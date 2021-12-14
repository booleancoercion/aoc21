const std = @import("std");
const helper = @import("helper.zig");
const Allocator = std.mem.Allocator;
const HashMap = std.AutoHashMap;

const input = @embedFile("../inputs/day14.txt");

pub fn run(alloc: Allocator, stdout_: anytype) !void {
    var polymer = try Polymer.init(alloc, input);
    defer polymer.deinit();

    var i: usize = 0;
    while (i < 10) : (i += 1) {
        try polymer.step();
    }
    const res1 = try polymer.getMostLeastDiff(alloc);

    while (i < 40) : (i += 1) { // the 40 here is not a bug
        try polymer.step();
    }
    const res2 = try polymer.getMostLeastDiff(alloc);

    if (stdout_) |stdout| {
        try stdout.print("Part 1: {}\n", .{res1});
        try stdout.print("Part 2: {}\n", .{res2});
    }
}

const Polymer = struct {
    current: HashMap([2]u8, i64),
    buffer: HashMap([2]u8, i64),
    rules: HashMap([2]u8, u8),
    last: u8,

    const Self = @This();

    pub fn init(alloc: Allocator, inp: []const u8) !Self {
        var current = HashMap([2]u8, i64).init(alloc);
        var rules = HashMap([2]u8, u8).init(alloc);

        var lines = tokenize(u8, inp, "\r\n");
        const fst = lines.next().?;
        try Self.addInitial(fst, &current);

        while (lines.next()) |line| {
            const rule = Rule.parse(line);
            try rules.put(rule.pattern, rule.char);
        }

        return Self{
            .current = current,
            .buffer = HashMap([2]u8, i64).init(alloc),
            .rules = rules,
            .last = fst[fst.len - 1],
        };
    }

    pub fn step(self: *Self) !void {
        self.buffer.clearRetainingCapacity();

        var iter = self.current.iterator();
        while (iter.next()) |entry| {
            const key = entry.key_ptr.*;
            const mid = self.rules.get(key).?;

            const key1 = .{ key[0], mid };
            const key2 = .{ mid, key[1] };

            const keys: [2][2]u8 = .{ key1, key2 };

            for (keys) |newkey| {
                var newentry = try self.buffer.getOrPutValue(newkey, 0);
                newentry.value_ptr.* += entry.value_ptr.*;
            }
        }

        std.mem.swap(HashMap([2]u8, i64), &self.buffer, &self.current);
    }

    pub fn getMostLeastDiff(self: Self, alloc: Allocator) !i64 {
        var count_map = HashMap(u8, i64).init(alloc);
        defer count_map.deinit();

        try count_map.put(self.last, 1);

        var iter = self.current.iterator();
        while (iter.next()) |entry| {
            const val = entry.value_ptr.*;
            // we're only considering the first char of each pair because
            // they're overlapping and we don't want to count a character twice.
            const ch = entry.key_ptr.*[0];

            const newentry = try count_map.getOrPutValue(ch, 0);
            newentry.value_ptr.* += val;
        }

        var min: i64 = math.maxInt(i64);
        var max: i64 = math.minInt(i64);
        var counts = count_map.valueIterator();
        while (counts.next()) |cnt| {
            min = math.min(min, cnt.*);
            max = math.max(max, cnt.*);
        }

        return max - min;
    }

    pub fn deinit(self: *Self) void {
        self.current.deinit();
        self.buffer.deinit();
        self.rules.deinit();
    }

    fn addInitial(line: []const u8, map: *HashMap([2]u8, i64)) !void {
        var i: usize = 0;
        while (i + 1 < line.len) : (i += 1) {
            var entry = try map.getOrPutValue(.{ line[i], line[i + 1] }, 0);
            entry.value_ptr.* += 1;
        }
    }
};

const Rule = struct {
    pattern: [2]u8,
    char: u8,

    const Self = @This();

    pub fn parse(line: []const u8) Self {
        // 0123456
        // AB -> C
        return Self{
            .pattern = .{ line[0], line[1] },
            .char = line[6],
        };
    }
};

const eql = std.mem.eql;
const tokenize = std.mem.tokenize;
const split = std.mem.split;
const count = std.mem.count;
const parseUnsigned = std.fmt.parseUnsigned;
const parseInt = std.fmt.parseInt;
const sort = std.sort.sort;
const math = std.math;
