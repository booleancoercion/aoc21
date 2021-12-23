const std = @import("std");
const helper = @import("helper.zig");
const Allocator = std.mem.Allocator;
const HashMap = std.AutoHashMap;

const input = @embedFile("../inputs/day23.txt");

pub fn run(alloc: Allocator, stdout_: anytype) !void {
    const start2: State(2) = State(2).parse(input);
    const res1 = try findDist(2, alloc, start2, final_state2);

    const rooms2 = start2.rooms;
    const start4: State(4) = .{
        .hallway = start2.hallway,
        .rooms = .{
            .{ rooms2[0][0], .desert, .desert, rooms2[0][1] },
            .{ rooms2[1][0], .copper, .bronze, rooms2[1][1] },
            .{ rooms2[2][0], .bronze, .amber, rooms2[2][1] },
            .{ rooms2[3][0], .amber, .copper, rooms2[3][1] },
        },
    };

    const res2 = try findDist(4, alloc, start4, final_state4);

    if (stdout_) |stdout| {
        try stdout.print("Part 1: {}\n", .{res1});
        try stdout.print("Part 2: {}\n", .{res2});
    }
}

const Amphipod = enum {
    amber,
    bronze,
    copper,
    desert,

    const Self = @This();

    pub fn roomnum(self: Self) u2 {
        return switch (self) {
            .amber => 0,
            .bronze => 1,
            .copper => 2,
            .desert => 3,
        };
    }

    pub fn multiplier(self: Self) i32 {
        return switch (self) {
            .amber => 1,
            .bronze => 10,
            .copper => 100,
            .desert => 1000,
        };
    }

    pub fn fromLetter(ch: u8) ?Self {
        return switch (ch) {
            'A' => .amber,
            'B' => .bronze,
            'C' => .copper,
            'D' => .desert,
            else => null,
        };
    }

    pub fn getLetter(self: Self) u8 {
        return switch (self) {
            .amber => 'A',
            .bronze => 'B',
            .copper => 'C',
            .desert => 'D',
        };
    }
};

fn aeq(a1: ?Amphipod, a2: ?Amphipod) bool {
    if (a1 == null and a2 != null) return false;
    if (a1 != null and a2 == null) return false;
    if (a1 == null and a2 == null) return true;
    return a1.? == a2.?;
}

