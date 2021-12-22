const std = @import("std");
const helper = @import("helper.zig");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const input = @embedFile("../inputs/day22.txt");

pub fn run(alloc: Allocator, stdout_: anytype) !void {
    var entries = ArrayList(InputEntry).init(alloc);
    defer entries.deinit();
}

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
    x: Range(i64),
    y: Range(i64),
    z: Range(i64),
    on: bool,

    pub fn parse(line: []const u8) !@This() {
        const on = std.mem.startsWith(u8, line, "on");
        var tokens = tokenize(u8, line, "onxyz=., ");

        var ranges: [3]Range(i64) = undefined;
        for (ranges) |*range| {
            const low = try parseInt(i64, tokens.next().?, 10);
            const high = try parseInt(i64, tokens.next().?, 10);

            range.* = Range(i64).init(low, high);
        }

        return .{
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
