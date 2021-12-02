const std = @import("std");
const Allocator = std.mem.Allocator;

const input = @embedFile("../inputs/day1.txt");

pub fn run(alloc: *Allocator, stdout: anytype) !void {
    _ = alloc;
    try stdout.print("-- Day 1 --\n", .{});
    try stdout.print("Part 1: {}\n", .{try part1()});
    try stdout.print("Part 2: {}\n", .{try part2()});
}

fn part1() !i32 {
    var last: ?i32 = null;
    var increments: i32 = 0;
    var lines = std.mem.tokenize(u8, input, "\r\n");

    while (lines.next()) |line| {
        const parsed = try std.fmt.parseInt(i32, line, 0);
        defer last = parsed;

        if (last == null) {
            continue;
        }

        if (parsed > last.?) {
            increments += 1;
        }
    }

    return increments;
}

fn part2() !i32 {
    var window: [3]i32 = .{undefined} ** 3;

    var increments: i32 = 0;

    var lines = std.mem.tokenize(u8, input, "\r\n");
    for (window) |_| {
        const parsed = try std.fmt.parseInt(i32, lines.next().?, 0);
        advanceWindow(&window, parsed);
    }
    var last_sum: i32 = getSum(window);

    while (lines.next()) |line| {
        const parsed = try std.fmt.parseInt(i32, line, 0);
        advanceWindow(&window, parsed);

        const sum = getSum(window);
        defer last_sum = sum;

        if (last_sum < sum) {
            increments += 1;
        }
    }

    return increments;
}

fn advanceWindow(window: *[3]i32, newval: i32) void {
    window.*[0] = window.*[1];
    window.*[1] = window.*[2];
    window.*[2] = newval;
}

fn getSum(window: [3]i32) i32 {
    return window[0] + window[1] + window[2];
}
