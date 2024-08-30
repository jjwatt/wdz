const std = @import("std");
const fs = std.fs;
const os = std.os;
const process = std.process;

pub const dbfile = ".wdz";

pub fn main() !void {
    //const path: ?[]u8 = try getCwd() orelse "";
    const d: std.fs.Dir = std.fs.cwd();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var allocator = gpa.allocator();

    var progargs = process.args();
    std.debug.print("ArgIterator looks like {}\n", .{progargs});
    std.debug.print("arg: {?s}\n", .{progargs.next()});

    const home_dir = try process.getEnvVarOwned(allocator, "HOME");
    defer allocator.free(home_dir);
    std.debug.print("home_dir is {s}\n", .{home_dir});

    std.debug.print("cwd is {d}\n", d);
    std.debug.print("trying to look in value: {}\n", .{d});

    std.debug.print("Trying to use realPathAlloc and an allocator...", .{});
    const path = try d.realpathAlloc(allocator, ".");
    defer allocator.free(path);
    std.debug.print("Current directory from allocator: {s}\n", .{path});

    std.debug.print("Trying to use fs.Dir.realpath without allocator...", .{});
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const path2 = try d.realpath(".", &buf);
    std.debug.print("Current directory from buf: {s}\n", .{path2});
}

// pub fn add(name: []u8, path: []u8) !void {
//     // call addToFile with the global file name
// }
// pub fn addToFile(name: []u8, path: []u8, db: *std.fs.File) !void {
//     // open db file
//     // name & path to file
// }
pub fn getCwd(allocator: std.mem.Allocator) !?[]u8 {
    const d: std.fs.Dir = std.fs.cwd();
    std.debug.print("cwd is {d}\n", d);
    std.debug.print("trying to look in value: {}\n", .{d});

    const path = try d.realpathAlloc(allocator, ".");
    std.debug.print("Current directory: {s}\n", .{path});
    // can't really return this. I need to learn more zig.
    return path;
}
// cwd (call real fs.cwd() or override for testing)
// add (Bookmark, BookmarkFile)
//   add will add the string and cwd to the bookmarkfile
// dirAdd (name: []u8, directory: fs.Dir, BookmarkFile)
// del/rm (Identifier, BookmarkFile)
// pop (Identifier, BookmarkFile)
//    rm removes all occurances, pop just the last one.
// ls/list (Filter, BookmarkFile)
// readfile (BookmarkFile)
// writefile (BookmarkFile)
// Identifier would just be a string that we can check against multiple fields
// Filter would be a string that we can search or maybe glob or re
// pub const Bookmark = struct { name: []u8, path: []u8 };
// pub const BookmarkFile = struct { path: []u8 = "~/.wdz" };
// BookmarkFile .content?
