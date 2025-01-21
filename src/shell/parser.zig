const std = @import("std");
const cmd = @import("cmd.zig");

pub const Diagnostics = struct {};

pub const Error = error{
    UnexpectedEof,
};

/// Parse shell command with the following grammar
///
/// <Cmd> ::= <Env>* <Arg>*
/// <Env> ::= <Char>*=<Char>*
/// <Arg> ::= <Char>
///
/// Memory of the Cmd.args and Cmd.envs and their items owned by caller.
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
        while (self.cur < self.input.len) {
            var tmp_cur = self.cur;
            if (try self.parseString(&tmp_cur)) |env| {
                if (std.mem.indexOfScalar(u8, env, '=') != null) {
                    try envs.append(env);
                    self.cur = tmp_cur;
                } else {
                    self.alloc.free(env);
                    break;
                }
            } else {
                break;
            }
        }
        return try envs.toOwnedSlice();
    }

    fn parseArgs(self: *CmdParser) ![]const []const u8 {
        var args = std.ArrayList([]const u8).init(self.alloc);
        while (self.cur < self.input.len) {
            if (try self.parseString(&self.cur)) |arg| {
                try args.append(arg);
            } else {
                break;
            }
        }
        return try args.toOwnedSlice();
    }

    fn parseString(self: *CmdParser, cur: *usize) !?[]const u8 {
        self.skipWhitespaces(cur);
        if (cur.* >= self.input.len) {
            return null;
        }

        const begin_cur = cur.*;
        while (cur.* < self.input.len and !self.isWhitespace(self.input[cur.*])) {
            cur.* += 1;
        }
        return try self.alloc.dupe(u8, self.input[begin_cur..cur.*]);
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
