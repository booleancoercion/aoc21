const std = @import("std");
const Allocator = std.mem.Allocator;

const input = @embedFile("../inputs/day05.txt");
const i32_max: i32 = std.math.maxInt(i32);
const i32_min: i32 = std.math.minInt(i32);

const LineKind = enum { const_x, const_y, diagonal };
const Line = struct {
    x: [2]i32,
    y: [2]i32,
    kind: LineKind,

    const Self = @This();

    pub fn init(p0: [2]i32, p1: [2]i32) Self {
        const kind: LineKind = if (p0[0] == p1[0])
            LineKind.const_x
        else if (p0[1] == p1[1])
            LineKind.const_y
        else
            LineKind.diagonal;

        const x: [2]i32 = .{ p0[0], p1[0] };
        const y: [2]i32 = .{ p0[1], p1[1] };

        return Self{
            .x = x,
            .y = y,
            .kind = kind,
        };
    }

    /// Inserts all of the points on this line into the given board, and returns
    /// the amount of points that were upgraded to count 2.
    pub fn insertToBoard(self: *Self, board: *Board) ?i32 {
        var amount: i32 = 0;
        var x = self.x[0];
        var y = self.y[0];

        switch (self.kind) {
            .const_x => {
                y = @minimum(y, self.y[1]);
                while (y <= @maximum(self.y[0], self.y[1])) : (y += 1) {
                    amount += Self.insertPoint(board, x, y) orelse return null;
                }
            },
            .const_y => {
                x = @minimum(x, self.x[1]);
                while (x <= @maximum(self.x[0], self.x[1])) : (x += 1) {
                    amount += Self.insertPoint(board, x, y) orelse return null;
                }
            },
            .diagonal => {
                const x_offset = Self.calcDelta(self.x);
                const y_offset = Self.calcDelta(self.y);

                var i: i32 = 0;
                const len = std.math.absInt(self.x[1] - self.x[0]) catch unreachable;
                while (i <= len) : (i += 1) {
                    amount += Self.insertPoint(board, x, y) orelse return null;

                    x += x_offset;
                    y += y_offset;
                }
            },
        }

        return amount;
    }

    fn calcDelta(arr: [2]i32) i32 {
        return if (arr[0] < arr[1]) 1 else -1;
    }

    fn insertPoint(board: *Board, x: i32, y: i32) ?i32 {
        const count = board.insertPoint(.{ x, y }) orelse return null;
        return if (count == 2) 1 else 0;
    }
};

const Board = struct {
    map: []i32, // maps Point -> Count (as a matrix)
    alloc: Allocator,
    bottom_left: [2]i32,
    x_length: usize,
    y_length: usize,

    const Self = @This();

    pub fn init(alloc: Allocator, bottom_left: [2]i32, top_right: [2]i32) !Self {
        const x_length = @intCast(usize, top_right[0] - bottom_left[0] + 1);
        const y_length = @intCast(usize, top_right[1] - bottom_left[1] + 1);

        var map = try alloc.alloc(i32, x_length * y_length);
        for (map) |*pos| {
            pos.* = 0;
        }

        return Self{
            .map = map,
            .alloc = alloc,
            .bottom_left = bottom_left,
            .x_length = x_length,
            .y_length = y_length,
        };
    }

    fn get(self: *Self, i: usize, j: usize) ?*i32 {
        if (i >= self.x_length or j >= self.y_length) return null;
        return &self.map[i * self.y_length + j];
    }

    pub fn getPoint(self: *Self, pt: [2]i32) ?*i32 {
        if (pt[0] < self.bottom_left[0] or pt[1] < self.bottom_left[1]) return null;

        const i = @intCast(usize, pt[0] - self.bottom_left[0]);
        const j = @intCast(usize, pt[1] - self.bottom_left[1]);

        return self.get(i, j);
    }

    /// Inserts a point into the board, and returns its updated count.
    pub fn insertPoint(self: *Self, point: [2]i32) ?i32 {
        var entry = self.getPoint(point) orelse return null;
        entry.* += 1;
        return entry.*;
    }

    pub fn deinit(self: *Self) void {
        self.alloc.free(self.map);
    }
};

pub fn run(alloc: Allocator, stdout: anytype) !void {
    var bottom_left: [2]i32 = undefined;
    var top_right: [2]i32 = undefined;
    const lines = try parseInput(alloc, &bottom_left, &top_right);
    defer alloc.free(lines);

    var board = try Board.init(alloc, bottom_left, top_right);
    defer board.deinit();

    const res1 = part1(lines, &board);
    const res2 = part2(lines, &board) + res1;

    try stdout.print("Part 1: {}\n", .{res1});
    try stdout.print("Part 2: {}\n", .{res2});
}

fn part1(lines: []Line, board: *Board) i32 {
    var counter: i32 = 0;
    for (lines) |*line| {
        if (line.kind == .diagonal) continue;
        counter += line.insertToBoard(board).?;
    }

    return counter;
}

fn part2(lines: []Line, board: *Board) i32 {
    var counter: i32 = 0;
    for (lines) |*line| {
        if (line.kind != .diagonal) continue;
        counter += line.insertToBoard(board).?;
    }

    return counter;
}

fn parseInput(alloc: Allocator, lower_left: *[2]i32, top_right: *[2]i32) ![]Line {
    const line_num = std.mem.count(u8, input, "\n");
    var linelist = try alloc.alloc(Line, line_num);

    var min_x = i32_max;
    var max_x = i32_min;
    var min_y = i32_max;
    var max_y = i32_min;

    var lines_iter = std.mem.tokenize(u8, input, "\r\n");
    for (linelist) |*line| {
        line.* = try parseLine(lines_iter.next().?);

        min_x = std.math.min3(min_x, line.x[0], line.x[1]);
        max_x = std.math.max3(max_x, line.x[0], line.x[1]);
        min_y = std.math.min3(min_y, line.y[0], line.y[1]);
        max_y = std.math.max3(max_y, line.y[0], line.y[1]);
    }

    lower_left.* = .{ min_x, min_y };
    top_right.* = .{ max_x, max_y };

    return linelist;
}

fn parseLine(str: []const u8) !Line {
    var points = std.mem.split(u8, str, " -> ");
    const p0 = try parsePoint(points.next().?);
    const p1 = try parsePoint(points.next().?);

    return Line.init(p0, p1);
}

fn parsePoint(str: []const u8) ![2]i32 {
    var nums = std.mem.split(u8, str, ",");
    const num0 = try std.fmt.parseInt(i32, nums.next().?, 10);
    const num1 = try std.fmt.parseInt(i32, nums.next().?, 10);

    return [2]i32{ num0, num1 };
}
