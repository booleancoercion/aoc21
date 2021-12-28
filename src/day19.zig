const std = @import("std");
const helper = @import("helper.zig");
const Allocator = std.mem.Allocator;
const Vec3 = @Vector(3, i32);
const ArrayList = std.ArrayList;
const HashMap = std.AutoHashMap;

const input = @embedFile("../inputs/day19.txt");

pub fn run(alloc: Allocator, stdout_: anytype) !void {
    _ = stdout_;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    const scanners: []Scanner = try parseScanners(arena_alloc, input);
    try matchScanners(scanners);

    const assemble_res = try assembleMap(arena_alloc, scanners);
    const map = assemble_res.map;
    const positions = assemble_res.positions;

    const res1 = map.count();
    const res2 = maxDistance(positions);
    if (stdout_) |stdout| {
        try stdout.print("Part 1: {}\n", .{res1});
        try stdout.print("Part 2: {}\n", .{res2});
    }
}

fn matchScanners(scanners: []Scanner) !void {
    for (scanners) |*scanner1, i| {
        var j: usize = i + 1;
        while (j < scanners.len) : (j += 1) {
            const scanner2 = &scanners[j];

            try scanner1.matches(scanner2);
        }
    }
}

const AssembleRes = struct {
    map: HashMap(Vec3, void),
    positions: []?Vec3,
};

fn maxDistance(positions: []?Vec3) i32 {
    var dist: i32 = std.math.minInt(i32);

    for (positions) |pos1, i| {
        var j: usize = i + 1;
        while (j < positions.len) : (j += 1) {
            const curr: [3]i32 = pos1.? - positions[j].?;

            dist = std.math.max(dist, abs(curr[0]) + abs(curr[1]) + abs(curr[2]));
        }
    }

    return dist;
}

fn assembleMap(alloc: Allocator, scanners: []const Scanner) !AssembleRes {
    var map = HashMap(Vec3, void).init(alloc);
    const reached = try alloc.alloc(?Vec3, scanners.len);

    try assembleMapInner(scanners, &map, reached, 0, rots[0], [3]i32{ 0, 0, 0 });

    return AssembleRes{ .map = map, .positions = reached };
}

fn assembleMapInner(
    scanners: []const Scanner,
    map: *HashMap(Vec3, void),
    reached: []?Vec3,
    idx: usize,
    mat: Mat3,
    offset: Vec3,
) Allocator.Error!void {
    const scanner = scanners[idx];
    reached[idx] = offset; // store the scanner's offset, aka its position :)

    var points_iter = scanner.points.keyIterator();
    while (points_iter.next()) |point| {
        const translated = mulVec(mat, point.*) + offset;
        try map.put(translated, {});
    }

    for (scanner.match_data.items) |match| {
        const match_idx = match.scanner_idx;
        if (reached[match_idx] != null) continue;

        const new_mat = mulMat(mat, rots[match.mat_idx]);
        const new_offset = mulVec(mat, match.offset) + offset;

        try assembleMapInner(scanners, map, reached, match_idx, new_mat, new_offset);
    }
}

fn parseScanners(alloc: Allocator, inp: []const u8) ![]Scanner {
    var lines = helper.getlines(inp);
    _ = lines.next(); // get rid of the first line
    var scanners = ArrayList(Scanner).init(alloc);

    var idx: usize = 0;
    while (lines.rest().len > 0) : (idx += 1) {
        const scanner = try scanners.addOne();
        scanner.* = Scanner.init(alloc, idx);

        while (lines.next()) |line| {
            if (std.mem.startsWith(u8, line, "---")) break;
            const vec = try parseVec(line);
            try scanner.addPoint(vec);
        }
    }

    return scanners.toOwnedSlice();
}

fn parseVec(line: []const u8) !Vec3 {
    var splut = split(u8, line, ",");
    var vals: [3]i32 = undefined;
    for (vals) |*val| {
        val.* = try parseInt(i32, splut.next().?, 10);
    }

    const vec: Vec3 = vals;
    return vec;
}

const DiffMap = HashMap(Vec3, ArrayList([2]Vec3));
const MatchInfo = struct { scanner_idx: usize, mat_idx: usize, offset: Vec3 };

