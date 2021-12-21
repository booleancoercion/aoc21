const std = @import("std");
const helper = @import("helper.zig");
const Allocator = std.mem.Allocator;
const HashMap = std.AutoHashMap;

const input = @embedFile("../inputs/day21.txt");

pub fn run(alloc: Allocator, stdout_: anytype) !void {
    const nums = try parseInput(input);

    const res1 = part1(nums);
    const res2 = try part2(alloc, nums);

    if (stdout_) |stdout| {
        try stdout.print("Part 1: {}\n", .{res1});
        try stdout.print("Part 2: {}\n", .{res2});
    }
}

fn parseInput(inp: []const u8) ![2]i32 {
    var tokens = tokenize(u8, inp, " \r\n");

    var nums: [2]i32 = undefined;
    for (nums) |*num| {
        _ = tokens.next();
        _ = tokens.next();
        _ = tokens.next();
        _ = tokens.next();
        num.* = try parseInt(i32, tokens.next().?, 10);
    }

    return nums;
}

fn part1(nums: [2]i32) i32 {
    var game = Game.init(nums[0], nums[1]);
    while (game.players[0].score < 1000 and game.players[1].score < 1000) {
        game.advance();
    }

    return game.players[game.turn].score * game.die.rolls;
}

const Game = struct {
    die: Die,
    players: [2]Player,
    turn: usize = 0,

    pub fn init(player1: i32, player2: i32) @This() {
        return .{
            .die = .{},
            .players = .{
                .{ .current_space = player1 },
                .{ .current_space = player2 },
            },
        };
    }

    pub fn advance(self: *@This()) void {
        const player = &self.players[self.turn];
        player.advance(&self.die);

        self.turn = 1 - self.turn;
    }
};

const Die = struct {
    current_face: i32 = 1,
    rolls: i32 = 0,

    pub fn roll(self: *@This()) i32 {
        self.rolls += 1;
        defer {
            self.current_face = @mod(self.current_face + 1 - 1, 100) + 1;
        }

        return self.current_face;
    }
};

const Player = struct {
    current_space: i32,
    score: i32 = 0,

    pub fn advance(self: *@This(), die: *Die) void {
        var sum: i32 = 0;
        var i: usize = 0;
        while (i < 3) : (i += 1) {
            sum += die.roll();
        }

        self.advanceNum(sum);
    }

    pub fn advanceNum(self: *@This(), num: i32) void {
        self.current_space = @mod(self.current_space + num - 1, 10) + 1;
        self.score += self.current_space;
    }
};

const RollValue = struct { value: i32, times: i32 };
const dice_roll_values: [7]RollValue = .{
    RollValue{ .value = 3, .times = 1 },
    RollValue{ .value = 4, .times = 3 },
    RollValue{ .value = 5, .times = 6 },
    RollValue{ .value = 6, .times = 7 },
    RollValue{ .value = 7, .times = 6 },
    RollValue{ .value = 8, .times = 3 },
    RollValue{ .value = 9, .times = 1 },
}; // precalculated

const UMap = HashMap([2]Player, i64);

fn part2(alloc: Allocator, nums: [2]i32) !i64 {
    var qgame = try QGame.init(alloc, nums);
    defer qgame.deinit();

    while (qgame.universes.count() > 0) {
        try qgame.advance();
    }

    return std.math.max(qgame.wins[0], qgame.wins[1]);
}

const QGame = struct {
    universes: UMap,
    buffer: UMap,
    wins: [2]i64,
    turn: usize = 0,

    pub fn init(alloc: Allocator, nums: [2]i32) !@This() {
        var universes = UMap.init(alloc);
        try universes.ensureTotalCapacity(10 * 10 * 21 * 21); // number of possible universes, ~44k

        var buffer = UMap.init(alloc);
        try buffer.ensureTotalCapacity(10 * 10 * 21 * 21);

        try universes.put(.{
            .{ .current_space = nums[0] },
            .{ .current_space = nums[1] },
        }, 1);

        return @This(){
            .universes = universes,
            .buffer = buffer,
            .wins = .{ 0, 0 },
        };
    }

    pub fn advance(self: *@This()) !void {
        self.buffer.clearRetainingCapacity();

        var entries = self.universes.iterator();
        while (entries.next()) |entry| {
            for (dice_roll_values) |rollvalue| {
                var key = entry.key_ptr.*;
                key[self.turn].advanceNum(rollvalue.value);

                const num = rollvalue.times * entry.value_ptr.*;

                if (key[self.turn].score >= 21) {
                    self.wins[self.turn] += num;
                } else {
                    var newentry = try self.buffer.getOrPutValue(key, 0);
                    newentry.value_ptr.* += num;
                }
            }
        }

        self.turn = 1 - self.turn;
        std.mem.swap(UMap, &self.universes, &self.buffer);
    }

    pub fn deinit(self: *@This()) void {
        self.universes.deinit();
        self.buffer.deinit();
    }
};

const eql = std.mem.eql;
const tokenize = std.mem.tokenize;
const split = std.mem.split;
const count = std.mem.count;
const parseUnsigned = std.fmt.parseUnsigned;
const parseInt = std.fmt.parseInt;
const sort = std.sort.sort;
