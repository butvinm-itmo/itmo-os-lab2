const std = @import("std");
const cmd = @import("cmd.zig");
const parser = @import("parser.zig");

const max_input_size = 4096;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();

    var exit = false;
    while (!exit) {
        try stdout.print(">> ", .{});
        if (try stdin.readUntilDelimiterOrEofAlloc(alloc, '\n', max_input_size)) |input| {
            if (parser.parseCmd(alloc, input)) |command| {
                exit = try execCmd(alloc, stdout, stderr, command);
            } else |_| {
                try stderr.print("Failed to parse command", .{});
            }
        }
        _ = arena.reset(std.heap.ArenaAllocator.ResetMode.retain_capacity);
    }
    try stdout.print("Bye!\n", .{});
}

fn execCmd(
    alloc: std.mem.Allocator,
    _: std.fs.File.Writer,
    stderr: std.fs.File.Writer,
    command: cmd.Cmd,
) !bool {
    if (command.args.len == 0) return false;

    if (std.mem.eql(u8, command.args[0], "exit")) return true;

    const pid = try std.posix.fork();
    if (pid == 0) {
        const exec_args = try command.toExecArgs(alloc);
        switch (std.posix.execvpeZ(exec_args.path, exec_args.child_argv, exec_args.envp)) {
            std.posix.ExecveError.FileNotFound => try stderr.print("Executable not found: {s}\n", .{command.args[0]}),
            std.posix.ExecveError.AccessDenied => try stderr.print("Access denied\n", .{}),
            else => try stderr.print("Unexpected error\n", .{}),
        }
        std.process.abort();
    } else {
        const st_time = std.time.nanoTimestamp();
        const status = std.posix.waitpid(pid, 0).status;
        const end_time = std.time.nanoTimestamp();
        if (std.os.linux.W.IFEXITED(status)) {
            const exec_time = @as(f64, @floatFromInt(end_time - st_time)) / std.time.ns_per_s;
            try stderr.print(
                "Process {d} exited with status code {} in {d} seconds\n",
                .{ pid, std.os.linux.W.EXITSTATUS(status), exec_time },
            );
        }
    }
    return false;
}

test {
    _ = @import("cmd.zig");
    _ = @import("parser.zig");
}
