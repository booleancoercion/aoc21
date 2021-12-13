const std = @import("std");
const helper = @import("helper.zig");
const Allocator = std.mem.Allocator;
const HashMap = std.AutoHashMap;
const ArrayList = std.ArrayList;

const input = @embedFile("../inputs/day13.txt");

pub fn run(alloc: Allocator, stdout_: anytype) !void {
    var parsed = try Input.init(alloc, input);
    defer parsed.deinit();

    const num_points = @intCast(usize, parsed.count());
    var point_cache = try ArrayList(Input.Point).initCapacity(alloc, num_points);
    defer point_cache.deinit();

    try parsed.fold(parsed.rules.items[0], &point_cache);
    const res1 = parsed.count();

    for (parsed.rules.items[1..]) |rule| {
        try parsed.fold(rule, &point_cache);
    }

    if (stdout_) |stdout| {
        try stdout.print("Part 1: {}\n", .{res1});
        try stdout.print("Part 2:\n", .{});
        try parsed.printGrid(stdout);
    }
}

const Input = struct {
    points: HashMap(Point, void),
    rules: ArrayList(Rule),

    const Self = @This();

    pub fn init(alloc: Allocator, inp: []const u8) !Self {
        var points = HashMap(Point, void).init(alloc);
        var rules = ArrayList(Rule).init(alloc);

        var lines = tokenize(u8, inp, "\r\n");
        while (lines.next()) |line| {
            const point = try Self.parsePoint(line);
            try points.put(point, {});

            if (lines.rest()[0] == 'f') break;
        }

        while (lines.next()) |line| {
            const rule = try Rule.init(line);
            try rules.append(rule);
        }

        return Self{ .points = points, .rules = rules };
    }

    pub fn fold(self: *Self, rule: Rule, point_cache: *ArrayList(Point)) !void {
        point_cache.clearRetainingCapacity();
        var point_iter = self.points.keyIterator();
        while (point_iter.next()) |point| {
            try point_cache.append(point.*);
        }

        for (point_cache.items) |point| {
            try self.foldPoint(point, rule);
        }
    }

    pub fn count(self: Self) HashMap(Point, void).Size {
        return self.points.count();
    }

    pub fn printGrid(self: Self, stdout: anytype) !void {
        var max = Point{ .x = 0, .y = 0 };
        var point_iter = self.points.keyIterator();

        while (point_iter.next()) |point| {
            max.x = std.math.max(max.x, point.x + 1);
            max.y = std.math.max(max.y, point.y + 1);
        }

        var j: usize = 0;
        while (j < max.y) : (j += 1) {
            var i: usize = 0;
            while (i < max.x) : (i += 1) {
                const point = Point{ .x = i, .y = j };
                const ch: u8 = if (self.points.contains(point)) '#' else ' ';
                try stdout.print("{c}", .{ch});
            }
            try stdout.print("\n", .{});
        }
    }

    fn foldPoint(self: *Self, point_: Point, rule: Rule) !void {
        var point = point_;
        switch (rule) {
            .fold_x => |num| {
                if (point.x < num) return;
                _ = self.points.remove(point);
                if (point.x > num) {
                    const offset = point.x - num;
                    point.x = num - offset;
                    try self.points.put(point, {});
                }
            },
            .fold_y => |num| {
                if (point.y < num) return;
                _ = self.points.remove(point);
                if (point.y > num) {
                    const offset = point.y - num;
                    point.y = num - offset;
                    try self.points.put(point, {});
                }
            },
        }
    }

    pub fn deinit(self: *Self) void {
        self.points.deinit();
        self.rules.deinit();
    }

    fn parsePoint(line: []const u8) !Point {
        var splut = split(u8, line, ",");
        const x_str = splut.next().?;
        const y_str = splut.next().?;
        if (splut.next() != null) unreachable;

        const x = try parseUnsigned(usize, x_str, 10);
        const y = try parseUnsigned(usize, y_str, 10);

        return Point{ .x = x, .y = y };
    }

    const Point = struct { x: usize, y: usize };
};

const Rule = union(enum) {
    fold_x: usize,
    fold_y: usize,

    const Self = @This();

    pub fn init(line: []const u8) !Self {
        var tokens = tokenize(u8, line, " =");
        _ = tokens.next().?; // fold
        _ = tokens.next().?; // along
        const letter = tokens.next().?; // x/y
        const num_str = tokens.next().?;
        if (tokens.next() != null) unreachable;

        const num: usize = try parseUnsigned(usize, num_str, 10);

        if (letter[0] == 'x') {
            return Self{ .fold_x = num };
        } else if (letter[0] == 'y') {
            return Self{ .fold_y = num };
        } else {
            unreachable;
        }
    }
};

const eql = std.mem.eql;
const tokenize = std.mem.tokenize;
const split = std.mem.split;
const count = std.mem.count;
const parseUnsigned = std.fmt.parseUnsigned;
const parseInt = std.fmt.parseInt;
const sort = std.sort.sort;
