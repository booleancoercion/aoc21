const std = @import("std");
const helper = @import("helper.zig");
const Allocator = std.mem.Allocator;
const Grid = helper.Grid;

const input = @embedFile("../inputs/day13.txt");

pub fn run(alloc: Allocator, stdout: anytype) !void {
    var parsed = try Input.init(alloc, input);
    _ = parsed;
    _ = alloc;
    _ = stdout;
}

const Rule = union(enum) {
    fold_x: usize,
    fold_y: usize,
};

const Input = struct {
    grid: Grid(bool),
    rules: []Rule,
    allocator: Allocator,

    const Self = @This();

    pub fn init(alloc: Allocator, str: []const u8) !Self {
        _ = alloc;
        _ = str;
        unreachable;
    }
};

const eql = std.mem.eql;
const tokenize = std.mem.tokenize;
const split = std.mem.split;
const count = std.mem.count;
const parseUnsigned = std.fmt.parseUnsigned;
const parseInt = std.fmt.parseInt;
const sort = std.sort.sort;