const Scanner = struct {
    idx: usize,
    points: HashMap(Vec3, void),
    diffs: DiffMap,
    match_data: ArrayList(MatchInfo), // how to get *from* other *to* self
    alloc: Allocator,

    const Self = @This();

    pub fn init(alloc: Allocator, idx: usize) Self {
        return Self{
            .idx = idx,
            .points = HashMap(Vec3, void).init(alloc),
            .diffs = DiffMap.init(alloc),
            .match_data = ArrayList(MatchInfo).init(alloc),
            .alloc = alloc,
        };
    }

    fn getDiffArr(self: Self, diff: Vec3) ?*ArrayList([2]Vec3) {
        if (self.diffs.getPtr(diff)) |arr| return arr;
        if (self.diffs.getPtr(-diff)) |arr| return arr;
        return null;
    }

    pub fn addPoint(self: *Self, point: Vec3) !void {
        const res = try self.points.fetchPut(point, {});
        if (res != null) return;

        var keys = self.points.keyIterator();
        while (keys.next()) |key| {
            if (vecAll(key.* == point)) continue;
            const diff = key.* - point;

            const arr = if (self.getDiffArr(diff)) |val| val else blk: {
                const entry = try self.diffs.getOrPutValue(
                    diff,
                    ArrayList([2]Vec3).init(self.alloc),
                );
                break :blk entry.value_ptr;
            };

            try arr.append(.{ key.*, point });
        }
    }

    pub fn matches(self: *Self, other: *Self) !void {
        for (rots) |_, rot| {
            if (self.matchesRot(other, rot)) |offset| { // other/self are switched here because i'm stupid
                try self.match_data.append(MatchInfo{
                    .scanner_idx = other.idx,
                    .mat_idx = rot,
                    .offset = offset,
                });

                try other.match_data.append(MatchInfo{
                    .scanner_idx = self.idx,
                    .mat_idx = inv_indices[rot],
                    .offset = -mulVec(rots[inv_indices[rot]], offset),
                });
            }
        }
    }

    /// Return value is the offset of other, after rotating, where the match occurs.
    fn matchesRot(self: *const Self, other: *const Self, rot: usize) ?Vec3 {
        // other is manipulated w.r.t self, that is, shifted and rotated.
        if (!self.hasEnoughMatchingPairs(other, rot)) return null;

        var other_diffs = other.diffs.iterator();
        while (other_diffs.next()) |entry| {
            const diff = entry.key_ptr.*;
            const other_arr = entry.value_ptr.items;

            const rotated = mulVec(rots[rot], diff);
            const my_arr = self.diffs.get(rotated) orelse continue;

            for (my_arr.items) |my_pair| for (other_arr) |other_pair| {
                const v1 = mulVec(rots[rot], other_pair[0]);
                const v2 = mulVec(rots[rot], other_pair[1]);
                const offset = calculateOffset(my_pair, .{ v1, v2 });

                if (self.matchesRotOffset(other, rot, offset)) return offset;
            };
        }

        return null;
    }

    fn matchesRotOffset(self: *const Self, other: *const Self, rot: usize, offset: Vec3) bool {
        var other_points = other.points.keyIterator();
        var match_sum: i32 = 0;
        while (other_points.next()) |other_point| {
            const translated = mulVec(rots[rot], other_point.*) + offset;
            if (self.points.contains(translated)) match_sum += 1;
        }

        return match_sum >= 12;
    }

    fn calculateOffset(pair1: [2]Vec3, pair2: [2]Vec3) Vec3 {
        const diff1 = pair1[0] - pair1[0];
        const diff2 = pair2[0] - pair2[1];

        if (vecAll(diff1 == diff2)) {
            return pair1[0] - pair2[0];
        } else { // diff1 == -diff2
            return pair1[1] - pair2[1];
        }
    }

    fn hasEnoughMatchingPairs(self: *const Self, other: *const Self, rot: usize) bool {
        var other_diffs = other.diffs.iterator();
        var match_sum: usize = 0;
        while (other_diffs.next()) |entry| {
            const diff = entry.key_ptr.*;
            const other_len = entry.value_ptr.items.len;

            const rotated = mulVec(rots[rot], diff);
            if (self.diffs.get(rotated)) |arr| {
                match_sum += std.math.min(other_len, arr.items.len);
            }
        }

        return match_sum >= 6; // less than 6 matching *pairs*
    }
};

const Mat3 = [3]Vec3; // an array of rows

fn transpose(mat: Mat3) Mat3 {
    const rows: [3][3]i32 = .{ mat[0], mat[1], mat[2] };

    return .{
        [3]i32{ rows[0][0], rows[1][0], rows[2][0] },
        [3]i32{ rows[0][1], rows[1][1], rows[2][1] },
        [3]i32{ rows[0][2], rows[1][2], rows[2][2] },
    };
}

fn mulVec(mat: Mat3, vec: Vec3) Vec3 {
    const out: Vec3 = .{
        vecSum(mat[0] * vec),
        vecSum(mat[1] * vec),
        vecSum(mat[2] * vec),
    };

    return out;
}

fn mulMat(mat1: Mat3, mat2: Mat3) Mat3 {
    const cols2 = transpose(mat2);

    return Mat3{
        [3]i32{ vecSum(mat1[0] * cols2[0]), vecSum(mat1[0] * cols2[1]), vecSum(mat1[0] * cols2[2]) },
        [3]i32{ vecSum(mat1[1] * cols2[0]), vecSum(mat1[1] * cols2[1]), vecSum(mat1[1] * cols2[2]) },
        [3]i32{ vecSum(mat1[2] * cols2[0]), vecSum(mat1[2] * cols2[1]), vecSum(mat1[2] * cols2[2]) },
    };
}

