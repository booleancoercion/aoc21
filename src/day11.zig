const std = @import("std");
const helper = @import("helper.zig");
const Allocator = std.mem.Allocator;

const input = @embedFile("../inputs/day11.txt");

const grid_size = 10;

pub fn run(alloc: Allocator, stdout: anytype) !void {
    _ = alloc;

    var grid = OctoGrid.init(input);
    var grid2 = grid;

    const res1 = grid.simulateMany(100);
    const res2 = grid2.getSyncStep();

    try stdout.print("Part 1: {}\n", .{res1});
    try stdout.print("Part 2: {}\n", .{res2});
}

const OctoGrid = struct {
    grid: [grid_size][grid_size]u8,

    const Self = @This();

    pub fn init(str: []const u8) Self {
        var grid: [grid_size][grid_size]u8 = undefined;
        var lines = tokenize(u8, str, "\r\n");

        for (grid) |*row| {
            const line = lines.next().?;
            for (row) |*num, i| {
                num.* = line[i] - '0';
            }
        }

        if (lines.next() != null) unreachable;

        return Self{ .grid = grid };
    }

    pub fn simulateOne(self: *Self) i32 {
        self.addOneAll();

        var flashed = true;
        var flashes: i32 = 0;
        while (flashed) {
            const temp = self.flashOnce();
            flashes += temp;
            flashed = temp > 0;
        }

        return flashes;
    }

    pub fn simulateMany(self: *Self, amt: i32) i32 {
        var i: i32 = 0;
        var sum: i32 = 0;
        while (i < amt) : (i += 1) {
            sum += self.simulateOne();
        }

        return sum;
    }

    pub fn getSyncStep(self: *Self) i32 {
        var i: i32 = 1;
        while (self.simulateOne() != grid_size * grid_size) {
            i += 1;
        }
        return i;
    }

    fn addOneAll(self: *Self) void {
        for (self.grid) |*row| {
            for (row) |*num| {
                num.* += 1;
            }
        }
    }

    fn flashOnce(self: *Self) i32 {
        var flashes: i32 = 0;
        for (self.grid) |*row, i| {
            for (row) |num, j| {
                if (num > 9) {
                    flashes += 1;
                    self.flashAt(i, j);
                }
            }
        }

        return flashes;
    }

    fn flashAt(self: *Self, iu: usize, ju: usize) void {
        self.grid[iu][ju] = 0;
        const i = @intCast(i32, iu);
        const j = @intCast(i32, ju);

        const delta: [3]i32 = .{ -1, 0, 1 };
        for (delta) |di| {
            for (delta) |dj| {
                if (di == 0 and dj == 0) continue;
                if (i + di < 0 or i + di >= grid_size) continue;
                if (j + dj < 0 or j + dj >= grid_size) continue;

                const newi = @intCast(usize, i + di);
                const newj = @intCast(usize, j + dj);

                if (self.grid[newi][newj] == 0) continue;
                self.grid[newi][newj] += 1;
            }
        }
    }

    fn print(self: *const Self) void {
        const stdout = std.io.getStdOut().writer();

        for (self.grid) |*row| {
            for (row) |num| {
                stdout.print("{}", .{num}) catch unreachable;
            }
            stdout.print("\n", .{}) catch unreachable;
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
