const std = @import("std");
const Allocator = std.mem.Allocator;
const Writer = std.io.Writer;

const art = @embedFile("../art.txt");

const Days = struct {
    pub const day01 = @import("day01.zig");
    pub const day02 = @import("day02.zig");
    pub const day03 = @import("day03.zig");
    pub const day04 = @import("day04.zig");
    pub const day05 = @import("day05.zig");
    pub const day06 = @import("day06.zig");
    pub const day07 = @import("day07.zig");
    pub const day08 = @import("day08.zig");
    pub const day09 = @import("day09.zig");
    pub const day10 = @import("day10.zig");
    pub const day11 = @import("day11.zig");
    pub const day12 = @import("day12.zig");
};

const days: usize = std.meta.declarations(Days).len;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const stdout = std.io.getStdOut().writer();
    try stdout.print("{s}\n", .{art});

    var args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args); // i know this is a no-op, but if i ever decide to change allocator this is necessary

    const num_opt: ?usize = if (args.len <= 1) null else std.fmt.parseUnsigned(usize, args[1], 0) catch null;
    const num = num_opt orelse days;

    if (num < 1 or num > days) {
        std.log.err("Invalid day number!\n", .{});
    } else {
        var buffer: [5]u8 = undefined;
        const day = try std.fmt.bufPrint(&buffer, "day{d:0>2}", .{num});

        inline for (std.meta.declarations(Days)) |decl| {
            if (std.mem.eql(u8, day, decl.name)) {
                const cmd = @field(Days, decl.name);

                try stdout.print("-- Day {} --\n", .{num});
                return cmd.run(alloc, stdout);
            }
        }

        // if we're here, none of the days have been executed.
        std.log.err("This day hasn't been solved yet!\n", .{});
    }
}
