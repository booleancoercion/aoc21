const std = @import("std");
const helper = @import("helper.zig");
const Allocator = std.mem.Allocator;
const HashMap = std.AutoHashMap;

const input = @embedFile("../inputs/day17.txt");

pub fn run(alloc: Allocator, stdout_: anytype) !void {
    const area = try Area.parse(input);

    var stepnums = try getStepNums(alloc, area);
    defer stepnums.deinit();

    const res1 = getMaxYPossible(stepnums, area);

    var velmap = HashMap(Point, void).init(alloc);
    defer velmap.deinit();

    try calculateAllVelocities(stepnums, area, &velmap);
    const res2 = velmap.count();

    if (stdout_) |stdout| {
        try stdout.print("Part 1: {}\n", .{res1});
        try stdout.print("Part 2: {}\n", .{res2});
    }
}

fn getMaxYPossible(stepnums: HashMap(Point, void), area: Area) i64 {
    var max: i64 = std.math.minInt(i64);
    var keys = stepnums.keyIterator();
    while (keys.next()) |steps| {
        // if this was more complicated to solve, we'd have to iterate over all
        // possible values of y in a loop - however, since this is essentially
        // solving a linear equation, we can do the whole area at once as an
        // optimization.
        if (getPositiveY(steps.y, area)) |y| {
            max = std.math.max(max, y);
        }
    }

    return max;
}

fn getPositiveY(steps: i64, area: Area) ?i64 {
    // trying to solve:
    // y_init + (y_init - 1) + ... + 1 + 0 - 1 - ... - (steps - y_init - 1) = t
    //
    // this reduces to:
    // (steps^2 - steps)/2 + t = steps*y_init
    // which is solved by:
    // y_init = (steps^2 - steps + 2t)/2steps
    // (there's a prettier form but it's harder to verify that there's an integer solution for it)
    //
    // to solve an inequality f(y_init, steps) <= t where f is the function above,
    // we can simply substitute the equals sign for the <= sign because y_init switches
    // sides and there's a single negative division. Similarly for >=.

    if (steps <= 0) { // degenerate case that must be handled first
        return null;
    }

    const enumerator = steps * steps - steps;
    const enumerator_min = enumerator + 2 * area.ymin;
    const enumerator_max = enumerator + 2 * area.ymax;
    const denominator = 2 * steps;

    const y_init_max = @divFloor(enumerator_max, denominator); // flooring division is intentional

    if (y_init_max * denominator < enumerator_min) { // no integer solutions will fit here
        return null;
    }

    if (y_init_max > 0) {
        return @divExact(y_init_max * (y_init_max + 1), 2); // y_init_max + (y_init_max - 1) + ... + 1 + 0
    } else {
        return 0;
    }
}

fn calculateAllVelocities(
    stepnums: HashMap(Point, void),
    area: Area,
    velmap: *HashMap(Point, void),
) !void {
    var keys = stepnums.keyIterator();
    while (keys.next()) |pt| {
        const vx = pt.x;
        const steps = pt.y;

        try addVYs(vx, steps, velmap, area);
    }
}

fn addVYs(vx: i64, steps: i64, velmap: *HashMap(Point, void), area: Area) !void {
    if (steps <= 0) { // degenerate case that must be handled first
        return;
    }

    const enumerator = steps * steps - steps;
    const enumerator_min = enumerator + 2 * area.ymin;
    const enumerator_max = enumerator + 2 * area.ymax;
    const denominator = 2 * steps;

    var y_init = @divFloor(enumerator_max, denominator);

    while (y_init * denominator >= enumerator_min) : (y_init -= 1) {
        try velmap.put(Point{ .x = vx, .y = y_init }, {});
    }
}

fn getStepNums(alloc: Allocator, area: Area) !HashMap(Point, void) {
    var stepmap = HashMap(Point, void).init(alloc);

    var vx: i64 = 0;
    while (vx <= area.xmax) : (vx += 1) {
        try getStepsFromVx(vx, area, &stepmap);
    }

    return stepmap;
}

fn getStepsFromVx(vx_: i64, area: Area, stepmap: *HashMap(Point, void)) !void {
    var vx = vx_;
    if (vx < 0) unreachable;
    var t: i64 = 0;
    var xpos: i64 = 0;

    while (xpos < area.xmax and t < 1000) { // arbitrary limit for t :(
        xpos += vx;
        if (vx > 0) {
            vx -= 1;
        }
        t += 1;

        if (area.xmin <= xpos and area.xmax >= xpos) {
            try stepmap.put(Point{ .x = vx_, .y = t }, {});
        }
    }
}

const Point = struct { x: i64, y: i64 };

const Area = struct {
    xmin: i64,
    xmax: i64,
    ymin: i64,
    ymax: i64,

    const Self = @This();

    pub fn parse(inp: []const u8) !Self {
        var nums_iter = tokenize(u8, inp, "targe :x=.,y\r\n"); // crude but eh

        const x1 = try parseInt(i64, nums_iter.next().?, 10);
        const x2 = try parseInt(i64, nums_iter.next().?, 10);
        const y1 = try parseInt(i64, nums_iter.next().?, 10);
        const y2 = try parseInt(i64, nums_iter.next().?, 10);

        return Self{
            .xmin = std.math.min(x1, x2),
            .xmax = std.math.max(x1, x2),
            .ymin = std.math.min(y1, y2),
            .ymax = std.math.max(y1, y2),
        };
    }

    pub fn contains(self: Self, pt: Point) bool {
        const x = pt.x;
        const y = pt.y;

        return (self.xmin <= x and self.xmax >= x and self.ymin <= y and self.ymax >= y);
    }
};

const eql = std.mem.eql;
const tokenize = std.mem.tokenize;
const split = std.mem.split;
const count = std.mem.count;
const parseUnsigned = std.fmt.parseUnsigned;
const parseInt = std.fmt.parseInt;
const sort = std.sort.sort;
const absInt = std.math.absInt;
