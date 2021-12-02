const std = @import("std");
const art = @embedFile("../art.txt");

const day1 = @import("day1.zig");
const day2 = @import("day2.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = &arena.allocator;

    const stdout = std.io.getStdOut().writer();
    try stdout.print("{s}\n", .{art});

    var args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args); // i know this is a no-op, but if i ever decide to change allocator this is necessary

    const num_opt: ?i32 = if (args.len <= 1) null else std.fmt.parseInt(i32, args[1], 0) catch null;
    const num = num_opt orelse 0;

    try switch (num) {
        1 => day1.run(stdout),
        0, 2 => day2.run(alloc, stdout),

        else => std.log.err("Invalid Day!\n", .{}),
    };
}
