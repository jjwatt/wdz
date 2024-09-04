const std = @import("std");
const fs = std.fs;
const io = std.io;
const mem = std.mem;
const os = std.os;
const process = std.process;

const usage =
    \\Usage: wdz [options]
    \\
    \\General Options:
    \\
    \\ -h, --help                Print usage
    \\ -a, --add [name]          Add current directory with name
    \\ -l, --list, --ls          List bookmarks
    \\ -r, --remove, --rm [name] Remove bookmark
    \\
;

// default k,v delim
const delim = "|";
// default bookmark file filename
const default_bm_filename = ".wdz";
// TODO: refactor pass the allocator to functions instead of global

pub fn main() !void {
    // const d: std.fs.Dir = std.fs.cwd();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var progargs = process.args();
    // std.debug.print("ArgIterator looks like {}\n", .{progargs});
    // std.debug.print("arg from ArgIterator.next(): {?s}\n", .{progargs.next()});
    while (progargs.next()) |arg| {
        // std.debug.print("arg from while ArgIterator: {s}\n", .{arg});
        if (mem.startsWith(u8, arg, "-")) {
            if (mem.eql(u8, arg, "-h") or mem.eql(u8, arg, "--help")) {
                try io.getStdOut().writeAll(usage);
                return;
            }
            if (mem.eql(u8, arg, "-l") or mem.eql(u8, arg, "--ls") or mem.eql(u8, arg, "--list")) {
                const lst = try list(allocator);
                defer allocator.free(lst);
                std.debug.print("{s}\n", .{lst});
                return;
            }
            if (mem.eql(u8, arg, "-a") or mem.eql(u8, arg, "--add")) {
                // Get bookmark name.
                if (progargs.next()) |bm_name| {
                    if (mem.startsWith(u8, bm_name, "-")) {
                        std.log.err("Expected a name after -a or --add", .{});
                        process.exit(1);
                    } else {
                        const bmfile = try getBookMarkFile(allocator);
                        defer bmfile.close();
                        _ = try add(allocator, bm_name);
                        return;
                    }
                }
            }
            if (mem.eql(u8, arg, "-f") or mem.eql(u8, arg, "--find")) {
                // Try to find latest bookmark name entry
                // TODO: later we'll add pop() and iterators or multiple returns
                if (progargs.next()) |bm_search| {
                    if (mem.startsWith(u8, bm_search, "-")) {
                        std.log.err("Expected string after -f or --find", .{});
                        process.exit(1);
                    } else {
                        const bmfile = try getBookMarkFile(allocator);
                        defer bmfile.close();
                        const rev = try readFileLinesReverse(allocator, bmfile);
                        defer allocator.free(rev);
                        const entry = try find(bm_search, &rev);
                        std.debug.print("{s}\n", .{entry});
                        // if (entry) |e| {
                        //     std.debug.print("{s}\n", .{e});
                        //     process.exit(0);
                        // } else {
                        //     process.exit(1);
                        // }
                    }
                }
            }
        }
    }

    // const readfile = try getBookMarkFile(allocator);
    // const rev = try readFileLinesReverse(allocator, readfile);
    // defer allocator.free(rev);
    // std.debug.print("rev: \n {s}\n", .{rev});
    // try find function
    // std.debug.print("Using find() to find fakebmname4...\n", .{});
    // const entry = try find("fakebmname4", &rev);
    // std.debug.print("found entry: {s}\n", .{entry});
}
pub fn getBookMarkFile(allocator: mem.Allocator) !fs.File {
    // return the bookmark file
    // bookmark file is always $HOME/$bm_file_path (set at the top)
    const home_dir = try process.getEnvVarOwned(allocator, "HOME");
    defer allocator.free(home_dir);
    // std.debug.print("home_dir is {s}\n", .{home_dir});
    // cat filename onto the end of home_dir
    const bm_file_path = try fs.path.join(allocator, &[_][]const u8{ home_dir, default_bm_filename });
    defer allocator.free(bm_file_path);
    const file = fs.openFileAbsolute(bm_file_path, .{ .mode = .read_write }) catch |err| switch (err) {
        error.FileNotFound => {
            const new_file = try fs.createFileAbsolute(bm_file_path, .{});
            return new_file;
        },
        else => {
            std.debug.print("error opening file: {}\n", .{err});
            return err;
        },
    };
    return file;
}
pub fn list(allocator: mem.Allocator) ![]u8 {
    // return list of records
    const readfile = try getBookMarkFile(allocator);
    defer readfile.close();
    const rev = try readFileLinesReverse(allocator, readfile);
    // defer allocator.free(rev);
    // std.debug.print("rev: \n {s}\n", .{rev});
    return rev;
}
pub fn find(name: []const u8, records: *const []u8) ![]const u8 {
    var entries = mem.splitAny(u8, records.*, "\n");
    while (entries.next()) |entry| {
        if (mem.startsWith(u8, entry, name)) {
            return entry;
        }
    } else {
        std.debug.print("return NotFound", .{});
        // TODO: return a real error.
        return "not found\n";
    }
}
// pub fn findInFile(name: []const u8) ![]const u8 {
//     // try to find first entry in file.
// }
pub fn add(allocator: mem.Allocator, name: []const u8) !void {
    const d: std.fs.Dir = std.fs.cwd();
    // std.debug.print("cwd is {d}\n", d);
    // std.debug.print("trying to look in value: {}\n", .{d});

    // Is this cool?
    // std.debug.print("Trying to use fs.Dir.realpath without allocator...", .{});
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const path = try d.realpath(".", &buf);
    // std.debug.print("Current directory from buf: {s}\n", .{path});

    const myfile = try getBookMarkFile(allocator);
    defer myfile.close();
    // std.debug.print("file is {}\n", .{myfile});
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
pub fn readFileLinesReverse(allocator: mem.Allocator, file: fs.File) ![]u8 {
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
    // This seems unnecessary considering the above, but I can't seem to make
    // it work with reversed_lines alone.
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
