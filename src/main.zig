const std = @import("std");
const fs = std.fs;
const os = std.os;
const process = std.process;

// TODO: I want this to be $HOME/.wdz
// pub const dbfile = ".wdz";

// default k,v delim
const delim = "|";
// default bookmark file filename
const default_bm_filename = ".wdz";
// TODO: pass the allocator to functions instead of global
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = gpa.allocator();

pub fn main() !void {
    //const path: ?[]u8 = try getCwd() orelse "";
    defer _ = gpa.deinit();
    const d: std.fs.Dir = std.fs.cwd();

    var progargs = process.args();
    std.debug.print("ArgIterator looks like {}\n", .{progargs});
    // std.debug.print("arg from ArgIterator.next(): {?s}\n", .{progargs.next()});
    // I think we can use while over the ArgIterator
    while (progargs.next()) |arg| {
        std.debug.print("arg from while ArgIterator: {s}\n", .{arg});
    }
    // yes, this works.

    // const page_alloc = std.heap.page_allocator;
    // const args_alloc_args = try process.argsAlloc(page_alloc);
    // std.debug.print("args_alloc_args: {s}\n", .{args_alloc_args});
    // // args_alloc_args is a slice
    // const ArgsType = @TypeOf(args_alloc_args);
    // std.debug.print("type of args_alloc_args: {}\n", .{ArgsType});
    // // TODO: switch on command line arguments
    // // e.g., if it's add, if it's ls
    // for (args_alloc_args) |arg| {
    //     std.debug.print("arg from loop args_alloc_args: {s}\n", .{arg});
    // }
    // defer page_alloc.free(args_alloc_args);

    const home_dir = try process.getEnvVarOwned(allocator, "HOME");
    defer allocator.free(home_dir);
    std.debug.print("home_dir is {s}\n", .{home_dir});

    std.debug.print("cwd is {d}\n", d);
    std.debug.print("trying to look in value: {}\n", .{d});

    // std.debug.print("Trying to use realPathAlloc and an allocator...", .{});
    // const path = try d.realpathAlloc(allocator, ".");
    // defer allocator.free(path);
    // std.debug.print("Current directory from allocator: {s}\n", .{path});

    std.debug.print("Trying to use fs.Dir.realpath without allocator...", .{});
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const path2 = try d.realpath(".", &buf);
    std.debug.print("Current directory from buf: {s}\n", .{path2});

    // fake adding
    const fakename = "fakebmname3";
    _ = try add(fakename, path2);
}

pub fn add(name: []const u8, path: []u8) !void {
    // The file has to be in your home dir for now.
    // TODO: support using an absolute path.
    const home_dir = try process.getEnvVarOwned(allocator, "HOME");
    defer allocator.free(home_dir);

    std.debug.print("adding: {s}{s}{s}\n", .{ name, delim, path });
    // try to construct the full path to the dbfile
    const bm_file_path = try fs.path.join(allocator, &[_][]const u8{ home_dir, default_bm_filename });
    defer allocator.free(bm_file_path);
    std.debug.print("full db file path: {s}\n", .{bm_file_path});

    const myfile = try getFileFromPath(bm_file_path);
    defer myfile.close();
    std.debug.print("file is {}\n", .{myfile});
    return addToFile(name, path, myfile);
}
pub fn addToFile(name: []const u8, path: []u8, file: fs.File) !void {
    // it doesn't write to the end and I don't see an O_APPEND Flag in OpenFlags...
    // Seek to the end for append.
    const stat = try file.stat();
    try file.seekTo(stat.size);
    var bufwriter = std.io.bufferedWriter(file.writer());
    const writer = bufwriter.writer();
    try writer.print("{s}{s}{s}\n", .{ name, delim, path });
    try bufwriter.flush();
}
pub fn getFileFromPath(path: []u8) !fs.File {
    const file = fs.openFileAbsolute(path, .{ .mode = .read_write }) catch |err| switch (err) {
        error.FileNotFound => {
            const new_file = try fs.createFileAbsolute(path, .{});
            return new_file;
        },
        else => {
            std.debug.print("error opening file: {}\n", .{err});
            return err;
        },
    };
    return file;
}

// pub fn addToFile(name: []u8, path: []u8, db: *std.fs.File) !void {
//     // open db file
//     // name & path to file
// }
// pub fn getCwd(allocator: std.mem.Allocator) !?[]u8 {
//     const d: std.fs.Dir = std.fs.cwd();
//     std.debug.print("cwd is {d}\n", d);
//     std.debug.print("trying to look in value: {}\n", .{d});

//     const path = try d.realpathAlloc(allocator, ".");
//     std.debug.print("Current directory: {s}\n", .{path});
//     // can't really return this. I need to learn more zig.
//     return path;
// }
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
