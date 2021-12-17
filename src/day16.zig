const std = @import("std");
const helper = @import("helper.zig");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const input = @embedFile("../inputs/day16.txt");

pub fn run(alloc: Allocator, stdout_: anytype) !void {
    const binary: []const u1 = try convertToBinary(alloc, input);
    defer alloc.free(binary);

    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    var packet_parser = PacketParser{ .binary = binary, .alloc = arena_alloc };
    const outer_packet = try packet_parser.get();

    const res1 = calculateVersionSum(outer_packet);

    if (stdout_) |stdout| {
        try stdout.print("Part 1: {}\n", .{res1});
    }
}

fn convertToBinary(alloc: Allocator, data: []const u8) ![]const u1 {
    var list = try ArrayList(u1).initCapacity(alloc, data.len * 4); // 4 bits per hex digit, *not* 8
    defer list.deinit();

    for (data) |hexdigit| {
        if (!std.ascii.isXDigit(hexdigit)) continue;
        const num = try parseUnsigned(u4, &.{hexdigit}, 16);
        inline for (.{ 3, 2, 1, 0 }) |i| {
            try list.append(getBit(num, i));
        }
    }

    return list.toOwnedSlice();
}

fn getBit(num: u4, i: u2) u1 {
    const one: u4 = 1;
    return @boolToInt(num & (one << i) != 0);
}

fn calculateVersionSum(packet: Packet) i64 {
    switch (packet.kind) {
        .literal => return packet.version,
        .operator => |data| {
            var sum: i64 = packet.version;
            for (data.subpackets) |subpacket| {
                sum += calculateVersionSum(subpacket);
            }

            return sum;
        },
    }
}

const Packet = struct {
    version: u3,
    id: u3,
    bin_len: usize,
    kind: union(enum) {
        literal: []const u1,
        operator: struct {
            length_type: u1,
            subpackets: []Packet,
        },
    },
};

const PacketParser = struct {
    binary: []const u1,
    alloc: Allocator,
    idx: usize = 0,

    const Self = @This();

    pub fn get(self: *Self) Allocator.Error!Packet {
        const start = self.idx;
        const version = self.getN(3);
        const id = self.getN(3);

        if (id == 4) {
            return self.getLiteral(start, version, id);
        } else {
            return self.getOperator(start, version, id);
        }
    }

    fn getLiteral(self: *Self, start: usize, version: u3, id: u3) Packet {
        const literal_start = self.idx;
        while (self.binary[self.idx] == 1) : (self.idx += 5) {}
        self.idx += 5; // also consume the last section that starts with a 0

        const literal = self.binary[literal_start..self.idx];

        return Packet{
            .version = version,
            .id = id,
            .bin_len = (self.idx - start),
            .kind = .{
                .literal = literal,
            },
        };
    }

    fn getOperator(self: *Self, start: usize, version: u3, id: u3) Allocator.Error!Packet {
        const length_type: u1 = self.binary[self.idx];
        self.idx += 1;

        const subpackets = if (length_type == 0) // total length in bits is provided
            try self.getSubpacketsWithBitLength()
        else // number of sub-packets immediately contained is provided
            try self.getSubpacketsWithNumber();

        return Packet{
            .version = version,
            .id = id,
            .bin_len = (self.idx - start),
            .kind = .{ .operator = .{
                .length_type = length_type,
                .subpackets = subpackets,
            } },
        };
    }

    fn getSubpacketsWithBitLength(self: *Self) Allocator.Error![]Packet {
        var packets = ArrayList(Packet).init(self.alloc);
        defer packets.deinit();

        const limit_bit_length = @intCast(usize, self.getN(15));
        var total_bit_length: usize = 0;
        while (total_bit_length < limit_bit_length) {
            const packet = try self.get();
            try packets.append(packet);
            total_bit_length += packet.bin_len;
        }

        return packets.toOwnedSlice();
    }

    fn getSubpacketsWithNumber(self: *Self) Allocator.Error![]Packet {
        var packets = ArrayList(Packet).init(self.alloc);
        defer packets.deinit();

        const limit_num: u11 = self.getN(11);
        var total_num: u11 = 0;
        while (total_num < limit_num) : (total_num += 1) {
            const packet = try self.get();
            try packets.append(packet);
        }

        return packets.toOwnedSlice();
    }

    fn getN(self: *Self, comptime n: u16) std.meta.Int(.unsigned, n) {
        if (self.idx + n >= self.binary.len) unreachable;
        const idx = self.idx;
        const binary = self.binary;

        defer self.idx += n;
        var sum: std.meta.Int(.unsigned, n) = 0;

        comptime var i = 0;
        inline while (i < n) : (i += 1) {
            sum = sum << 1;
            sum += binary[idx + i];
        }

        return sum;
    }
};

const eql = std.mem.eql;
const tokenize = std.mem.tokenize;
const split = std.mem.split;
const count = std.mem.count;
const parseUnsigned = std.fmt.parseUnsigned;
const parseInt = std.fmt.parseInt;
const sort = std.sort.sort;
