const std = @import("std");
const helper = @import("helper.zig");
const Allocator = std.mem.Allocator;

const input = @embedFile("../inputs/dayX.txt");

pub fn run(alloc: *Allocator, stdout: anytype) !void {}

const tokenize = std.mem.tokenize;
const count = std.mem.count;
const parseUnsigned = std.fmt.parseUnsigned;
const parseInt = std.fmt.parseInt;
const sort = std.sort.sort;
