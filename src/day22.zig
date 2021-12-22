const std = @import("std");
const helper = @import("helper.zig");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const HashMap = std.AutoHashMap;

const input = @embedFile("../inputs/day22.txt");

pub fn run(alloc: Allocator, stdout_: anytype) !void {
    var entries = ArrayList(InputEntry).init(alloc);
    defer entries.deinit();

    var lines = helper.getlines(input);
    while (lines.next()) |line| {
        const entry = try InputEntry.parse(line);
        try entries.append(entry);
    }

    const res1 = try part1(alloc, entries.items);

    if (stdout_) |stdout| {
        try stdout.print("Part 1: {}\n", .{res1});
    }
}

fn part1(alloc: Allocator, entries: []InputEntry) !u32 {
    var pointmap = HashMap(Point, void).init(alloc);
    defer pointmap.deinit();

    for (entries) |entry| {
        if (entry.x.low > 50 or entry.x.low < -50) break;
        var xiter = entry.x.iter();
        while (xiter.next()) |x| {
            var yiter = entry.y.iter();
            while (yiter.next()) |y| {
                var ziter = entry.z.iter();
                while (ziter.next()) |z| {
                    const key = Point{ .x = x, .y = y, .z = z };
                    if (entry.on) {
                        try pointmap.put(key, {});
                    } else {
                        _ = pointmap.remove(key);
                    }
                }
            }
        }
    }

    return pointmap.count();
}

const Point = struct { x: i32, y: i32, z: i32 };

fn Range(comptime T: type) type {
    return struct {
        low: T,
        high: T,

        const Self = @This();

        pub fn init(low: T, high: T) Self {
            if (low > high) unreachable;
            return .{ .low = low, .high = high };
        }

        pub fn contains(self: Self, elem: T) bool {
            return self.low <= elem and elem <= self.high;
        }

        pub fn iter(self: Self) RangeIterator {
            return .{ .range = self, .val = self.low };
        }

        const RangeIterator = struct {
            range: Self, // Range(T)
            val: T,

            pub fn next(self: *@This()) ?T {
                if (self.val > self.range.high) return null;
                defer self.val += 1;
                return self.val;
            }
        };
    };
}

const InputEntry = struct {
    x: Range(i32),
    y: Range(i32),
    z: Range(i32),
    on: bool,

    pub fn parse(line: []const u8) !@This() {
        const on = std.mem.startsWith(u8, line, "on");
        var tokens = tokenize(u8, line, "ofnxyz=., ");

        var ranges: [3]Range(i32) = undefined;
        for (ranges) |*range| {
            const low = try parseInt(i32, tokens.next().?, 10);
            const high = try parseInt(i32, tokens.next().?, 10);

            range.* = Range(i32).init(low, high);
        }

        return @This(){
            .x = ranges[0],
            .y = ranges[1],
            .z = ranges[2],
            .on = on,
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
