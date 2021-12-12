const std = @import("std");
const Allocator = std.mem.Allocator;
const TailQueue = std.TailQueue(IntType);
const Node = TailQueue.Node;

const input = @embedFile("../inputs/day03.txt");

const IntType = u16;
const int_size = @bitSizeOf(IntType);

var real_length: i32 = 0;

pub fn run(alloc: Allocator, stdout_: anytype) !void {
    const parsed = try parseInput(alloc);
    defer alloc.free(parsed);

    const res1 = part1(parsed);
    const res2 = try part2(alloc, parsed);

    if (stdout_) |stdout| {
        try stdout.print("Part 1: {}\n", .{res1});
        try stdout.print("Part 2: {}\n", .{res2});
    }
}

fn part1(parsed: []IntType) i32 {
    var counters: [int_size]i32 = .{0} ** int_size;

    for (parsed) |num| {
        var i: usize = 0;
        while (i < int_size) : (i += 1) {
            if (num & getMask(i) != 0) {
                counters[i] += 1;
            }
        }
    }

    // I could do epsilon = ~gamma, but i wanted to not mess with bits widths
    // and just have a nice round u16, so here we are.
    var gamma: IntType = 0;
    var epsilon: IntType = 0;
    for (counters) |counter, i| {
        if (i >= real_length) {
            break;
        }
        const mask = getMask(i);
        if (2 * counter > parsed.len) {
            gamma |= mask;
        } else {
            epsilon |= mask;
        }
    }

    return @as(i32, epsilon) * @as(i32, gamma);
}

const BitCriteria = enum {
    most_common,
    least_common,
};

fn part2(alloc: Allocator, parsed: []IntType) !i32 {
    var nodes: []Node = try alloc.alloc(Node, parsed.len);
    defer alloc.free(nodes);
    for (parsed) |num, i| {
        nodes[i].data = num;
    }

    const oxygen_rate = getRate(nodes, BitCriteria.most_common, 1);
    const co2_rate = getRate(nodes, BitCriteria.least_common, 0);

    return oxygen_rate * co2_rate;
}

fn getRate(nodes: []Node, criteria: BitCriteria, default: u1) i32 {
    var list = TailQueue{};
    for (nodes) |*node| {
        list.prepend(node);
    }

    var i: i32 = real_length - 1;
    while (list.len > 1 and i >= 0) : (i -= 1) {
        const bit = findBitByCriteria(i, &list, criteria) orelse default;
        const mask = getMask(i);

        var curr = list.first;
        while (curr) |node| {
            if ((node.data & mask == 0) == (bit == 0)) {
                const next = node.next;
                list.remove(node);
                curr = next;
            } else {
                curr = node.next;
            }
        }
    }

    if (list.len == 0) unreachable;
    return list.first.?.data;
}

fn findBitByCriteria(idx: i32, list: *TailQueue, criteria: BitCriteria) ?u1 {
    const mask = getMask(idx);

    var zero_count: i32 = 0;
    var curr = list.first;
    while (curr) |node| : (curr = node.next) {
        if (node.data & mask == 0) {
            zero_count += 1;
        }
    }

    if (2 * zero_count > list.len) {
        return switch (criteria) {
            .least_common => 1,
            .most_common => 0,
        };
    } else if (2 * zero_count < list.len) {
        return switch (criteria) {
            .least_common => 0,
            .most_common => 1,
        };
    } else {
        return null;
    }
}

fn getMask(val: anytype) IntType {
    return std.math.shl(IntType, 1, val);
}

fn parseInput(alloc: Allocator) ![]IntType {
    var lines = std.mem.tokenize(u8, input, "\r\n");

    const length = std.mem.count(u8, input, "\n"); // no. of lines

    var output: []IntType = try alloc.alloc(IntType, length);

    var i: usize = 0;
    while (lines.next()) |line| : (i += 1) {
        output[i] = try std.fmt.parseUnsigned(IntType, line, 2);

        if (real_length == 0) {
            real_length = @intCast(i32, line.len);
        }
    }

    return output;
}