fn vecSum(vec: Vec3) i32 {
    const arr: [3]i32 = vec;
    return arr[0] + arr[1] + arr[2];
}

fn vecAll(vec: @Vector(3, bool)) bool {
    const arr: [3]bool = vec;
    return arr[0] and arr[1] and arr[2];
}

const rots: [24]Mat3 = .{
    .{ [3]i32{ 1, 0, 0 }, [3]i32{ 0, 1, 0 }, [3]i32{ 0, 0, 1 } },
    .{ [3]i32{ -1, 0, 0 }, [3]i32{ 0, -1, 0 }, [3]i32{ 0, 0, 1 } },
    .{ [3]i32{ -1, 0, 0 }, [3]i32{ 0, 1, 0 }, [3]i32{ 0, 0, -1 } },
    .{ [3]i32{ 1, 0, 0 }, [3]i32{ 0, -1, 0 }, [3]i32{ 0, 0, -1 } },

    .{ [3]i32{ -1, 0, 0 }, [3]i32{ 0, 0, 1 }, [3]i32{ 0, 1, 0 } },
    .{ [3]i32{ 1, 0, 0 }, [3]i32{ 0, 0, -1 }, [3]i32{ 0, 1, 0 } },
    .{ [3]i32{ 1, 0, 0 }, [3]i32{ 0, 0, 1 }, [3]i32{ 0, -1, 0 } },
    .{ [3]i32{ -1, 0, 0 }, [3]i32{ 0, 0, -1 }, [3]i32{ 0, -1, 0 } },

    .{ [3]i32{ 0, -1, 0 }, [3]i32{ 1, 0, 0 }, [3]i32{ 0, 0, 1 } },
    .{ [3]i32{ 0, 1, 0 }, [3]i32{ -1, 0, 0 }, [3]i32{ 0, 0, 1 } },
    .{ [3]i32{ 0, 1, 0 }, [3]i32{ 1, 0, 0 }, [3]i32{ 0, 0, -1 } },
    .{ [3]i32{ 0, -1, 0 }, [3]i32{ -1, 0, 0 }, [3]i32{ 0, 0, -1 } },

    .{ [3]i32{ 0, 1, 0 }, [3]i32{ 0, 0, 1 }, [3]i32{ 1, 0, 0 } },
    .{ [3]i32{ 0, -1, 0 }, [3]i32{ 0, 0, -1 }, [3]i32{ 1, 0, 0 } },
    .{ [3]i32{ 0, -1, 0 }, [3]i32{ 0, 0, 1 }, [3]i32{ -1, 0, 0 } },
    .{ [3]i32{ 0, 1, 0 }, [3]i32{ 0, 0, -1 }, [3]i32{ -1, 0, 0 } },

    .{ [3]i32{ 0, 0, 1 }, [3]i32{ 1, 0, 0 }, [3]i32{ 0, 1, 0 } },
    .{ [3]i32{ 0, 0, -1 }, [3]i32{ -1, 0, 0 }, [3]i32{ 0, 1, 0 } },
    .{ [3]i32{ 0, 0, -1 }, [3]i32{ 1, 0, 0 }, [3]i32{ 0, -1, 0 } },
    .{ [3]i32{ 0, 0, 1 }, [3]i32{ -1, 0, 0 }, [3]i32{ 0, -1, 0 } },

    .{ [3]i32{ 0, 0, -1 }, [3]i32{ 0, 1, 0 }, [3]i32{ 1, 0, 0 } },
    .{ [3]i32{ 0, 0, 1 }, [3]i32{ 0, -1, 0 }, [3]i32{ 1, 0, 0 } },
    .{ [3]i32{ 0, 0, 1 }, [3]i32{ 0, 1, 0 }, [3]i32{ -1, 0, 0 } },
    .{ [3]i32{ 0, 0, -1 }, [3]i32{ 0, -1, 0 }, [3]i32{ -1, 0, 0 } },
};

const inv_indices: [24]usize = blk: {
    var idxs: [24]usize = undefined;
    @setEvalBranchQuota(2000);

    for (idxs) |*idx, i| {
        // the inverse of an orthogonal real matrix is its transpose
        const trans = transpose(rots[i]);
        for (rots) |rot, j| {
            if (vecAll(rot[0] == trans[0]) and vecAll(rot[1] == trans[1]) and vecAll(rot[2] == trans[2])) {
                idx.* = j;
            }
        }
    }

    break :blk idxs;
};

const abs = helper.abs;
const eql = std.mem.eql;
const tokenize = std.mem.tokenize;
const split = std.mem.split;
const count = std.mem.count;
const parseUnsigned = std.fmt.parseUnsigned;
const parseInt = std.fmt.parseInt;
const sort = std.sort.sort;
