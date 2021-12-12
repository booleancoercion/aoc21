const std = @import("std");
const helper = @import("helper.zig");
const Allocator = std.mem.Allocator;
const StringHashMap = std.StringHashMap;
const HashMap = std.AutoHashMap;

const input = @embedFile("../inputs/day12.txt");

pub fn run(alloc: Allocator, stdout_: anytype) !void {
    const graph = try CaveGraph.init(alloc, input);

    const res1 = try graph.countPathsNoRevisitSmall();
    const res2 = res1 + try graph.countPathsWithRevisitSmall();

    if (stdout_) |stdout| {
        try stdout.print("Part 1: {}\n", .{res1});
        try stdout.print("Part 2: {}\n", .{res2});
    }
}

const CaveGraph = struct {
    adjmat: []const bool,
    nodes: StringHashMap(usize),
    big: []const bool,
    node_num: usize,
    start: usize,
    end: usize,
    allocator: Allocator,

    const Self = @This();

    pub fn init(alloc: Allocator, str: []const u8) !Self {
        var nodes = StringHashMap(usize).init(alloc);
        try Self.populateNodesMap(str, &nodes);

        const node_num = @intCast(usize, nodes.count());
        var adjmat = try alloc.alloc(bool, node_num * node_num);
        std.mem.set(bool, adjmat, false);

        var big = try alloc.alloc(bool, node_num);

        Self.populateAdj(str, adjmat, nodes, node_num);
        Self.populateBig(big, nodes);

        return Self{
            .adjmat = adjmat,
            .nodes = nodes,
            .big = big,
            .node_num = node_num,
            .allocator = alloc,
            .start = nodes.get("start").?,
            .end = nodes.get("end").?,
        };
    }

    pub fn countPathsNoRevisitSmall(self: *const Self) !i32 {
        var visited_map = HashMap(usize, void).init(self.allocator);
        defer visited_map.deinit();
        return self.countPathsInner(self.start, &visited_map, null, true);
    }

    pub fn countPathsWithRevisitSmall(self: *const Self) !i32 {
        var visited_map = HashMap(usize, void).init(self.allocator);
        defer visited_map.deinit();

        var sum: i32 = 0;
        var node: usize = 0;
        while (node < self.node_num) : (node += 1) {
            if (self.big[node]) continue;
            if (node == self.start or node == self.end) continue;
            sum += try self.countPathsInner(self.start, &visited_map, node, false);
        }

        return sum;
    }

    pub fn deinit(self: Self) void {
        self.allocator.free(self.adjmat);
        self.allocator.free(self.big);
        self.nodes.deinit();
    }

    fn countPathsInner(
        self: *const Self,
        node: usize,
        visited_map: *HashMap(usize, void),
        may_visit_twice: ?usize,
        visited_twice: bool,
    ) Allocator.Error!i32 {
        if (node == self.end) {
            if (!visited_twice) return 0;
            return 1;
        }
        if (!self.big[node]) try visited_map.put(node, {});
        defer if (!self.big[node]) {
            // this is formatted stupidly because of a compiler error,
            // see: <https://github.com/ziglang/zig/issues/6059>
            if (!visited_twice) {
                _ = visited_map.remove(node);
            } else if (node != may_visit_twice) {
                _ = visited_map.remove(node);
            }
        };

        var sum: i32 = 0;
        var other: usize = 0;
        while (other < self.node_num) : (other += 1) {
            if (!self.getAdj(node, other)) continue;

            var visited_twice_mod = visited_twice;
            if (visited_map.contains(other)) {
                // you guessed it, same compiler error
                if (other == may_visit_twice) {
                    if (!visited_twice) {
                        visited_twice_mod = true;
                    } else {
                        continue;
                    }
                } else {
                    continue;
                }
            }

            sum += try self.countPathsInner(other, visited_map, may_visit_twice, visited_twice_mod);
        }

        return sum;
    }

    fn getAdj(self: *const Self, i: usize, j: usize) bool {
        return self.adjmat[i * self.node_num + j];
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
