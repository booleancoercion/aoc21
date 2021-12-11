const std = @import("std");
const helper = @import("helper.zig");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const input = @embedFile("../inputs/day10.txt");

pub fn run(alloc: Allocator, stdout: anytype) !void {
    var lines = tokenize(u8, input, "\r\n");

    var corrupted_sum: i64 = 0;
    var incomplete_scores = ArrayList(i64).init(alloc);
    var leftover_list = ArrayList(BraceKind).init(alloc);
    defer incomplete_scores.deinit();
    defer leftover_list.deinit();

    while (lines.next()) |line| {
        var corruption_score: ?i64 = null;
        var incomplete_score: ?i64 = null;
        try calculateScores(&leftover_list, line, &corruption_score, &incomplete_score);

        if (corruption_score) |score| {
            corrupted_sum += score;
        } else if (incomplete_score) |score| {
            try incomplete_scores.append(score);
        } else unreachable;
    }

    var items = incomplete_scores.items;
    sort(i64, items, {}, comptime std.sort.asc(i64));
    const incomplete_score = items[items.len / 2];

    try stdout.print("Part 1: {}\n", .{corrupted_sum});
    try stdout.print("Part 2: {}\n", .{incomplete_score});
}

fn calculateScores(
    leftover_list: *ArrayList(BraceKind),
    line: []const u8,
    corruption_score: *?i64,
    incomplete_score: *?i64,
) !void {
    var idx: usize = 0;
    leftover_list.clearRetainingCapacity();
    const maybe_corruption = try recursiveVerifier(line, &idx, leftover_list);

    if (maybe_corruption) |score| {
        corruption_score.* = score;
    } else {
        incomplete_score.* = calculateIncompleteScore(leftover_list.items);
    }
}

fn recursiveVerifier(
    line: []const u8,
    idx: *usize,
    leftover_list: *ArrayList(BraceKind),
) Allocator.Error!?i64 {
    if (isClosingBrace(line[idx.*])) unreachable;

    const kind = getBraceKind(line[idx.*]);
    idx.* += 1;
    if (idx.* >= line.len) {
        try leftover_list.append(kind);
        return null;
    }
    while (!isClosingBrace(line[idx.*])) {
        if (try recursiveVerifier(line, idx, leftover_list)) |score| {
            return score;
        }
        if (idx.* >= line.len) {
            try leftover_list.append(kind);
            return null;
        }
    }

    const new_kind = getBraceKind(line[idx.*]);
    if (new_kind != kind) {
        return getCorruptionScore(new_kind);
    } else {
        idx.* += 1;
        return null;
    }
}

fn isClosingBrace(char: u8) bool {
    return char == ')' or char == ']' or char == '}' or char == '>';
}

fn getBraceKind(char: u8) BraceKind {
    return switch (char) {
        '(', ')' => .round,
        '[', ']' => .square,
        '{', '}' => .curly,
        '<', '>' => .angle,
        else => unreachable,
    };
}

fn getCorruptionScore(kind: BraceKind) i64 {
    return switch (kind) {
        .round => 3,
        .square => 57,
        .curly => 1197,
        .angle => 25137,
    };
}

fn calculateIncompleteScore(items: []const BraceKind) i64 {
    var sum: i64 = 0;
    for (items) |item| {
        sum *= 5;
        sum += getIncompleteCoefficient(item);
    }

    return sum;
}

fn getIncompleteCoefficient(kind: BraceKind) i64 {
    return switch (kind) {
        .round => 1,
        .square => 2,
        .curly => 3,
        .angle => 4,
    };
}

const BraceKind = enum { round, square, curly, angle };

const eql = std.mem.eql;
const tokenize = std.mem.tokenize;
const split = std.mem.split;
const count = std.mem.count;
const parseUnsigned = std.fmt.parseUnsigned;
const parseInt = std.fmt.parseInt;
const sort = std.sort.sort;

test "calculate incomplete score" {
    const items: [4]BraceKind = .{ .square, .round, .curly, .angle };
    const score = calculateIncompleteScore(&items);
    try std.testing.expect(score == 294);
}
