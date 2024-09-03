const std = @import("std");
const fs = std.fs;
const mem = std.mem;
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

    const home_dir = try process.getEnvVarOwned(allocator, "HOME");
    defer allocator.free(home_dir);
    std.debug.print("home_dir is {s}\n", .{home_dir});
    // cat filename onto the end of home_dir
    const bm_file_path = try fs.path.join(allocator, &[_][]const u8{ home_dir, default_bm_filename });
    defer allocator.free(bm_file_path);

    std.debug.print("cwd is {d}\n", d);
    std.debug.print("trying to look in value: {}\n", .{d});

    // Is this cool?
    std.debug.print("Trying to use fs.Dir.realpath without allocator...", .{});
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const path2 = try d.realpath(".", &buf);
    std.debug.print("Current directory from buf: {s}\n", .{path2});

    // stop adding while I mess with finding.
    // const fakename = "fakebmname4";
    // _ = try add(fakename, path2, bm_file_path);

    const readfile = try getFileFromPath(bm_file_path);
    defer readfile.close();
    const rev = try readFileLinesReverse(readfile);
    defer allocator.free(rev);
    std.debug.print("rev: \n {s}\n", .{rev});
    var entries = mem.split(u8, rev, "\n");
    // std.debug.print("sm: {}\n", .{sm});
    findloop: while (entries.next()) |entry| {
        std.debug.print("entry: {s}\n", .{entry});
        if (mem.startsWith(u8, entry, "fakebmname4")) {
            std.debug.print("found: {s}\n", .{entry});
            break :findloop;
        }
    } else {
        std.debug.print("entry not found", .{});
    }
    // try find function
    const entry = try find("fakebmname4", &entries);
    std.debug.print("found entry: {s}\n", .{entry});
}
pub fn find(name: []const u8, entries: *mem.SplitIterator(u8, .sequence)) ![]const u8 {
    while (entries.next()) |entry| {
        std.debug.print("entry: {s}\n", .{entry});
        if (mem.startsWith(u8, entry, name)) {
            std.debug.print("found: {s}\n", .{entry});
            return entry;
        }
    } else {
        std.debug.print("return NotFound", .{});
        return "not found\n";
    }
}
pub fn add(name: []const u8, path: []u8, bm_file_path: []u8) !void {
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
pub fn readFileLinesReverse(file: fs.File) ![]u8 {
    // Read file into memory
    const stat = try file.stat();
    var buffer = try allocator.alloc(u8, stat.size);
    defer allocator.free(buffer);
    const bytesread = try file.readAll(buffer);
    if (bytesread != stat.size) return error.UnexpectedEndOfFile;

    // Split buffer into lines
    var lines = std.ArrayList([]const u8).init(allocator);
    defer lines.deinit();

    var line_start: usize = 0;
    for (buffer, 0..) |char, i| {
        if (char == '\n') {
            try lines.append(buffer[line_start..i]);
            line_start = i + 1;
        }
    }
    // Add the last line if it doesn't end in a newline.
    if (line_start < buffer.len) {
        try lines.append(buffer[line_start..]);
    }
    // Reverse the order of the lines.
    var reversed_lines = std.ArrayList([]const u8).init(allocator);
    defer reversed_lines.deinit();
    for (lines.items) |line| {
        try reversed_lines.insert(0, line);
    }
    var result = std.ArrayList(u8).init(allocator);
    for (reversed_lines.items) |line| {
        try result.appendSlice(line);
        try result.append('\n');
    }
    return result.toOwnedSlice();
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
