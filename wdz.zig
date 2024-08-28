const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const d: std.fs.Dir = std.fs.cwd();
    std.debug.print("cwd is {d}\n", d);
    std.debug.print("trying to look in value: {}\n", .{d});

    const path = try d.realpathAlloc(allocator, ".");
    defer allocator.free(path);
    std.debug.print("Current directory: {s}\n", .{path});
}
// add
// del/rm
// ls/list
pub const Bookmark = struct { name: []u8, path: []u8 };
pub const BookmarkFile = struct { path: []u8 = "~/.wdz" };
// BookmarkFile .content?
