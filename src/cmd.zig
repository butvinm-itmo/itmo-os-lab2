const std = @import("std");
const cmd = @import("cmd.zig");
const parser = @import("parser.zig");

pub const ExecArgs = struct {
    path: [*:0]const u8,
    child_argv: [*:null]const ?[*:0]const u8,
    envp: [*:null]const ?[*:0]const u8,
};

/// Arguments to invoke executable via execvpe
pub const Cmd = struct {
    args: []const []const u8,
    envs: []const []const u8,

    /// Build arguments to invoke execvpe from command
    pub fn toExecArgs(self: Cmd, alloc: std.mem.Allocator) !ExecArgs {
        var argsZ = std.ArrayList(?[*:0]const u8).init(alloc);
        for (self.args) |arg| {
            const argZ = try alloc.dupeZ(u8, arg);
            try argsZ.append(argZ.ptr);
        }
        const argsZZ = try argsZ.toOwnedSliceSentinel(null);

        var envsZ = std.ArrayList(?[*:0]const u8).init(alloc);
        for (self.envs) |env| {
            const envZ = try alloc.dupeZ(u8, env);
            try envsZ.append(envZ.ptr);
        }
        const envsZZ = try envsZ.toOwnedSliceSentinel(null);

        if (argsZZ[0]) |path| {
            return .{ .path = path, .child_argv = argsZZ.ptr, .envp = envsZZ.ptr };
        } else {
            unreachable;
        }
    }

    /// Deinit args and envs and their members.
    /// Use with parser.parseCmd
    pub fn deinit(self: Cmd, alloc: std.mem.Allocator) void {
        for (self.args) |arg| alloc.free(arg);
        alloc.free(self.args);

        for (self.envs) |arg| alloc.free(arg);
        alloc.free(self.envs);
    }
};
