const std = @import("std");
const fs = std.fs;
const io = std.io;
const mem = std.mem;
const os = std.os;
const process = std.process;
const testing = std.testing;

const usage =
    \\Usage: wdz [options]
    \\
    \\General Options:
    \\
    \\ -h, --help                Print usage
    \\ -a, --add [name]          Add current directory with name
    \\ -f, --find [name]         Find an bookmark and return the path
    \\ -l, --list, --ls          List bookmarks
    \\ --list-all                List all values (useful to use with fuzzy matchers)
    \\ -r, --pop, --rm [name]    Remove and return bookmark
    \\
;

// default k,v delim
const delim = "|";
// default bookmark file filename
const default_bm_filename = ".wdz";

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var progargs = process.args();
    while (progargs.next()) |arg| {
        if (mem.startsWith(u8, arg, "-")) {
            if (mem.eql(u8, arg, "-h") or mem.eql(u8, arg, "--help")) {
                try io.getStdOut().writeAll(usage);
                return;
            }
            if (mem.eql(u8, arg, "--test")) {
                // do testing stuff here
                var timer = try std.time.Timer.start();
                // try listPrint(allocator);
                const bmfilepath = try bookMarkFilePath(allocator, default_bm_filename);
                defer allocator.free(bmfilepath);
                std.debug.print("bmfilepath: {s}\n", .{bmfilepath});
                std.debug.print("took: {d} nanoseconds\n", .{timer.lap()});
                process.exit(0);
            }
            if (mem.eql(u8, arg, "--list-all") or mem.eql(u8, arg, "--la")) {
                try listPrintAllValues(allocator);
                process.exit(0);
            }
            if (mem.eql(u8, arg, "-l") or mem.eql(u8, arg, "--ls") or mem.eql(u8, arg, "--list")) {
                // var timer = try std.time.Timer.start();
                try listPrint(allocator);
                // std.debug.print("took: {d} nanoseconds\n", .{timer.lap()});
                process.exit(0);
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
            if (mem.eql(u8, arg, "-r") or mem.eql(u8, arg, "--pop")) {
                // Get bookmark name.
                if (progargs.next()) |bm_name| {
                    if (mem.startsWith(u8, bm_name, "-")) {
                        std.log.err("Expected a name after -r or --pop", .{});
                        process.exit(1);
                    } else {
                        const bmfile = try getBookMarkFile(allocator);
                        defer bmfile.close();
                        // can do catch |err| switch |err| trick here
                        _ = try popFromFile(allocator, bmfile, bm_name);
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
                        _ = try listPrintFindByName(allocator, bmfile, bm_search);
                        process.exit(0);
                    }
                }
            }
        }
    }
}
pub fn bookMarkFilePath(allocator: mem.Allocator, bm_filename: []const u8) ![]const u8 {
    // bookmark file is always $HOME/$bm_file_path (set at the top).
    const home_dir = try process.getEnvVarOwned(allocator, "HOME");
    defer allocator.free(home_dir);

    // cat filename onto the end of home_dir.
    const bm_file_path = try fs.path.join(allocator, &[_][]const u8{ home_dir, bm_filename });
    return bm_file_path;
}
pub fn bookMarkFileHandle(path: []const u8) !fs.File {
    const file =
        fs.openFileAbsolute(path, .{ .mode = .read_write }) catch |err| switch (err) {
        error.FileNotFound => {
            return try fs.createFileAbsolute(path, .{});
        },
        else => {
            std.debug.print("error opening file: {}\n", .{err});
            return err;
        },
    };
    return file;
}
pub fn getBookMarkFile(allocator: mem.Allocator) !fs.File {
    const bm_file_path = try bookMarkFilePath(allocator, default_bm_filename);
    defer allocator.free(bm_file_path);
    const bmfile = try bookMarkFileHandle(bm_file_path);
    return bmfile;
}
test "get bookmark file path" {
    const allocator = std.testing.allocator;
    const bm_file_path = try bookMarkFilePath(allocator, default_bm_filename);
    defer allocator.free(bm_file_path);
    std.debug.print("bookmark filepath: {s}\n", .{bm_file_path});
    // This won't be true if home isn't /home
    // Remove or change this test if different.
    try testing.expect(mem.startsWith(u8, bm_file_path, "/home"));
}
test "getBookMarkFile" {
    const allocator = std.testing.allocator;
    const bmfile = try getBookMarkFile(allocator);
    defer bmfile.close();
    std.debug.print("typeof bmfile: {}\n", .{bmfile});
}
/// Prints list of all records to stdout
pub fn listPrint(allocator: mem.Allocator) !void {
    // TODO: put this in a function that returns buffer.
    const file = try getBookMarkFile(allocator);
    defer file.close();
    // Read file into memory
    const stat = try file.stat();
    const buffer = try allocator.alloc(u8, stat.size);
    defer allocator.free(buffer);
    const bytesread = try file.readAll(buffer);
    if (bytesread != stat.size) return error.UnexpectedEndOfFile;

    // Setup to iterate over lines in reverse.
    var it = mem.splitBackwardsAny(u8, buffer, "\n");

    // Print lines to stdout.
    const stdout_writer = std.io.getStdOut().writer();
    while (it.next()) |line| {
        // Skip empty lines.
        if (mem.eql(u8, line, "")) {
            continue;
        } else {
            try stdout_writer.print("{s}\n", .{line});
        }
    }
}
/// Prints list of values to stdout
pub fn listPrintAllValues(allocator: mem.Allocator) !void {
    // TODO: put this in a function that returns buffer.
    const file = try getBookMarkFile(allocator);
    defer file.close();
    // Read file into memory
    const stat = try file.stat();
    const buffer = try allocator.alloc(u8, stat.size);
    defer allocator.free(buffer);
    const bytesread = try file.readAll(buffer);
    if (bytesread != stat.size) return error.UnexpectedEndOfFile;

    // Setup to iterate over lines in reverse.
    var entries = mem.splitBackwardsAny(u8, buffer, "\n");

    // Print lines to stdout.
    const stdout_writer = std.io.getStdOut().writer();
    while (entries.next()) |entry| {
        // Skip empty lines.
        if (mem.eql(u8, entry, "")) {
            continue;
        } else {
            // std.debug.print("DEBUG: entry: {s}\n", .{entry});
            var it = mem.splitAny(u8, entry, delim);
            // skip the first part.
            _ = it.next();
            const val = it.next() orelse process.exit(1);
            try stdout_writer.print("{s}\n", .{val});
        }
    }
}
pub fn listPrintFindByName(allocator: mem.Allocator, bmfile: fs.File, name: []const u8) !void {
    // Read file into memory.
    const stat = try bmfile.stat();
    const buffer = try allocator.alloc(u8, stat.size);
    defer allocator.free(buffer);
    const bytesread = try bmfile.readAll(buffer);
    if (bytesread != stat.size) return error.UnexpectedEndOfFile;

    // Setup to iterate over lines in reverse.
    var entries = mem.splitBackwardsAny(u8, buffer, "\n");
    const stdout_writer = std.io.getStdOut().writer();
    while (entries.next()) |entry| {
        if (mem.startsWith(u8, entry, name)) {
            var it = mem.splitAny(u8, entry, delim);
            // skip the first part.
            _ = it.next();
            const val = it.next() orelse process.exit(1);
            try stdout_writer.print("{s}\n", .{val});
            break;
        }
    } else {
        process.exit(1);
    }
}
// TODO: listPrintFindAllByName
// TODO: decide on interface
pub fn listPrintFindByValue(allocator: mem.Allocator, bmfile: fs.File, value: []const u8) !void {
    // Read file into memory.
    const stat = try bmfile.stat();
    const buffer = try allocator.alloc(u8, stat.size);
    defer allocator.free(buffer);
    const bytesread = try bmfile.readAll(buffer);
    if (bytesread != stat.size) return error.UnexpectedEndOfFile;

    // Setup to iterate over lines in reverse.
    var entries = mem.splitBackwardsAny(u8, buffer, "\n");
    const stdout_writer = std.io.getStdOut().writer();
    while (entries.next()) |entry| {
        if (mem.eql(u8, entry, "")) {
            continue;
        }
        var it = mem.splitAny(u8, entry, delim);
        // skip the first part.
        _ = it.next();
        const val = it.next() orelse process.exit(1);
        if (mem.startsWith(u8, val, value)) {
            try stdout_writer.print("{s}\n", .{val});
            break;
        }
    } else {
        process.exit(1);
    }
}

