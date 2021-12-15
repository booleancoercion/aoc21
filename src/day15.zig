const std = @import("std");
const helper = @import("helper.zig");
const Allocator = std.mem.Allocator;
const Grid = helper.Grid;
const BinaryHeap = helper.BinaryHeap;

const input = @embedFile("../inputs/day15.txt");

pub fn run(alloc: Allocator, stdout_: anytype) !void {
    const grid = try parseInput(alloc, input);
    defer grid.deinit();

    var dijkstra = try DijkstraGrid.init(alloc, grid);
    defer dijkstra.deinit();

    dijkstra.calculate();
    const res1 = dijkstra.nodes[0].priority - grid.data[0];

    const grid5 = try genGrid5(alloc, grid);
    defer grid5.deinit();

    var dijkstra5 = try DijkstraGrid.init(alloc, grid5);
    defer dijkstra5.deinit();

    dijkstra5.calculate();
    const res2 = dijkstra5.nodes[0].priority - grid5.data[0];

    if (stdout_) |stdout| {
        try stdout.print("Part 1: {}\n", .{res1});
        try stdout.print("Part 2: {}\n", .{res2});
    }
}

fn genGrid5(alloc: Allocator, grid: Grid(u8)) !Grid(u8) {
    var grid5 = try Grid(u8).init(alloc, grid.m * 5, grid.n * 5);

    var i: usize = 0;
    while (i < grid5.m) : (i += 1) {
        var j: usize = 0;
        while (j < grid5.n) : (j += 1) {
            const increases = @intCast(u8, (i / grid.m) + (j / grid.n));
            const ii = i % grid.m;
            const jj = j % grid.n;
            const val = (grid.get(ii, jj) + increases - 1) % 9 + 1;
            grid5.set(i, j, val);
        }
    }

    return grid5;
}

const DijkstraGrid = struct {
    grid: Grid(u8),
    nodes: []Node,
    heap: BinaryHeap(Point),
    allocator: Allocator,

    const Self = @This();

    pub fn init(alloc: Allocator, grid: Grid(u8)) !Self {
        var nodes = try alloc.alloc(Node, grid.data.len);
        var i: usize = 0;
        while (i < grid.m) : (i += 1) {
            var j: usize = 0;
            while (j < grid.n) : (j += 1) {
                const node = &nodes[grid.getIdx(i, j)];
                node.priority = std.math.maxInt(i32);
                node.data = Point{ .x = i, .y = j };
            }
        }

        nodes[nodes.len - 1].priority = grid.data[grid.data.len - 1];

        var heap = try BinaryHeap(Point).init(alloc, nodes);

        return Self{ .grid = grid, .nodes = nodes, .heap = heap, .allocator = alloc };
    }

    pub fn calculate(self: *Self) void {
        while (self.heap.len > 0) {
            const min = self.heap.pop();
            var neighbors = self.neighbors_iter(min.data);
            while (neighbors.next()) |neighbor| {
                const node = &self.nodes[self.grid.getIdx(neighbor.x, neighbor.y)];
                if (node.idx == null) continue;

                const alt: i32 = min.priority + self.grid.get(neighbor.x, neighbor.y);

                if (alt < node.priority) {
                    self.heap.changePriority(node.idx.?, alt);
                }
            }
        }
    }

    pub fn deinit(self: Self) void {
        self.allocator.free(self.nodes);
        self.heap.deinit();
    }

    fn neighbors_iter(self: *const Self, pt: Point) NeighborIterator {
        return NeighborIterator{
            .dg = self,
            .point = NeighborIterator.SignedPoint{
                .x = @intCast(isize, pt.x),
                .y = @intCast(isize, pt.y),
            },
        };
    }

    const NeighborIterator = struct {
        dg: *const DijkstraGrid,
        point: SignedPoint,
        index: usize = 0,

        const offsets: [4]SignedPoint = .{
            .{ .x = -1, .y = 0 },
            .{ .x = 0, .y = -1 },
            .{ .x = 1, .y = 0 },
            .{ .x = 0, .y = 1 },
        };

        pub fn next(self: *@This()) ?Point {
            const pt = self.point;
            const grid = self.dg.grid;
            while (self.index < 4) {
                const of = offsets[self.index];
                self.index += 1;

                const newpoint = SignedPoint{ .x = of.x + pt.x, .y = of.y + pt.y };
                if (newpoint.x < 0 or newpoint.x >= grid.m) continue;
                if (newpoint.y < 0 or newpoint.y >= grid.n) continue;

                return Point{
                    .x = @intCast(usize, newpoint.x),
                    .y = @intCast(usize, newpoint.y),
                };
            }

            return null;
        }

        const SignedPoint = struct { x: isize, y: isize };
    };

    const Point = struct { x: usize, y: usize };
    const Node = BinaryHeap(Point).Node;
};

fn parseInput(alloc: Allocator, inp: []const u8) !Grid(u8) {
    var lines = getlines(inp);
    const m = count(u8, inp, "\n");
    const n = lines.next().?.len;

    if (m != n) unreachable; // the input should be a square

    var grid = try Grid(u8).init(alloc, m, n);
    const items = grid.data;

    var i: usize = 0;
    for (inp) |ch| {
        if (!std.ascii.isDigit(ch)) continue;
        items[i] = ch - '0';
        i += 1;
    }
    if (i != items.len) unreachable;

    return grid;
}

const eql = std.mem.eql;
const tokenize = std.mem.tokenize;
const split = std.mem.split;
const count = std.mem.count;
const parseUnsigned = std.fmt.parseUnsigned;
const parseInt = std.fmt.parseInt;
const sort = std.sort.sort;
const getlines = helper.getlines;
