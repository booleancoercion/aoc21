const std = @import("std");
const helper = @import("helper.zig");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const HashMap = std.AutoHashMap;

const input = @embedFile("../inputs/day22.txt");

pub fn run(alloc: Allocator, stdout_: anytype) !void {
    var entries = ArrayList(Cuboid).init(alloc);
    defer entries.deinit();

    var lines = helper.getlines(input);
    while (lines.next()) |line| {
        const entry = try Cuboid.parse(line);
        try entries.append(entry);
    }

    var reactor = Reactor.init(alloc);
    defer reactor.deinit();
    var i: usize = 0;
    while (true) : (i += 1) {
        const val = entries.items[i].x.low;
        if (val < -50 or val > 50) break;

        try reactor.addCuboid(entries.items[i]);
    }

    const res1 = reactor.volumeSum();

    while (i < entries.items.len) : (i += 1) {
        try reactor.addCuboid(entries.items[i]);
    }

    const res2 = reactor.volumeSum();

    if (stdout_) |stdout| {
        try stdout.print("Part 1: {}\n", .{res1});
        try stdout.print("Part 2: {}\n", .{res2});
    }
}

const Reactor = struct {
    cuboids: ArrayList(Cuboid),
    buffer: ArrayList(Cuboid),

    const Self = @This();

    pub fn init(alloc: Allocator) Self {
        return .{
            .cuboids = ArrayList(Cuboid).init(alloc),
            .buffer = ArrayList(Cuboid).init(alloc),
        };
    }

    pub fn addCuboid(self: *Self, cuboid: Cuboid) !void {
        self.buffer.clearRetainingCapacity();
        for (self.cuboids.items) |victim| {
            try self.splitAndAddPieces(victim, cuboid);
        }

        if (cuboid.on) {
            try self.buffer.append(cuboid);
        }

        std.mem.swap(ArrayList(Cuboid), &self.cuboids, &self.buffer);
    }

    fn minimizeFrom(self: *Self, i_: usize) void {
        var i: usize = i_;
        while (i < self.buffer.items.len) {
            const ci = self.buffer.items[i];
            var melded: bool = false;
            var j: usize = i + 1;
            while (j < self.buffer.items.len) : (j += 1) {
                const cj = &self.buffer.items[j];
                const eqx = ci.x.eq(cj.x);
                const eqy = ci.y.eq(cj.y);
                const eqz = ci.z.eq(cj.z);
                if (eqx and eqy) {
                    if (ci.z.low == cj.z.high + 1) {
                        cj.z.high = ci.z.high;
                        melded = true;
                    } else if (ci.z.high == cj.z.low - 1) {
                        cj.z.low = ci.z.low;
                        melded = true;
                    }
                } else if (eqy and eqz) {
                    if (ci.x.low == cj.x.high + 1) {
                        cj.x.high = ci.x.high;
                        melded = true;
                    } else if (ci.x.high == cj.x.low - 1) {
                        cj.x.low = ci.x.low;
                        melded = true;
                    }
                } else if (eqz and eqx) {
                    if (ci.y.low == cj.y.high + 1) {
                        cj.y.high = ci.y.high;
                        melded = true;
                    } else if (ci.y.high == cj.y.low - 1) {
                        cj.y.low = ci.y.low;
                        melded = true;
                    }
                }

                if (melded) break;
            }

            if (melded) {
                _ = self.buffer.swapRemove(i);
            } else {
                i += 1;
            }
        }
    }

    fn splitAndAddPieces(self: *Self, victim: Cuboid, splitter: Cuboid) !void {
        const splitter_ranges: [3]Range(i32) = .{ splitter.x, splitter.y, splitter.z };
        const victim_ranges: [3]Range(i32) = .{ victim.x, victim.y, victim.z };
        var victim_split_ranges: [3][3]?Range(i32) = undefined;

        for (splitter_ranges) |srange, i| {
            const vrange = victim_ranges[i];
            victim_split_ranges[i] = splitRange(vrange, srange);
        }

        const idx = self.buffer.items.len;

        for (victim_split_ranges[0]) |xrangen, xi| if (xrangen) |xrange| {
            for (victim_split_ranges[1]) |yrangen, yi| if (yrangen) |yrange| {
                for (victim_split_ranges[2]) |zrangen, zi| if (zrangen) |zrange| {
                    if (xi == 1 and yi == 1 and zi == 1) continue; // exactly the intersection of the cuboids

                    try self.buffer.append(Cuboid{
                        .x = xrange,
                        .y = yrange,
                        .z = zrange,
                        .on = true,
                    });
                };
            };
        };

        if (idx < self.buffer.items.len) {
            self.minimizeFrom(idx);
        }
    }

    fn splitRange(vrange: Range(i32), srange: Range(i32)) [3]?Range(i32) {
        return .{
            Range(i32).init(vrange.low, std.math.min(vrange.high, srange.low - 1)),
            vrange.intersection(srange),
            Range(i32).init(std.math.max(vrange.low, srange.high + 1), vrange.high),
        };
    }

    pub fn volumeSum(self: Self) i64 {
        var sum: i64 = 0;
        for (self.cuboids.items) |cuboid| {
            sum += cuboid.volume();
        }

        return sum;
    }

    pub fn deinit(self: Self) void {
        self.cuboids.deinit();
        self.buffer.deinit();
    }
};

const Point = struct { x: i32, y: i32, z: i32 };

fn Range(comptime T: type) type {
    return struct {
        low: T,
        high: T,

        const Self = @This();

        pub fn init(low: T, high: T) ?Self {
            if (low > high) return null;
            return Self{ .low = low, .high = high };
        }

        pub fn contains(self: Self, elem: T) bool {
            return self.low <= elem and elem <= self.high;
        }

        pub fn intersection(self: Self, other: Self) ?Self {
            const low = std.math.max(self.low, other.low);
            const high = std.math.min(self.high, other.high);

            return Self.init(low, high); // automatically handles non-intersecting ranges
        }

        pub fn length(self: Self) T {
            return self.high - self.low + 1;
        }

        pub fn eq(self: Self, other: Self) bool {
            return self.low == other.low and self.high == other.high;
        }
    };
}

const Cuboid = struct {
    x: Range(i32),
    y: Range(i32),
    z: Range(i32),
    on: bool,

    const Self = @This();

    pub fn parse(line: []const u8) !Self {
        const on = std.mem.startsWith(u8, line, "on");
        var tokens = tokenize(u8, line, "ofnxyz=., ");

        var ranges: [3]Range(i32) = undefined;
        for (ranges) |*range| {
            const low = try parseInt(i32, tokens.next().?, 10);
            const high = try parseInt(i32, tokens.next().?, 10);

            range.* = Range(i32).init(low, high) orelse return error.InvalidRange;
        }

        return Self{
            .x = ranges[0],
            .y = ranges[1],
            .z = ranges[2],
            .on = on,
        };
    }

    pub fn volume(self: Self) i64 {
        var acc: i64 = 1;
        acc *= self.x.length();
        acc *= self.y.length();
        acc *= self.z.length();

        return acc;
    }
};

const eql = std.mem.eql;
const tokenize = std.mem.tokenize;
const split = std.mem.split;
const count = std.mem.count;
const parseUnsigned = std.fmt.parseUnsigned;
const parseInt = std.fmt.parseInt;
const sort = std.sort.sort;
