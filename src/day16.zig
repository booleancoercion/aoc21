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
    _ = alloc;
    _ = data;
    unreachable;
}

fn calculateVersionSum(packet: Packet) i64 {
    switch (packet.kind) {
        .literal => return packet.version,
        .operator => |data| {
            var sum: i64 = packet.version;
            for (data.subpackets.items) |subpacket| {
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
            subpackets: ArrayList(Packet),
        },
    },
};

const PacketParser = struct {
    binary: []const u1,
    alloc: Allocator,
    idx: usize = 0,

    const Self = @This();

    pub fn get(self: *Self) Allocator.Error!Packet {
        _ = self;
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
