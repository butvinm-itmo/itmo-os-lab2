const std = @import("std");
const search_name = @import("search_name");

pub fn main() !void {
    const args = try parse_args();

    const alloc = std.heap.page_allocator;
    for (0..args.repeats) |_| {
        var iter = try search_name.searchName(alloc, "build.zig", null);
        while (try iter.next()) |file| {
            std.mem.doNotOptimizeAway(file);
        }
    }
}

fn usage(out: std.fs.File.Writer, exe: []const u8, msg: ?[]const u8) !void {
    if (msg) |msg_val| try out.writeAll(msg_val);
    try out.print("usage: {s} <repeats: usize>\n", .{exe});
}

fn parse_args() !struct { repeats: usize } {
    const stderr = std.io.getStdErr().writer();

    var args = std.process.args();
    const exe_arg = args.next().?;
    const repeats_arg = args.next() orelse {
        try usage(stderr, exe_arg, null);
        std.process.exit(1);
    };
    const repeats = std.fmt.parseInt(usize, repeats_arg, 10) catch {
        try usage(stderr, exe_arg, "<repeats> must be an unsigned integer\n");
        std.process.exit(1);
    };
    return .{ .repeats =repeats };
}
