const std = @import("std");
const linreg = @import("linreg");
const search_name = @import("search_name");

fn linreg_task(args: anytype) !void {
    const n = 20;
    for (1..args.fits) |f| {
        const model = linreg.LinReg(n).fit(
            @Vector(n, f64){ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20 },
            @Vector(n, f64){ 2, 3, 16, 9, 9, 15, 19, 2, 18, @floatFromInt(f), 7, 15, 5, 20, 12, 11, 9, 14, 6, 5 },
        );
        for (1..args.predicts) |_| {
            std.mem.doNotOptimizeAway(model.predict(10.0));
        }
    }
}

fn search_task(args: anytype) !void {
    const alloc = std.heap.page_allocator;
    for (0..args.search_repeats) |_| {
        var iter = try search_name.searchName(alloc, "build.zig", null);
        while (try iter.next()) |file| {
            std.mem.doNotOptimizeAway(file);
        }
    }
}

pub fn main() !void {
    const args = try parse_args();

    var linreg_thread = try std.Thread.spawn(.{}, linreg_task, .{args});
    var search_thread = try std.Thread.spawn(.{}, search_task, .{args});

    linreg_thread.join();
    search_thread.join();
}

fn usage(out: std.fs.File.Writer, exe: []const u8, msg: ?[]const u8) !void {
    if (msg) |msg_val| try out.writeAll(msg_val);
    try out.print("usage: {s} <fits: usize> <predicts: usize> <search_repeats: usize>\n", .{exe});
}

fn parse_args() !struct { fits: usize, predicts: usize, search_repeats: usize } {
    const stderr = std.io.getStdErr().writer();

    var args = std.process.args();
    const exe_arg = args.next().?;
    const fits_arg = args.next() orelse {
        try usage(stderr, exe_arg, null);
        std.process.exit(1);
    };
    const fits = std.fmt.parseInt(usize, fits_arg, 10) catch {
        try usage(stderr, exe_arg, "<fits> must be an unsigned integer\n");
        std.process.exit(1);
    };
    const predicts_arg = args.next() orelse {
        try usage(stderr, exe_arg, null);
        std.process.exit(1);
    };
    const predicts = std.fmt.parseInt(usize, predicts_arg, 10) catch {
        try usage(stderr, exe_arg, "<predicts> must be an unsigned integer\n");
        std.process.exit(1);
    };
    const search_repeats_arg = args.next() orelse {
        try usage(stderr, exe_arg, null);
        std.process.exit(1);
    };
    const search_repeats = std.fmt.parseInt(usize, search_repeats_arg, 10) catch {
        try usage(stderr, exe_arg, "<search_repeats> must be an unsigned integer\n");
        std.process.exit(1);
    };
    return .{ .fits = fits, .predicts = predicts, .search_repeats = search_repeats };
}
