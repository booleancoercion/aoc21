const std = @import("std");
const helper = @import("helper.zig");
const Allocator = std.mem.Allocator;
const StringHashMap = std.StringHashMap;
const HashMap = std.AutoHashMap;

const input = @embedFile("../inputs/day12.txt");

pub fn run(alloc: Allocator, stdout_: anytype) !void {
    const graph = try CaveGraph.init(alloc, input);
    defer graph.deinit();

    var visited = try alloc.alloc(u8, graph.node_num);
    defer alloc.free(visited);

    const res1 = try graph.countPathsNoRevisitSmall(visited);
    const res2 = res1 + try graph.countPathsWithRevisitSmall(visited);

    if (stdout_) |stdout| {
        try stdout.print("Part 1: {}\n", .{res1});
        try stdout.print("Part 2: {}\n", .{res2});
    }
}

const CaveGraph = struct {
    neighbors: []const []const usize,
    neighbor_buffer: []const usize,
    big: []const bool,
    node_num: usize,
    start: usize,
    end: usize,
    allocator: Allocator,

    const Self = @This();

    pub fn init(alloc: Allocator, str: []const u8) !Self {
        var nodes = StringHashMap(usize).init(alloc);
        defer nodes.deinit();
        try Self.populateNodesMap(str, &nodes);
        const node_num = @intCast(usize, nodes.count());

        var adjmat = try alloc.alloc(bool, node_num * node_num);
        defer alloc.free(adjmat);
        std.mem.set(bool, adjmat, false);
        Self.populateAdj(str, adjmat, nodes, node_num);

        var big = try alloc.alloc(bool, node_num);
        Self.populateBig(big, nodes);

        var neighbor_buffer: []usize = undefined;
        var neighbors: [][]usize = try alloc.alloc([]usize, node_num);
        try Self.populateNeighbors(alloc, adjmat, neighbors, &neighbor_buffer, node_num);

        return Self{
            .neighbors = neighbors,
            .neighbor_buffer = neighbor_buffer,
            .big = big,
            .node_num = node_num,
            .allocator = alloc,
            .start = nodes.get("start").?,
            .end = nodes.get("end").?,
        };
    }

    fn populateNeighbors(
        alloc: Allocator,
        adjmat: []const bool,
        neighbors: [][]usize,
        neighbor_buffer: *[]usize,
        node_num: usize,
    ) !void {
        var neighbor_num: usize = 0;
        for (adjmat) |val| {
            neighbor_num += @intCast(usize, @boolToInt(val));
        }

        neighbor_buffer.* = try alloc.alloc(usize, neighbor_num);
        var start: usize = 0;
        var end: usize = 0;
        var node: usize = 0;
        while (node < node_num) : (node += 1) {
            start = end;
            var other: usize = 0;
            while (other < node_num) : (other += 1) {
                if (adjmat[node * node_num + other]) {
                    neighbor_buffer.*[end] = other;
                    end += 1;
                }
            }

            neighbors[node] = neighbor_buffer.*[start..end];
        }
    }

    pub fn countPathsNoRevisitSmall(self: *const Self, visited: []u8) !i32 {
        std.mem.set(u8, visited, 0);
        return self.countPathsInner(self.start, visited, null);
    }

    pub fn countPathsWithRevisitSmall(self: *const Self, visited: []u8) !i32 {
        std.mem.set(u8, visited, 0);

        var sum: i32 = 0;
        var node: usize = 0;
        while (node < self.node_num) : (node += 1) {
            if (self.big[node]) continue;
            if (node == self.start or node == self.end) continue;
            sum += try self.countPathsInner(self.start, visited, node);
        }

        return sum;
    }

    pub fn deinit(self: Self) void {
        self.allocator.free(self.neighbors);
        self.allocator.free(self.neighbor_buffer);
        self.allocator.free(self.big);
    }

    fn countPathsInner(
        self: *const Self,
        node: usize,
        visited: []u8,
        may_visit_twice: ?usize,
    ) Allocator.Error!i32 {
        if (node == self.end) {
            if (may_visit_twice) |visitor| {
                if (visited[visitor] != 2) return 0;
            }
            return 1;
        }
        if (!self.big[node]) visited[node] += 1;
        defer if (!self.big[node]) {
            visited[node] -= 1;
        };

        var sum: i32 = 0;
        for (self.neighbors[node]) |other| {
            blk: {
                if (visited[other] != 0) {
                    if (other == may_visit_twice) {
                        if (visited[other] < 2) break :blk;
                    }
                    continue;
                }
            }

            sum += try self.countPathsInner(other, visited, may_visit_twice);
        }

        return sum;
    }

    fn populateNodesMap(str: []const u8, nodes: *StringHashMap(usize)) !void {
        var lines = tokenize(u8, str, "\r\n");
        var counter: usize = 0;
        while (lines.next()) |line| {
            var splut = split(u8, line, "-");
            while (splut.next()) |node_name| {
                if (!nodes.contains(node_name)) {
                    try nodes.put(node_name, counter);
                    counter += 1;
                }
            }
        }
    }

    fn populateAdj(str: []const u8, adjmat: []bool, nodes: StringHashMap(usize), node_num: usize) void {
        var lines = tokenize(u8, str, "\r\n");
        while (lines.next()) |line| {
            var splut = split(u8, line, "-");
            const fst = splut.next().?;
            const snd = splut.next().?;

            const i = nodes.get(fst).?;
            const j = nodes.get(snd).?;

            adjmat[i * node_num + j] = true;
            adjmat[j * node_num + i] = true;
        }
    }

    fn populateBig(big: []bool, nodes: StringHashMap(usize)) void {
        var iter = nodes.iterator();
        while (iter.next()) |entry| {
            const i = entry.value_ptr.*;
            big[i] = std.ascii.isUpper(entry.key_ptr.*[0]);
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
