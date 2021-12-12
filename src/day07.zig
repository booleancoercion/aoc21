const std = @import("std");
const helper = @import("helper.zig");
const Allocator = std.mem.Allocator;

const input = @embedFile("../inputs/day07.txt");

pub fn run(alloc: Allocator, stdout_: anytype) !void {
    const parsed = try parseInput(alloc);
    defer alloc.free(parsed);

    const res1 = try part1(alloc, parsed);
    const res2 = try part2(parsed);

    if (stdout_) |stdout| {
        try stdout.print("Part 1: {}\n", .{res1});
        try stdout.print("Part 2: {}\n", .{res2});
    }
}

fn part1(alloc: Allocator, parsed: []i32) !i32 {
    var crab_copy = try alloc.dupe(i32, parsed);
    defer alloc.free(crab_copy);

    sort(i32, crab_copy, {}, comptime std.sort.asc(i32));
    const median = crab_copy[crab_copy.len / 2];

    const minima = blk: {
        // if the median is undisputed, it's also the minima
        if (crab_copy.len % 2 == 1) {
            break :blk median;
        }

        // otherwise, we need to see which possible median has more impact
        // when it's chosen:
        const candidate = crab_copy[(crab_copy.len + 1) / 2];
        if (count(i32, crab_copy, &.{candidate}) > count(i32, crab_copy, &.{median})) { // i am aware this is inefficient
            break :blk candidate;
        } else {
            break :blk median;
        }
    };

    var fuel: i32 = 0;
    for (crab_copy) |crab| {
        fuel += try std.math.absInt(crab - minima);
    }

    return fuel;
}

fn part2(parsed: []i32) !i64 {
    const mean = @divFloor(helper.sum(i32, parsed), @intCast(i32, parsed.len)); // guess
    // my guess ended up being correct: see <https://www.reddit.com/r/adventofcode/comments/rawxad/2021_day_7_part_2_i_wrote_a_paper_on_todays/>

    var fuel: i64 = 0;
    for (parsed) |crab| {
        var diff = try std.math.absInt(mean - crab);
        fuel += nsum(diff);
    }

    return fuel;
}

fn nsum(x: i32) i32 {
    return @divExact(x * (x + 1), 2);
}

fn parseInput(alloc: Allocator) ![]i32 {
    const num_crabs = count(u8, input, ",") + 1;
    var crab_arr = try alloc.alloc(i32, num_crabs);

    var tokens = tokenize(u8, input, ",\n");
    for (crab_arr) |*crab| {
        crab.* = try parseInt(i32, tokens.next().?, 10);
    }

    return crab_arr;
}

const tokenize = std.mem.tokenize;
const count = std.mem.count;
const parseUnsigned = std.fmt.parseUnsigned;
const parseInt = std.fmt.parseInt;
const sort = std.sort.sort;
