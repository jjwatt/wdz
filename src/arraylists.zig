const std = @import("std");
const mem = std.mem;

test "messing with attraylists" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // var lines = std.ArrayList([]const u8).init(allocator);
    // defer lines.deinit();

    // testing append
    // try lines.append("zig-out|/home/zig/zig-out");
    // try lines.append("home|/home/jwattenb");

    const lines = try buildArrayListReverse(allocator);
    defer lines.deinit();
    for (lines.items) |line| {
        std.debug.print("{s}\n", .{line});
    }
}

pub fn buildArrayList(allocator: mem.Allocator) !std.ArrayList([]const u8) {
    // build an ArrayList and try to return it
    var lines = std.ArrayList([]const u8).init(allocator);
    // defer lines.deinit();
    try lines.append("zig-out|/home/zig/zig-out");
    try lines.append("home|/home/jwattenb");
    try lines.append("zig|/home/zig");

    return lines;
}
pub fn buildArrayListReverse(allocator: mem.Allocator) !std.ArrayList([]const u8) {
    const lines = try buildArrayList(allocator);
    defer lines.deinit();
    var backwards = std.ArrayList([]const u8).init(allocator);
    for (lines.items) |line| {
        try backwards.insert(0, line);
    }
    return backwards;
}
// pub fn main() !void {}
