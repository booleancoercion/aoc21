const std = @import("std");
const helper = @import("helper.zig");
const Allocator = std.mem.Allocator;

const input = @embedFile("../inputs/day06.txt");

const valid_values = 9;

pub fn run(alloc: Allocator, stdout_: anytype) !void {
    const fish = try parseInput(alloc);
    defer alloc.free(fish);

    const res1 = simulate(fish, 80);
    const res2 = simulate(fish, 256);

    if (stdout_) |stdout| {
        try stdout.print("Part 1: {}\n", .{res1});
        try stdout.print("Part 2: {}\n", .{res2});
    }
}

fn simulate(fish: []u8, simulation_time: i32) i64 {
    var amounts = std.mem.zeroes([valid_values]i64);

    // initialize amounts
    for (fish) |fsh| {
        amounts[@intCast(usize, fsh)] += 1;
    }

    var will_birth: usize = 0;
    var i: i32 = 0;
    while (i < simulation_time) : (i += 1) {
        const resting_idx: usize = (will_birth + 7) % valid_values;
        amounts[resting_idx] += amounts[will_birth];

        will_birth = (will_birth + 1) % valid_values;
    }

    return helper.sum(i64, &amounts);
}

fn parseInput(alloc: Allocator) ![]u8 {
    var tokens = tokenize(u8, input, ",\n");
    const fish_amt = count(u8, input, ",") + 1;

    var fish = try alloc.alloc(u8, fish_amt);
    for (fish) |*fsh| {
        fsh.* = try parseUnsigned(u8, tokens.next().?, 10);
    }

    return fish;
}

const tokenize = std.mem.tokenize;
const count = std.mem.count;
const parseUnsigned = std.fmt.parseUnsigned;