fn State(comptime roomsize: comptime_int) type {
    return struct {
        hallway: [11]?Amphipod,
        rooms: [4][roomsize]?Amphipod, // room[0] is closer to the hallway

        const Self = @This();

        pub fn parse(inp: []const u8) Self {
            var tokens = tokenize(u8, inp, "# \r\n.");
            var rooms: [4][roomsize]?Amphipod = undefined;

            var i: usize = 0;
            var j: usize = 0;
            while (tokens.next()) |token| {
                rooms[i][j] = Amphipod.fromLetter(token[0]).?;
                i += 1;
                if (i >= rooms.len) {
                    i = 0;
                    j += 1;
                }
            }

            return Self{
                .hallway = .{null} ** 11,
                .rooms = rooms,
            };
        }

        pub fn neighbors(self: Self) NeighborIterator {
            return .{ .outer = self };
        }

        pub fn eq(self: Self, other: Self) bool {
            for (self.hallway) |amph, i| {
                if (!aeq(amph, other.hallway[i])) return false;
            }
            for (self.rooms) |room, i| {
                for (room) |amph, j| {
                    if (!aeq(amph, other.rooms[i][j])) return false;
                }
            }

            return true;
        }

        const NeighborIterator = struct {
            outer: Self,
            iter_state: IteratorState = .hallway,
            idx: usize = 0,

            const IteratorState = union(enum) { hallway, room: u2, done };
            const StateCost = struct { state: Self, cost: i32 };

            pub fn next(self: *@This()) ?StateCost {
                while (true) : (self.advanceState()) {
                    switch (self.iter_state) {
                        .done => return null,
                        .hallway => if (self.nextHallway()) |state| return state,
                        .room => |roomnum| if (self.nextRoom(roomnum)) |state| return state,
                    }
                }
            }

            fn nextHallway(self: *@This()) ?StateCost {
                const hallway = self.outer.hallway;
                if (self.idx >= hallway.len) return null;
                const amphi = hallway[self.idx] orelse return null;

                const roomnum = amphi.roomnum();
                const roomidx = idxOfRoom(roomnum);

                if (!self.routeEmpty(self.idx, roomidx)) return null;
                if (self.hasForeignAmphipods(roomnum)) return null;

                const vacant = self.getVacantIdx(roomnum) orelse return null;
                const routelen = routeLen(self.idx, roomidx);

                var new_state = self.outer;
                new_state.hallway[self.idx] = null;
                new_state.rooms[@intCast(usize, roomnum)][vacant] = amphi;

                self.advanceState();

                return StateCost{
                    .state = new_state,
                    .cost = (@intCast(i32, vacant) + 1 + routelen) * amphi.multiplier(),
                };
            }

            fn nextRoom(self: *@This(), roomnum: u2) ?StateCost {
                const hallway = self.outer.hallway;
                if (self.idx >= hallway.len or hallway[self.idx] != null) return null;
                if (self.isSolved(roomnum)) return null;

                const outermost = self.getOutermostIdx(roomnum) orelse return null;
                const roomusize = @intCast(usize, roomnum);
                const amphi = self.outer.rooms[roomusize][outermost].?;

                const roomidx = idxOfRoom(roomnum);
                if (!self.routeEmpty(roomidx, self.idx)) return null;
                const routelen = routeLen(roomidx, self.idx);

                var new_state = self.outer;
                new_state.hallway[self.idx] = amphi;
                new_state.rooms[roomusize][outermost] = null;

                self.advanceState();

                return StateCost{
                    .state = new_state,
                    .cost = (@intCast(i32, outermost) + 1 + routelen) * amphi.multiplier(),
                };
            }

            fn routeEmpty(self: @This(), start: usize, finish: usize) bool {
                const hallway = self.outer.hallway;
                if (hallway[finish] != null) return false;
                const min = std.math.min(start, finish);
                const max = std.math.max(start, finish);

                var i: usize = min + 1;
                while (i < max) : (i += 1) {
                    if (hallway[i] != null) return false;
                }

                return true;
            }

            fn hasForeignAmphipods(self: @This(), roomnum: u2) bool {
                const room = self.outer.rooms[@intCast(usize, roomnum)];
                for (room) |amphin| {
                    const amphi = amphin orelse continue;
                    if (amphi.roomnum() != roomnum) return true;
                }

                return false;
            }

            fn getVacantIdx(self: @This(), roomnum: u2) ?usize {
                const room = self.outer.rooms[@intCast(usize, roomnum)];
                var i: usize = 0;
                while (i < room.len) : (i += 1) {
                    if (room[room.len - i - 1] == null) return room.len - i - 1;
                }

                return null;
            }

            fn getOutermostIdx(self: @This(), roomnum: u2) ?usize {
                const room = self.outer.rooms[@intCast(usize, roomnum)];
                var i: usize = 0;
                while (i < room.len) : (i += 1) {
                    if (room[i] != null) return i;
                }

                return null;
            }

            fn routeLen(idx1: usize, idx2: usize) i32 {
                const x1 = @intCast(i32, idx1);
                const x2 = @intCast(i32, idx2);

                return std.math.absInt(x1 - x2) catch unreachable;
            }

            fn isSolved(self: @This(), roomnum: u2) bool {
                const room = self.outer.rooms[@intCast(usize, roomnum)];
                for (room) |amphin| {
                    const amphi = amphin orelse return false;
                    if (amphi.roomnum() != roomnum) return false;
                }

                return true;
            }

            fn advanceState(self: *@This()) void {
                switch (self.iter_state) {
                    .done => unreachable,
                    .hallway => self.advanceHallway(),
                    .room => |roomnum| self.advanceRoom(roomnum),
                }
            }

            fn advanceHallway(self: *@This()) void {
                const hallway = self.outer.hallway;
                self.idx += 1;
                while (self.idx < hallway.len and hallway[self.idx] == null) {
                    self.idx += 1;
                }

                if (self.idx >= hallway.len) {
                    self.iter_state = .{ .room = 0 };
                    self.makeIdxFirstAvailableForRoom();
                }
            }

            fn advanceRoom(self: *@This(), roomnum: u2) void {
                const hallway = self.outer.hallway;
                self.idx += 1;
                if (inFrontOfRoom(self.idx)) self.idx += 1;
                if (self.idx >= hallway.len or hallway[self.idx] != null) {
                    if (roomnum == 3) {
                        self.iter_state = .done;
                    } else {
                        self.iter_state = .{ .room = roomnum + 1 };
                        self.makeIdxFirstAvailableForRoom();
                    }
                }
            }

            fn makeIdxFirstAvailableForRoom(self: *@This()) void {
                const hallway = self.outer.hallway;
                self.idx = idxOfRoom(self.iter_state.room);
                while (self.idx > 0 and hallway[self.idx - 1] == null) {
                    self.idx -= 1;
                }

                if (inFrontOfRoom(self.idx)) self.idx += 1;
            }

            fn inFrontOfRoom(idx: usize) bool {
                return (idx == 2) or (idx == 4) or (idx == 6) or (idx == 8);
            }

            fn idxOfRoom(roomnum: u2) usize {
                return (@intCast(usize, roomnum) + 1) * 2;
            }
        };
    };
}

const final_state2 = State(2){
    .hallway = .{null} ** 11,
    .rooms = .{
        .{ .amber, .amber },
        .{ .bronze, .bronze },
        .{ .copper, .copper },
        .{ .desert, .desert },
    },
};

const final_state4 = State(4){
    .hallway = .{null} ** 11,
    .rooms = .{
        .{ .amber, .amber, .amber, .amber },
        .{ .bronze, .bronze, .bronze, .bronze },
        .{ .copper, .copper, .copper, .copper },
        .{ .desert, .desert, .desert, .desert },
    },
};

fn findDist(
    comptime roomsize: comptime_int,
    alloc: Allocator,
    begin_state: State(roomsize),
    end_state: State(roomsize),
) !i32 {
    var visited = HashMap(State(roomsize), void).init(alloc);
    var pqueue = helper.BinaryHashHeap(State(roomsize)).init(alloc);
    defer visited.deinit();
    defer pqueue.deinit();

    try pqueue.add(begin_state, 0);

    while (pqueue.heap.items.len > 0) {
        const min = pqueue.pop();
        // try min.state.print();
        if (min.data.eq(end_state)) return min.priority;

        var neighbors = min.data.neighbors();
        while (neighbors.next()) |neighbor| {
            if (visited.contains(neighbor.state)) continue;
            const state = neighbor.state;
            const cost = neighbor.cost;

            const alt = min.priority + cost;
            if (pqueue.getPriority(state)) |distv| {
                if (alt < distv) {
                    pqueue.changePriority(state, alt);
                }
            } else {
                try pqueue.add(state, alt);
            }
        }

        try visited.put(min.data, {});
    }

    return error.EndUnreachable;
}

const eql = std.mem.eql;
const tokenize = std.mem.tokenize;
const split = std.mem.split;
const count = std.mem.count;
const parseUnsigned = std.fmt.parseUnsigned;
const parseInt = std.fmt.parseInt;
const sort = std.sort.sort;
