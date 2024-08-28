const std = @import("std");

pub fn main() !void {
    //const path: ?[]u8 = try getCwd() orelse "";
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var allocator = gpa.allocator();

    const thing = try getCwd(&allocator);
    defer allocator.free(thing);
    std.debug.print("thing is {?s}\n", .{thing});
}

pub fn getCwd(allocator: *std.mem.Allocator) !?[]u8 {
    const d: std.fs.Dir = std.fs.cwd();
    std.debug.print("cwd is {d}\n", d);
    std.debug.print("trying to look in value: {}\n", .{d});

    const path = try d.realpathAlloc(allocator, ".");
    std.debug.print("Current directory: {s}\n", .{path});
    return path;
}
// cwd (call real fs.cwd() or override for testing)
// add (Bookmark, BookmarkFile)
// dirAdd (name: []u8, directory: fs.Dir, BookmarkFile)
// del/rm (Identifier, BookmarkFile)
// ls/list (Filter, BookmarkFile)
// readfile (BookmarkFile)
// writefile (BookmarkFile)
// Identifier would just be a string that we can check against multiple fields
// Filter would be a string that we can search or maybe glob or re
// pub const Bookmark = struct { name: []u8, path: []u8 };
// pub const BookmarkFile = struct { path: []u8 = "~/.wdz" };
// BookmarkFile .content?
