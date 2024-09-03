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

    std.debug.print("Trying to use fs.Dir.realpath without allocator...", .{});
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const path2 = try d.realpath(".", &buf);
    std.debug.print("Current directory from buf: {s}\n", .{path2});
}

const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const Allocator = std.mem.Allocator;

pub fn readFileLinesReverse(allocator: *Allocator, file_path: []const u8) !void {
    const file = try fs.cwd().openFile(file_path, .{});
    defer file.close();

    // Get the size of the file
    const stat = try file.stat();
    const file_size = stat.size;

    // Read the entire file into memory
    var buffer = try allocator.alloc(u8, file_size);
    defer allocator.free(buffer);

    const bytes_read = try file.readAll(buffer);
    if (bytes_read != file_size) return error.UnexpectedEndOfFile;

    // Process lines in reverse
    var line_end = file_size;
    while (line_end > 0) {
        // Find the start of the current line
        const line_start = mem.lastIndexOfScalar(u8, buffer[0..line_end], '\n') orelse 0;

        // Print the line (excluding the newline character)
        std.debug.print("{s}\n", .{buffer[line_start + 1 .. line_end]});

        // Move to the previous line
        line_end = line_start;
    }

    // Print the first line if there's no newline at the end of the file
    if (line_end == 0 and buffer[0] != '\n') {
        std.debug.print("{s}\n", .{buffer[0..]});
    }
}

// Example usage:
// pub fn main() !void {
//     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//     defer _ = gpa.deinit();
//     try readFileLinesReverse(gpa.allocator, "path_to_your_file.txt");
// }

pub const Bookmark = struct { name: []u8, path: []u8 };
const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const ArrayList = std.ArrayList;

pub fn readFileLinesReverse(file: fs.File, allocator: *std.mem.Allocator) ![]u8 {
    // Read file into memory
    const stat = try file.stat();
    var buffer = try allocator.alloc(u8, stat.size);
    defer allocator.free(buffer);

    const bytes_read = try file.readAll(buffer);
    if (bytes_read != stat.size) return error.UnexpectedEndOfFile;

    // Split the buffer into lines
    var lines = ArrayList([]const u8).init(allocator);
    defer lines.deinit();

    var line_start: usize = 0;
    for (buffer) |char, i| {
        if (char == '\n') {
            try lines.append(buffer[line_start..i]);
            line_start = i + 1;
        }
    }
    // Add the last line if it doesn't end with a newline
    if (line_start < buffer.len) {
        try lines.append(buffer[line_start..]);
    }

    // Reverse the order of lines
    var reversed_lines = std.ArrayList([]const u8).init(allocator);
    defer reversed_lines.deinit();
    for (lines.items) |line| {
        try reversed_lines.insert(0, line);
    }

    // Join the reversed lines into a single string
    var result = std.ArrayList(u8).init(allocator);
    for (reversed_lines.items) |line| {
        try result.appendSlice(line);
        try result.append('\n');
    }

    // Remove the trailing newline if it exists
    if (result.items.len > 0 and result.items[result.items.len - 1] == '\n') {
        _ = result.pop();
    }

    return result.toOwnedSlice();
}
