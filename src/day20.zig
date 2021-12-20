const std = @import("std");
const helper = @import("helper.zig");
const Allocator = std.mem.Allocator;
const HashMap = std.AutoHashMap;

const input = @embedFile("../inputs/day20.txt");

pub fn run(alloc: Allocator, stdout_: anytype) !void {
    var lines = helper.getlines(input);
    const algo = getEnhancementAlgorithm(lines.next().?);
    var image = try Image.parse(alloc, lines.rest());
    defer image.deinit();

    try image.enhanceN(2, &algo);
    const res1 = image.pixels.count();

    try image.enhanceN(50 - 2, &algo);
    const res2 = image.pixels.count();

    if (stdout_) |stdout| {
        try stdout.print("Part 1: {}\n", .{res1});
        try stdout.print("Part 2: {}\n", .{res2});
    }
}

fn getEnhancementAlgorithm(line: []const u8) [512]bool {
    if (line.len != 512) unreachable;
    var arr: [512]bool = undefined;

    for (line) |ch, i| switch (ch) {
        '.' => arr[i] = false,
        '#' => arr[i] = true,
        else => unreachable,
    };

    return arr;
}

const Image = struct {
    pixels: HashMap(Point, void),
    buffer: HashMap(Point, void),
    bottom_left: Point,
    top_right: Point,
    outer_on: bool,

    const Self = @This();

    pub fn parse(alloc: Allocator, text: []const u8) !Self {
        var pixels = HashMap(Point, void).init(alloc);
        try pixels.ensureTotalCapacity(@intCast(HashMap(Point, void).Size, text.len));

        var buffer = HashMap(Point, void).init(alloc);
        try buffer.ensureTotalCapacity(pixels.capacity());

        var lines = helper.getlines(text);

        const linelen = lines.next().?.len;
        lines.reset();

        var i: i64 = 0;
        while (lines.next()) |line| : (i += 1) {
            for (line) |ch, j| {
                switch (ch) {
                    '.' => {},
                    '#' => try pixels.put(.{ .x = i, .y = @intCast(i64, j) }, {}),
                    else => unreachable,
                }
            }
        }

        return Self{
            .pixels = pixels,
            .buffer = buffer,
            .bottom_left = .{ .x = 0, .y = 0 },
            .top_right = .{
                .x = i - 1,
                .y = @intCast(i64, linelen - 1),
            },
            .outer_on = false,
        };
    }

    pub fn enhanceN(self: *Self, comptime n: comptime_int, algo: *const [512]bool) !void {
        comptime var i = 0;
        inline while (i < n) : (i += 1) {
            try self.enhanceOnce(algo);
        }
    }

    pub fn enhanceOnce(self: *Self, algo: *const [512]bool) !void {
        const new_bottom_left = Point{
            .x = self.bottom_left.x - 1,
            .y = self.bottom_left.y - 1,
        };
        const new_top_right = Point{
            .x = self.top_right.x + 1,
            .y = self.top_right.y + 1,
        };

        self.buffer.clearRetainingCapacity();

        var x: i64 = new_bottom_left.x;
        while (x <= new_top_right.x) : (x += 1) {
            var y: i64 = new_bottom_left.y;
            while (y <= new_top_right.y) : (y += 1) {
                if (self.getNewValue(x, y, algo)) {
                    try self.buffer.put(.{ .x = x, .y = y }, {});
                }
            }
        }

        self.outer_on = self.getNewValue(new_top_right.x + 1, new_top_right.y + 1, algo);
        self.bottom_left = new_bottom_left;
        self.top_right = new_top_right;

        std.mem.swap(HashMap(Point, void), &self.pixels, &self.buffer);
    }

    pub fn deinit(self: *Self) void {
        self.pixels.deinit();
        self.buffer.deinit();
    }

    pub fn print(self: Self) void {
        const stdout = std.io.getStdOut().writer();
        var x: i64 = self.bottom_left.x;
        while (x <= self.top_right.x) : (x += 1) {
            var y: i64 = self.bottom_left.y;
            while (y <= self.top_right.y) : (y += 1) {
                if (self.get(x, y)) {
                    stdout.print("#", .{}) catch unreachable;
                } else {
                    stdout.print(".", .{}) catch unreachable;
                }
            }
            stdout.print("\n", .{}) catch unreachable;
        }
        stdout.print("\n", .{}) catch unreachable;
    }

    fn getNewValue(self: *const Self, x: i64, y: i64, algo: *const [512]bool) bool {
        var idx: usize = 0;
        var dx: i64 = -1;
        while (dx <= 1) : (dx += 1) {
            var dy: i64 = -1;
            while (dy <= 1) : (dy += 1) {
                idx = idx << 1;
                if (self.get(x + dx, y + dy)) {
                    idx += 1;
                }
            }
        }

        return algo[idx];
    }

    fn get(self: *const Self, x: i64, y: i64) bool {
        if (self.bottom_left.x > x or self.top_right.x < x) return self.outer_on;
        if (self.bottom_left.y > y or self.top_right.y < y) return self.outer_on;

        return self.pixels.contains(.{ .x = x, .y = y });
    }
};

const Point = struct { x: i64, y: i64 };

const eql = std.mem.eql;
const tokenize = std.mem.tokenize;
const split = std.mem.split;
const count = std.mem.count;
const parseUnsigned = std.fmt.parseUnsigned;
const parseInt = std.fmt.parseInt;
const sort = std.sort.sort;
