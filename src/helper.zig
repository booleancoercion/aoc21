const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn Grid(comptime T: type) type {
    return struct {
        x: usize,
        y: usize,
        data: []T,
        allocator: Allocator,

        const Self = @This();

        pub fn init(alloc: Allocator, x: usize, y: usize) !Self {
            var data = try alloc.alloc(T, x * y);

            return Self{
                .x = x,
                .y = y,
                .data = data,
                .allocator = alloc,
            };
        }

        pub fn deinit(self: Self) void {
            self.allocator.free(self.data);
        }

        pub fn get(self: Self, i: usize, j: usize) T {
            return self.data[Self.getIdx(self.y, i, j)];
        }

        pub fn set(self: Self, i: usize, j: usize, elem: T) void {
            self.data[Self.getIdx(self.y, i, j)] = elem;
        }

        fn getIdx(y: usize, i: usize, j: usize) usize {
            return i * y + j;
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
