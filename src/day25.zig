const std = @import("std");
const helper = @import("helper.zig");
const Allocator = std.mem.Allocator;
const Grid = helper.Grid;

const input = @embedFile("../inputs/day25.txt");

pub fn run(alloc: Allocator, stdout_: anytype) !void {
    var grid = try parseInitial(alloc, input);
    var buffer = try Grid(Tile).init(alloc, grid.m, grid.n);
    defer grid.deinit();
    defer buffer.deinit();

    const res1 = advanceUntilStopped(&grid, &buffer);

    if (stdout_) |stdout| {
        try stdout.print("Part 1: {}\n", .{res1});
    }
}

const Tile = enum { empty, south, east };

fn print(grid: Grid(Tile)) void {
    for (grid.data) |tile, i| {
        if (i > 0 and i % grid.n == 0) std.debug.print("\n", .{});
        const ch: u8 = switch (tile) {
            .empty => '.',
            .east => '>',
            .south => 'v',
        };

        std.debug.print("{c}", .{ch});
    }
    std.debug.print("\n\n", .{});
}

fn parseInitial(alloc: Allocator, inp: []const u8) !Grid(Tile) {
    const m = count(u8, inp, "\n");

    var lines = helper.getlines(inp);
    const n = lines.next().?.len;

    var grid = try Grid(Tile).init(alloc, m, n);

    var i: usize = 0;
    for (inp) |ch| {
        const tile: Tile = switch (ch) {
            '.' => .empty,
            '>' => .east,
            'v' => .south,
            else => continue,
        };
        grid.data[i] = tile;
        i += 1;
    }

    return grid;
}

fn advanceUntilStopped(grid: *Grid(Tile), buffer: *Grid(Tile)) i32 {
    var i: i32 = 1;
    while (advance(grid, buffer)) i += 1;
    return i;
}

fn advance(grid: *Grid(Tile), buffer: *Grid(Tile)) bool {
    const east = advanceEast(grid, buffer);
    const south = advanceSouth(grid, buffer);
    return east or south; // to stop short-circuiting
}

fn advanceEast(grid: *Grid(Tile), buffer: *Grid(Tile)) bool {
    std.mem.set(Tile, buffer.data, .empty);
    var modified: bool = false;

    var i: usize = 0;
    while (i < grid.m) : (i += 1) {
        var j: usize = 0;
        while (j < grid.n) : (j += 1) {
            switch (grid.get(i, j)) {
                .east => {
                    if (grid.get(i, (j + 1) % grid.n) == .empty) {
                        buffer.set(i, (j + 1) % grid.n, .east);
                        modified = true;
                    } else {
                        buffer.set(i, j, .east);
                    }
                },
                .south => buffer.set(i, j, .south),
                .empty => {},
            }
        }
    }

    std.mem.swap(Grid(Tile), grid, buffer);
    return modified;
}

fn advanceSouth(grid: *Grid(Tile), buffer: *Grid(Tile)) bool {
    std.mem.set(Tile, buffer.data, .empty);
    var modified: bool = false;

    var i: usize = 0;
    while (i < grid.m) : (i += 1) {
        var j: usize = 0;
        while (j < grid.n) : (j += 1) {
            switch (grid.get(i, j)) {
                .south => {
                    if (grid.get((i + 1) % grid.m, j) == .empty) {
                        buffer.set((i + 1) % grid.m, j, .south);
                        modified = true;
                    } else {
                        buffer.set(i, j, .south);
                    }
                },
                .east => buffer.set(i, j, .east),
                .empty => {},
            }
        }
    }

    std.mem.swap(Grid(Tile), grid, buffer);
    return modified;
}

const eql = std.mem.eql;
const tokenize = std.mem.tokenize;
const split = std.mem.split;
const count = std.mem.count;
const parseUnsigned = std.fmt.parseUnsigned;
const parseInt = std.fmt.parseInt;
const sort = std.sort.sort;
