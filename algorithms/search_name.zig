const std = @import("std");
const fs = std.fs;

/// Find files containing `name` in the filename.
/// Search in the root path if specified, otherwise search in the current working directory.
pub fn searchName(alloc: std.mem.Allocator, name: []const u8, root: ?[]const u8) !SearchIterator {
    const root_dir = try openRootDir(alloc, root);
    return SearchIterator.init(alloc, name, root_dir);
}

fn openRootDir(alloc: std.mem.Allocator, root: ?[]const u8) !fs.Dir {
    if (root) |root_path| {
        const real_root_path = try fs.realpathAlloc(alloc, root_path);
        defer alloc.free(real_root_path);
        return fs.openDirAbsolute(real_root_path, .{ .iterate = true, .access_sub_paths = true });
    } else {
        return fs.cwd().openDir(".", .{ .iterate = true, .access_sub_paths = true });
    }
}

pub const SearchIterator = struct {
    target: []const u8,
    root_dir: fs.Dir,
    walker: fs.Dir.Walker,

    /// Initialize walker.
    /// Walker owns basedir and will closed it on deinit.
    /// If initialization fails, root_dir will be closed.
    pub fn init(alloc: std.mem.Allocator, target: []const u8, root_dir: fs.Dir) !SearchIterator {
        const walker = try root_dir.walk(alloc);
        errdefer root_dir.close();
        return .{ .target = target, .root_dir = root_dir, .walker = walker };
    }

    pub fn deinit(self: *SearchIterator) void {
        self.walker.deinit();
        self.root_dir.close();
    }

    pub fn next(self: *SearchIterator) !?fs.Dir.Walker.Entry {
        while (try self.walker.next()) |file| {
            if (std.mem.indexOf(u8, file.basename, self.target)) |_| {
                return file;
            }
        }
        return null;
    }
};

test "searh in cwd" {
    var search = try searchName(std.testing.allocator, "build.zig", null);
    defer search.deinit();

    var file = try search.next();
    try std.testing.expectEqualStrings("build.zig", file.?.basename);

    file = try search.next();
    try std.testing.expectEqualStrings("build.zig.zon", file.?.basename);
    
    file = try search.next();
    try std.testing.expectEqual(null, file);
}

test "searh in provided root path" {
    var search = try searchName(std.testing.allocator, ".zig", "./algorithms");
    defer search.deinit();

    var file = try search.next();
    try std.testing.expectEqualStrings("linreg.zig", file.?.basename);

    file = try search.next();
    try std.testing.expectEqualStrings("search_name.zig", file.?.basename);
    
    file = try search.next();
    try std.testing.expectEqual(null, file);
}
