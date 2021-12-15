const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn Grid(comptime T: type) type {
    return struct {
        m: usize,
        n: usize,
        data: []T,
        allocator: Allocator,

        const Self = @This();

        pub fn init(alloc: Allocator, m: usize, n: usize) !Self {
            var data = try alloc.alloc(T, m * n);

            return Self{
                .m = m,
                .n = n,
                .data = data,
                .allocator = alloc,
            };
        }

        pub fn deinit(self: Self) void {
            self.allocator.free(self.data);
        }

        pub fn get(self: Self, i: usize, j: usize) T {
            return self.data[self.getIdx(i, j)];
        }

        pub fn set(self: Self, i: usize, j: usize, elem: T) void {
            self.data[self.getIdx(i, j)] = elem;
        }

        pub fn getIdx(self: Self, i: usize, j: usize) usize {
            return i * self.n + j;
        }
    };
}

pub fn BinaryHeap(comptime T: type) type {
    return struct {
        heap: []*Node,
        len: usize,
        allocator: Allocator,

        const Self = @This();

        pub fn init(alloc: Allocator, nodes: []Node) !Self {
            var heap = try alloc.alloc(*Node, nodes.len);
            var instance = Self{ .heap = heap, .len = nodes.len, .allocator = alloc };

            for (nodes) |*node, i| {
                heap[i] = node;
                node.idx = i;
            }

            instance.heapify();
            return instance;
        }

        pub fn changePriority(self: Self, idx: usize, new_priority: i32) void {
            const heap = self.heap;
            heap[idx].priority = new_priority;
            const prt = parent(idx);
            if (heap[idx].priority < heap[prt].priority) {
                self.bubbleUp(idx);
            } else {
                self.bubbleDown(idx);
            }
        }

        pub fn pop(self: *Self) *const Node {
            if (self.len == 0) unreachable;

            var node = self.heap[0];
            self.swap(0, self.len - 1);
            node.idx = null;
            self.len -= 1;
            self.bubbleDown(0);

            return node;
        }

        pub fn deinit(self: Self) void {
            self.allocator.free(self.heap);
        }

        pub const Node = struct {
            data: T,
            priority: i32,
            idx: ?usize = null,
        };

        fn heapify(self: *Self) void {
            const len = self.len;

            var i: usize = 0;
            while (i < len) : (i += 1) {
                const idx = len - i - 1;

                self.bubbleDown(idx);
            }
        }

        fn bubbleUp(self: Self, idx_: usize) void {
            var idx = idx_;
            const heap = self.heap;

            while (idx != 0) {
                const prt = parent(idx);

                if (heap[prt].priority > heap[idx].priority) {
                    self.swap(idx, prt);
                    idx = prt;
                } else break;
            }
        }

        fn bubbleDown(self: Self, idx_: usize) void {
            var idx = idx_;
            const heap = self.heap;
            const len = self.len;
            while (idx < len) {
                const lft = left(idx);
                const rgt = right(idx);

                if (lft >= len) break;
                const p = heap[idx].priority;
                const pl = heap[lft].priority;
                if (rgt >= len) {
                    if (pl <= p) {
                        self.swap(lft, idx);
                        idx = lft;
                    } else break;
                } else {
                    const pr = heap[rgt].priority;

                    if (pl <= pr and pl <= p) {
                        self.swap(lft, idx);
                        idx = lft;
                    } else if (pr <= pl and pr <= p) {
                        self.swap(rgt, idx);
                        idx = rgt;
                    } else break;
                }
            }
        }

        fn swap(self: Self, i: usize, j: usize) void {
            const nodei = self.heap[i];
            const nodej = self.heap[j];

            nodei.idx = j;
            nodej.idx = i;

            self.heap[i] = nodej;
            self.heap[j] = nodei;
        }

        fn left(idx: usize) usize {
            return 2 * idx + 1;
        }

        fn right(idx: usize) usize {
            return 2 * idx + 2;
        }

        fn parent(idx: usize) usize {
            return (idx - 1) / 2;
        }
    };
}

pub fn sum(comptime T: type, slice: []const T) T {
    var s: T = 0;
    for (slice) |elem| {
        s = s + elem;
    }

    return s;
}

pub fn getlines(buffer: []const u8) std.mem.TokenIterator(u8) {
    return std.mem.tokenize(u8, buffer, "\r\n");
}

test "BinaryHeap: add and remove min heap" {
    const expectEqual = std.testing.expectEqual;

    const alloc = std.testing.allocator;
    var nodes = try alloc.alloc(BinaryHeap(i32).Node, 8);
    defer alloc.free(nodes);
    const items: [8]i32 = .{ 54, 12, 7, 23, 25, 13, 0, 0 };
    for (items) |item, i| {
        nodes[i] = BinaryHeap(i32).Node{ .data = item, .priority = item };
    }
    var queue = try BinaryHeap(i32).init(std.testing.allocator, nodes);
    defer queue.deinit();

    try expectEqual(@as(i32, 0), queue.pop().data);
    try expectEqual(@as(i32, 0), queue.pop().data);
    try expectEqual(@as(i32, 7), queue.pop().data);
    try expectEqual(@as(i32, 12), queue.pop().data);
    try expectEqual(@as(i32, 13), queue.pop().data);
    try expectEqual(@as(i32, 23), queue.pop().data);
    try expectEqual(@as(i32, 25), queue.pop().data);
    try expectEqual(@as(i32, 54), queue.pop().data);
}
