const std = @import("std");
const cmd = @import("cmd.zig");

pub const Diagnostics = struct {};

pub const ParserError = error{
    Eol,
    ClosingQuoteMissed,
};

/// Parse shell command with the following grammar
///
/// <Cmd> ::= <Env>* <Arg>*
/// <Env> ::= <Char>*=<String>
/// <Arg> ::= <String>
/// <String> ::= <Char - Whitespace>* | "<Char - '"'>*"
///
/// Memory of the Cmd.args and Cmd.envs and their items owned by a caller.
pub fn parseCmd(alloc: std.mem.Allocator, input: []const u8) !cmd.Cmd {
    var parser = CmdParser.init(alloc, input);
    return parser.parse();
}

const CmdParser = struct {
    alloc: std.mem.Allocator,
    input: []const u8,
    cur: usize = 0,

    fn init(alloc: std.mem.Allocator, input: []const u8) CmdParser {
        return CmdParser{ .alloc = alloc, .input = input, .cur = 0 };
    }

    fn parse(self: *CmdParser) !cmd.Cmd {
        const envs = try self.parseEnvs();
        const args = try self.parseArgs();
        return .{ .args = args, .envs = envs };
    }

    fn parseEnvs(self: *CmdParser) ![]const []const u8 {
        var envs = std.ArrayList([]const u8).init(self.alloc);
        errdefer envs.deinit();

        self.skipWhitespaces(&self.cur);
        while (self.cur < self.input.len) {
            var cur = self.cur;
            while (cur < self.input.len and self.input[cur] != '=') {
                cur += 1;
            }
            if (cur >= self.input.len) {
                break;
            }
            const key_start = self.cur;
            const key_end = cur;
            self.cur = cur + 1;

            const val_start, const val_end = try self.parseString(&self.cur);
            const env = try std.mem.join(self.alloc, "=", &[_][]const u8{ self.input[key_start..key_end], self.input[val_start..val_end] });
            errdefer self.alloc.free(env);
            try envs.append(env);
            self.skipWhitespaces(&self.cur);
        }
        return try envs.toOwnedSlice();
    }

    fn parseArgs(self: *CmdParser) ![]const []const u8 {
        var args = std.ArrayList([]const u8).init(self.alloc);
        errdefer args.deinit();

        self.skipWhitespaces(&self.cur);
        while (self.cur < self.input.len) {
            const arg_start, const arg_end = try self.parseString(&self.cur);
            const arg = try self.alloc.dupe(u8, self.input[arg_start..arg_end]);
            errdefer self.alloc.free(arg);
            try args.append(arg);
            self.skipWhitespaces(&self.cur);
        }
        return try args.toOwnedSlice();
    }

    fn parseString(self: *CmdParser, cur: *usize) ParserError!struct { usize, usize } {
        if (cur.* >= self.input.len) {
            return ParserError.Eol;
        }
        if (self.input[cur.*] == '"') {
            cur.* += 1;
            const start = cur.*;
            while (cur.* < self.input.len and self.input[cur.*] != '"') {
                cur.* += 1;
            }
            if (cur.* >= self.input.len) {
                return ParserError.ClosingQuoteMissed;
            }
            cur.* += 1;
            return .{ start, cur.* - 1 };
        } else {
            const begin_cur = cur.*;
            while (cur.* < self.input.len and !self.isWhitespace(self.input[cur.*])) {
                cur.* += 1;
            }
            return .{ begin_cur, cur.* };
        }
    }

    fn skipWhitespaces(self: *CmdParser, cur: *usize) void {
        while (cur.* < self.input.len and self.isWhitespace(self.input[cur.*])) {
            cur.* += 1;
        }
    }

    fn isWhitespace(_: CmdParser, char: u8) bool {
        return switch (char) {
            ' ', '\n', '\t', '\r' => true,
            else => false,
        };
    }
};

test "empty" {
    const command = try parseCmd(std.testing.allocator, "");
    defer command.deinit(std.testing.allocator);
    try std.testing.expectEqual(cmd.Cmd{
        .args = &[_][]const u8{},
        .envs = &[_][]const u8{},
    }, command);
}

test "whitespaces" {
    const command = try parseCmd(std.testing.allocator, "           ");
    defer command.deinit(std.testing.allocator);
    try std.testing.expectEqual(cmd.Cmd{
        .args = &[_][]const u8{},
        .envs = &[_][]const u8{},
    }, command);
}

test "envs only" {
    const command = try parseCmd(std.testing.allocator, "a=10 b=20");
    defer command.deinit(std.testing.allocator);
    try std.testing.expectEqualDeep(
        cmd.Cmd{
            .args = &[_][]const u8{},
            .envs = &[_][]const u8{ "a=10", "b=20" },
        },
        command,
    );
}

test "args only" {
    const command = try parseCmd(std.testing.allocator, "ls ./src");
    defer command.deinit(std.testing.allocator);
    try std.testing.expectEqualDeep(
        cmd.Cmd{
            .args = &[_][]const u8{ "ls", "./src" },
            .envs = &[_][]const u8{},
        },
        command,
    );
}

test "envs and args" {
    const command = try parseCmd(std.testing.allocator, "a=10 b=20 ls ./src");
    defer command.deinit(std.testing.allocator);
    try std.testing.expectEqualDeep(
        cmd.Cmd{
            .args = &[_][]const u8{ "ls", "./src" },
            .envs = &[_][]const u8{ "a=10", "b=20" },
        },
        command,
    );
}

test "whitespaces between envs and args" {
    const command = try parseCmd(std.testing.allocator, "   a=10   b=20   ls    ./src   ");
    defer command.deinit(std.testing.allocator);
    try std.testing.expectEqualDeep(
        cmd.Cmd{
            .args = &[_][]const u8{ "ls", "./src" },
            .envs = &[_][]const u8{ "a=10", "b=20" },
        },
        command,
    );
}

test "quoted arg" {
    const command = try parseCmd(std.testing.allocator, "\"hello\"");
    defer command.deinit(std.testing.allocator);
    try std.testing.expectEqualDeep(
        cmd.Cmd{
            .args = &[_][]const u8{"hello"},
            .envs = &[_][]const u8{},
        },
        command,
    );
}

test "mixed quoted and unquoted args" {
    const command = try parseCmd(std.testing.allocator, "ls \"my file.txt\"");
    defer command.deinit(std.testing.allocator);
    try std.testing.expectEqualDeep(
        cmd.Cmd{
            .args = &[_][]const u8{ "ls", "my file.txt" },
            .envs = &[_][]const u8{},
        },
        command,
    );
}

test "quoted env and arg" {
    const command = try parseCmd(std.testing.allocator, "a=\"10 20\" ls");
    defer command.deinit(std.testing.allocator);
    try std.testing.expectEqualDeep(
        cmd.Cmd{
            .args = &[_][]const u8{"ls"},
            .envs = &[_][]const u8{"a=10 20"},
        },
        command,
    );
}

test "unterminated quoted arg" {
    try std.testing.expectError(ParserError.ClosingQuoteMissed, parseCmd(std.testing.allocator, "\"unterminated"));
}
