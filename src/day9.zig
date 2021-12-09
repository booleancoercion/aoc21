const std = @import("std");
const helper = @import("helper.zig");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const HashMap = std.AutoHashMap;

const PointSet = HashMap(Point, void);

const input = @embedFile("../inputs/day9.txt");

pub fn run(alloc: *Allocator, stdout: anytype) !void {
    const heightmap = try Heightmap.init(alloc, input);
    defer heightmap.deinit();

    var low_points = ArrayList(Point).init(alloc);

    const res1 = try part1(&heightmap, &low_points);
    const res2 = try part2(alloc, &heightmap, &low_points);

    try stdout.print("Part 1: {}\n", .{res1});
    try stdout.print("Part 2: {}\n", .{res2});
}

fn part1(heightmap: *const Heightmap, low_points: *ArrayList(Point)) !i32 {
    var sum: i32 = 0;
    var i: usize = 0;
    while (i < heightmap.m) : (i += 1) {
        var j: usize = 0;
        while (j < heightmap.n) : (j += 1) {
            const low_point = heightmap.isLowPoint(i, j);
            if (low_point) {
                sum += heightmap.get(i, j).? + 1;
                try low_points.append(Point{ .x = i, .y = j });
            }
        }
    }

    return sum;
}

fn part2(
    alloc: *Allocator,
    heightmap: *const Heightmap,
    low_points: *const ArrayList(Point),
) !i32 {
    var biggest: [3]i32 = .{0} ** 3;

    var visited = PointSet.init(alloc);
    var to_check = PointSet.init(alloc);
    var latest = PointSet.init(alloc);

    defer visited.deinit();
    defer to_check.deinit();
    defer latest.deinit();

    for (low_points.items) |point| {
        const basin = try heightmap.getBasinSize(point, &visited, &to_check, &latest);
        updateBiggest(&biggest, @intCast(i32, basin));
    }

    return biggest[0] * biggest[1] * biggest[2];
}

fn updateBiggest(biggest: *[3]i32, basin: i32) void {
    if (basin > biggest[2]) {
        biggest[0] = biggest[1];
        biggest[1] = biggest[2];
        biggest[2] = basin;
    } else if (basin > biggest[1]) {
        biggest[0] = biggest[1];
        biggest[1] = basin;
    } else if (basin > biggest[0]) {
        biggest[0] = basin;
    }
}

const Point = struct {
    x: usize,
    y: usize,
};

const Heightmap = struct {
    allocator: *Allocator,
    m: usize,
    n: usize,
    data: []const u8,

    const Self = @This();

    pub fn init(alloc: *Allocator, inp: []const u8) !Self {
        var lines = tokenize(u8, inp, "\r\n");
        const n = lines.next().?.len;

        const m = count(u8, inp, "\n");

        var data = try alloc.alloc(u8, m * n);
        var i: usize = 0;
        for (inp) |char| {
            if (!std.ascii.isDigit(char)) continue;
            data[i] = char - '0';
            i += 1;
        }

        return Self{ .allocator = alloc, .m = m, .n = n, .data = data };
    }

    fn isValidPos(self: *const Self, i: usize, j: usize) bool {
        return i < self.m and j < self.n;
    }

    pub fn get(self: *const Self, i: usize, j: usize) ?u8 {
        if (!self.isValidPos(i, j)) return null;

        return self.data[i * self.n + j];
    }

    pub fn getPoint(self: *const Self, point: Point) ?u8 {
        return self.get(point.x, point.y);
    }

    pub fn adjacentIter(self: *const Self, i: usize, j: usize) ?AdjacentIterator {
        if (!self.isValidPos(i, j)) return null;
        return AdjacentIterator{ .heightmap = self, .i = i, .j = j, .counter = 0 };
    }

    pub fn isLowPoint(self: *const Self, i: usize, j: usize) bool {
        const val = self.get(i, j).?;
        if (val == 9) return false; // shortcut
        var adj = self.adjacentIter(i, j).?;
        while (adj.next()) |neighbor| {
            if (val >= neighbor) return false;
        }

        return true;
    }

    pub fn getBasinSize(
        self: *const Self,
        origin: Point,
        visited: *PointSet,
        to_check_: *PointSet,
        latest_: *PointSet,
    ) !usize {
        var to_check = to_check_;
        var latest = latest_;

        visited.clearRetainingCapacity();
        to_check.clearRetainingCapacity();
        latest.clearRetainingCapacity();
        try to_check.put(origin, {});

        while (to_check.count() > 0) {
            var keys = to_check.keyIterator();
            while (keys.next()) |key| {
                try visited.put(key.*, {});
            }

            keys = to_check.keyIterator();
            while (keys.next()) |key| {
                var adj = self.adjacentIter(key.x, key.y).?;
                while (adj.nextPoint()) |point| {
                    if (self.getPoint(point).? == 9) continue;
                    if (!visited.contains(point)) try latest.put(point, {});
                }
            }

            to_check.clearRetainingCapacity();
            std.mem.swap(*PointSet, &to_check, &latest);
        }

        return visited.count();
    }

    pub fn deinit(self: *const Self) void {
        self.allocator.free(self.data);
    }

    const AdjacentIterator = struct {
        heightmap: *const Heightmap,
        i: usize,
        j: usize,

        counter: u8,

        pub fn nextPoint(self: *@This()) ?Point {
            const i = self.i;
            const j = self.j;
            if (self.counter == 0) {
                self.counter += 1;
                if (i > 0) return Point{ .x = i - 1, .y = j };
            }

            if (self.counter == 1) {
                self.counter += 1;
                if (j > 0) return Point{ .x = i, .y = j - 1 };
            }

            if (self.counter == 2) {
                self.counter += 1;
                if (i < self.heightmap.m - 1) return Point{ .x = i + 1, .y = j };
            }

            if (self.counter == 3) {
                self.counter += 1;
                if (j < self.heightmap.n - 1) return Point{ .x = i, .y = j + 1 };
            }

            return null;
        }

        pub fn next(self: *@This()) ?u8 {
            if (self.nextPoint()) |point| {
                return self.heightmap.getPoint(point);
            }

            return null;
        }
    };
};

const eql = std.mem.eql;
const tokenize = std.mem.tokenize;
const split = std.mem.split;
const count = std.mem.count;
const parseUnsigned = std.fmt.parseUnsigned;
const parseInt = std.fmt.parseInt;
const sort = std.sort.sort;