test "testing listPrint" {
    const allocator = std.testing.allocator;
    try listPrint(allocator);
}
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
    // Seek to the end for append.
    const stat = try file.stat();
    try file.seekTo(stat.size);
    var bufwriter = std.io.bufferedWriter(file.writer());
    const writer = bufwriter.writer();
    try writer.print("{s}{s}{s}\n", .{ name, delim, path });
    try bufwriter.flush();
}
// TODO: pop - take the first entry that matches and return it and rewrite the file without it
pub fn popFromFile(allocator: mem.Allocator, file: fs.File, name: []const u8) ![]const u8 {
    // read file into memory
    // find first occurance iterating backwards, save it and remove it from the list
    // rewrite list without first occurance
    // return value
    // Read file into memory.
    const stat = try file.stat();
    const buffer = try allocator.alloc(u8, stat.size);
    defer allocator.free(buffer);
    const bytesread = try file.readAll(buffer);
    if (bytesread != stat.size) return error.UnexpectedEndOfFile;

    // Setup to iterate over lines in reverse.
    var entries = mem.splitBackwardsAny(u8, buffer, "\n");
    const stdout_writer = std.io.getStdOut().writer();
    while (entries.next()) |entry| {
        if (mem.startsWith(u8, entry, name)) {
            var it = mem.splitAny(u8, entry, delim);
            // skip the first part.
            _ = it.next();
            if (it.next()) |val| {
                try stdout_writer.print("{s}\n", .{val});
                return val;
            }
        }
    } else {
        // TODO: change this to return an error or something
        return error.NotFound;
    }
    // That will print it. We could go through buffer again and write everything
    // except for the entry that matches back to the file. Will probably have to
    // seek to the beginning.
}
