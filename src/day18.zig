const std = @import("std");
const helper = @import("helper.zig");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const input = @embedFile("../inputs/day18.txt");

pub fn run(alloc: Allocator, stdout_: anytype) !void {
    var arena = std.heap.ArenaAllocator.init(alloc);
    const arena_alloc = arena.allocator();
    defer arena.deinit();

    const rawnums = try getRawNums(arena_alloc, input);
    const res1 = try part1(rawnums.items);
    const res2 = try part2(rawnums.items);

    if (stdout_) |stdout| {
        try stdout.print("Part 1: {}\n", .{res1});
        try stdout.print("Part 2: {}\n", .{res2});
    }
}

fn part1(rawnums: []const RawNum) !i64 {
    var acc = try rawnums[0].clone();
    var i: usize = 1;
    while (i < rawnums.len) : (i += 1) {
        try acc.addToSelf(rawnums[i]);
    }

    return acc.getMagnitude();
}

fn part2(rawnums: []const RawNum) !i64 {
    var max: i64 = std.math.minInt(i64);

    var i: usize = 0;
    while (i < rawnums.len) : (i += 1) {
        var j: usize = 0;
        while (j < rawnums.len) : (j += 1) {
            if (i == j) continue;
            var base = try rawnums[i].clone();
            try base.addToSelf(rawnums[j]);

            max = std.math.max(max, base.getMagnitude());
        }
    }

    return max;
}

fn getRawNums(alloc: Allocator, inp: []const u8) !ArrayList(RawNum) {
    var list = ArrayList(RawNum).init(alloc);
    var lines = helper.getlines(inp);
    while (lines.next()) |line| {
        const rawnum = try RawNum.fromLine(alloc, line);
        try list.append(rawnum);
    }

    return list;
}

const RawNumElem = union(enum) {
    open_brace,
    close_brace,
    number: u8,
};

const RawNum = struct {
    elems: ArrayList(RawNumElem),

    const Self = @This();

    pub fn fromLine(alloc: Allocator, line: []const u8) !Self {
        var list = try ArrayList(RawNumElem).initCapacity(alloc, line.len);

        for (line) |ch| {
            try list.append(switch (ch) {
                '[' => .open_brace,
                ']' => .close_brace,
                else => if (!std.ascii.isDigit(ch)) continue else .{ .number = ch - '0' },
            });
        }

        return Self{ .elems = list };
    }

    pub fn addToSelf(self: *Self, other: Self) !void {
        try self.concatToSelf(other);
        try self.reduce();
    }

    pub fn clone(self: Self) !Self {
        var newlist = try ArrayList(RawNumElem).initCapacity(self.elems.allocator, self.elems.capacity);
        try newlist.appendSlice(self.elems.items);

        return Self{ .elems = newlist };
    }

    fn concatToSelf(self: *Self, other: Self) !void {
        try self.elems.insert(0, .open_brace);
        try self.elems.appendSlice(other.elems.items);
        try self.elems.append(.close_brace);
    }

    fn reduce(self: *Self) !void {
        while (try self.reduceOnce()) {}
    }

    fn reduceOnce(self: *Self) !bool {
        var nesting_level: i32 = 0;

        // these loops must be separate because exploding must happen
        // before splitting.
        for (self.elems.items) |item, i| switch (item) {
            .open_brace => if (nesting_level >= 4) {
                self.explodeAt(i);
                return true;
            } else {
                nesting_level += 1;
            },

            .close_brace => nesting_level -= 1,

            .number => {},
        };

        for (self.elems.items) |item, i| switch (item) {
            .open_brace, .close_brace => {},
            .number => |num| if (num >= 10) {
                try self.splitAt(i);
                return true;
            },
        };

        return false;
    }

    fn explodeAt(self: *Self, i: usize) void {
        var items = self.elems.items;

        const left = items[i + 1].number;
        const right = items[i + 2].number;

        self.addNumToFirstLeft(i, left);
        self.addNumToFirstRight(i + 3, right);

        const new_items: [1]RawNumElem = .{.{ .number = 0 }};
        self.elems.replaceRange(i, 4, &new_items) catch unreachable;
    }

    fn addNumToFirstLeft(self: *Self, i: usize, num: u8) void {
        var j: usize = 1;
        while (j <= i) : (j += 1) {
            switch (self.elems.items[i - j]) {
                .number => |*found| {
                    found.* += num;
                    break;
                },
                else => {},
            }
        }
    }

    fn addNumToFirstRight(self: *Self, i: usize, num: u8) void {
        var j: usize = 1;
        while (i + j < self.elems.items.len) : (j += 1) {
            switch (self.elems.items[i + j]) {
                .number => |*found| {
                    found.* += num;
                    break;
                },
                else => {},
            }
        }
    }

    fn splitAt(self: *Self, i: usize) !void {
        const num = self.elems.items[i].number;
        const left = num / 2;
        const right = num - left;

        const new_items: [4]RawNumElem = .{
            .open_brace,
            .{ .number = left },
            .{ .number = right },
            .close_brace,
        };

        try self.elems.replaceRange(i, 1, &new_items);
    }

    fn getMagnitude(self: Self) i64 {
        var i: usize = 0;
        return self.getMagnitudeInner(&i);
    }

    fn getMagnitudeInner(self: Self, i: *usize) i64 {
        switch (self.elems.items[i.*]) {
            .number => |num| return num,
            .close_brace => unreachable,
            .open_brace => {
                i.* += 1;
                const left = self.getMagnitudeInner(i);
                i.* += 1;
                const right = self.getMagnitudeInner(i);
                i.* += 1;

                return 3 * left + 2 * right;
            },
        }
    }

    fn print(self: *const Self) void {
        const stdout = std.io.getStdOut().writer();
        for (self.elems.items) |item| switch (item) {
            .open_brace => stdout.print("[ ", .{}) catch unreachable,
            .close_brace => stdout.print("] ", .{}) catch unreachable,
            .number => |n| stdout.print("{} ", .{n}) catch unreachable,
        };

        stdout.print("\n", .{}) catch unreachable;
    }
};

const eql = std.mem.eql;
const tokenize = std.mem.tokenize;
const split = std.mem.split;
const count = std.mem.count;
const parseUnsigned = std.fmt.parseUnsigned;
const parseInt = std.fmt.parseInt;
const sort = std.sort.sort;
