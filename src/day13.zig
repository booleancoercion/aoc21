const std = @import("std");
const helper = @import("helper.zig");
const Allocator = std.mem.Allocator;
const Grid = helper.Grid;

const input = @embedFile("../inputs/day13.txt");

pub fn run(alloc: Allocator, stdout_: anytype) !void {
    var parsed = try Input.init(alloc, input);

    parsed.fold(parsed.rules[0]);
    const res1 = parsed.count();

    for (parsed.rules) |rule, i| {
        if (i == 0) continue;
        parsed.fold(rule);
    }

    if (stdout_) |stdout| {
        try stdout.print("Part 1: {}\n", .{res1});
        try stdout.print("Part 2:\n", .{});
        try parsed.printGrid(stdout);
    }
}

const Rule = union(enum) {
    fold_x: usize,
    fold_y: usize,

    const Self = @This();

    pub fn parseRule(line: []const u8) !Self {
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

const Input = struct {
    grid: Grid(bool),
    rules: []Rule,
    allocator: Allocator,
    limits: Point,

    const Self = @This();

    pub fn init(alloc: Allocator, str: []const u8) !Self {
        var grid_limit: Point = Point{ .x = 0, .y = 0 };
        var num_rules: usize = 0;

        try Self.getLimits(str, &grid_limit, &num_rules);
        var grid = try Grid(bool).init(alloc, grid_limit.x, grid_limit.y);
        std.mem.set(bool, grid.data, false);
        var rules = try alloc.alloc(Rule, num_rules);

        var lines = tokenize(u8, str, "\r\n");
        while (lines.next()) |line| {
            const pt = try Self.parseLine(line);
            grid.set(pt.x, pt.y, true);
            if (lines.rest()[0] == 'f') break;
        }

        for (rules) |*rule| {
            rule.* = try Rule.parseRule(lines.next().?);
        }
        if (lines.next() != null) unreachable;

        return Self{
            .grid = grid,
            .rules = rules,
            .allocator = alloc,
            .limits = grid_limit,
        };
    }

    pub fn count(self: Self) i32 {
        var sum: i32 = 0;
        var i: usize = 0;
        while (i < self.limits.x) : (i += 1) {
            var j: usize = 0;
            while (j < self.limits.y) : (j += 1) {
                if (self.grid.get(i, j)) sum += 1;
            }
        }

        return sum;
    }

    pub fn fold(self: *Self, rule: Rule) void {
        switch (rule) {
            .fold_x => |num| {
                var j: usize = 0;
                while (j < self.limits.y) : (j += 1) {
                    var i: usize = 1;
                    while (i < self.limits.x - num) : (i += 1) {
                        const val_original = self.grid.get(num - i, j);
                        const val_overlay = self.grid.get(num + i, j);
                        self.grid.set(num - i, j, val_original or val_overlay);
                    }
                }

                self.limits.x = num;
            },
            .fold_y => |num| {
                var i: usize = 0;
                while (i < self.limits.x) : (i += 1) {
                    var j: usize = 1;
                    while (j < self.limits.y - num) : (j += 1) {
                        const val_original = self.grid.get(i, num - j);
                        const val_overlay = self.grid.get(i, num + j);
                        self.grid.set(i, num - j, val_original or val_overlay);
                    }
                }

                self.limits.y = num;
            },
        }
    }

    pub fn deinit(self: Self) void {
        self.grid.deinit();
        self.allocator.free(self.rules);
    }

    pub fn printGrid(self: Self, stdout: anytype) !void {
        var j: usize = 0;
        while (j < self.limits.y) : (j += 1) {
            var i: usize = 0;
            while (i < self.limits.x) : (i += 1) {
                const ch: u8 = if (self.grid.get(i, j)) '#' else ' ';
                try stdout.print("{c}", .{ch});
            }
            try stdout.print("\n", .{});
        }
    }

    fn getLimits(str: []const u8, grid_limit: *Point, num_rules: *usize) !void {
        var lines = tokenize(u8, str, "\r\n");
        while (lines.next()) |line| {
            const pt = try Self.parseLine(line);
            grid_limit.x = std.math.max(pt.x + 1, grid_limit.x);
            grid_limit.y = std.math.max(pt.y + 1, grid_limit.y);
            if (lines.rest()[0] == 'f') break;
        }

        while (lines.next()) |_| {
            num_rules.* += 1;
        }
    }

    fn parseLine(line: []const u8) !Point {
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

const eql = std.mem.eql;
const tokenize = std.mem.tokenize;
const split = std.mem.split;
const count = std.mem.count;
const parseUnsigned = std.fmt.parseUnsigned;
const parseInt = std.fmt.parseInt;
const sort = std.sort.sort;
