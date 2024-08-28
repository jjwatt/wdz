const std = @import("std");
const fs = std.fs;

pub fn main() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const d: fs.Dir = fs.cwd();
    std.debug.print("cwd is {d}\n", d);
    std.debug.print("trying to look in value: {}\n", .{d});

    const path = try d.realpathAlloc(allocator, ".");
    defer allocator.free(path);
    std.debug.print("Current directory: {s}\n", .{path});
    // std.debug.print("try out TypeOf: {s}\n", @TypeOf(d)); //
    //std.debug.print("trying a function: {}\n", d.realpath("", ""));
    // var buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    // const cwd = std.process.getCwd(&buffer);
    // std.debug.print("current directory: {s}\n", .{cwd});
}
