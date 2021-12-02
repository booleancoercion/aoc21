const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const Inst = union(enum) { forward: i32, down: i32, up: i32 };
const Day2Err = error{InvalidInstruction};

const input = @embedFile("../inputs/day2.txt");

pub fn run(alloc: *Allocator, stdout: anytype) !void {
    try stdout.print("-- Day 2 --\n", .{});

    const parsed: ArrayList(Inst) = try parseInput(alloc);
    defer parsed.deinit();

    try stdout.print("Part 1: {}\n", .{try part1(parsed.items)});
    try stdout.print("Part 2: {}\n", .{try part2(parsed.items)});
}

fn part1(parsed: []const Inst) !i64 {
    var depth: i64 = 0;
    var position: i64 = 0;

    for (parsed) |inst| {
        switch (inst) {
            .forward => |num| position += num,
            .down => |num| depth += num,
            .up => |num| depth -= num,
        }
    }

    return depth * position;
}

fn part2(parsed: []const Inst) !i64 {
    var depth: i64 = 0;
    var position: i64 = 0;
    var aim: i32 = 0;

    for (parsed) |inst| {
        switch (inst) {
            .forward => |num| {
                position += num;
                depth += aim * num;
            },
            .down => |num| aim += num,
            .up => |num| aim -= num,
        }
    }

    return depth * position;
}

/// Caller must deinit return value with a call to `.deinit()` when done.
fn parseInput(alloc: *Allocator) !ArrayList(Inst) {
    var list = ArrayList(Inst).init(alloc);

    var lines = std.mem.tokenize(u8, input, "\r\n");

    while (lines.next()) |line| {
        try list.append(try parseInstruction(line));
    }

    return list;
}

fn parseInstruction(line: []const u8) !Inst {
    var parts = std.mem.split(u8, line, " ");

    const kind = parts.next() orelse return Day2Err.InvalidInstruction;
    const num_str = parts.next() orelse return Day2Err.InvalidInstruction;

    const num = try std.fmt.parseInt(i32, num_str, 0);

    if (std.mem.eql(u8, kind, "forward")) {
        return Inst{ .forward = num };
    } else if (std.mem.eql(u8, kind, "down")) {
        return Inst{ .down = num };
    } else if (std.mem.eql(u8, kind, "up")) {
        return Inst{ .up = num };
    } else {
        return Day2Err.InvalidInstruction;
    }
}
