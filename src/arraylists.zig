const std = @import("std");
const mem = std.mem;

test "test buildArrayListReverse" {
    var timer = try std.time.Timer.start();
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const lines = try buildArrayListReverse(allocator);
    defer lines.deinit();
    for (lines.items) |line| {
        std.debug.print("{s}\n", .{line});
    }
    std.debug.print("took: {d} nanoseconds\n", .{timer.lap()});
}

test "test buildArrayListReverseIter" {
    var timer = try std.time.Timer.start();
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const lines = try buildArrayListReverse(allocator);
    defer lines.deinit();
    const rev = try buildArrayListReverseIter(allocator);
    std.debug.print("printing after reverseIter...\n", .{});
    for (rev.items) |item| {
        std.debug.print("{s}\n", .{item});
    }
    std.debug.print("took: {d} nanoseconds\n", .{timer.lap()});
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
pub fn buildArrayListReverseIter(allocator: mem.Allocator) !std.ArrayList([]const u8) {
    var lines = try buildArrayList(allocator);
    defer lines.deinit();
    const sl = try lines.toOwnedSlice();
    std.debug.print("type of sl: {}\n", .{@TypeOf(sl)});
    // Loop through the list backwards and build a new list.
    // I convert lines to toOwnedSlice() because mem.reverseIterator()
    // seems to work on ArrayList, but then it.next() complains about
    // the type and throws an error from zig's std code.
    var it = mem.reverseIterator(sl);
    var backwards = std.ArrayList([]const u8).init(allocator);
    while (it.next()) |s| {
        try backwards.append(s);
    }
    return backwards;
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

// pub fn main() !void {}
