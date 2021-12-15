const std = @import("std");
const Allocator = std.mem.Allocator;
const Writer = std.io.Writer;
const GPA = std.heap.GeneralPurposeAllocator(.{});

const art = @embedFile("../art.txt");

const Days = @import("days.zig").Days;
const days: usize = std.meta.declarations(Days).len;

pub fn main() !void {
    var gpa: GPA = .{};
    const alloc = gpa.allocator();

    const stdout = std.io.getStdOut().writer();
    try stdout.print("{s}\n", .{art});

    var args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    const num_opt: ?usize = if (args.len <= 1) null else std.fmt.parseUnsigned(usize, args[1], 0) catch null;
    const num = num_opt orelse days;

    if (num < 1 or num > days) {
        std.log.err("Invalid day number!\n", .{});
    } else {
        var buffer: [5]u8 = undefined;
        const day = try std.fmt.bufPrint(&buffer, "day{d:0>2}", .{num});

        inline for (std.meta.declarations(Days)) |decl| {
            if (std.mem.eql(u8, day, decl.name)) {
                const cmd = @field(Days, decl.name);

                try stdout.print("-- Day {} --\n", .{num});
                return bench(alloc, cmd.run, stdout);
            }
        }

        // if we're here, none of the days have been executed.
        std.log.err("This day hasn't been solved yet!\n", .{});
    }
}

// Modified from <https://github.com/SpexGuy/Advent2021/blob/a71d4f299815cc191f6f0951ee22da9c8c4dafc9/src/day03.zig#L74-L93>
// Copyright (c) 2020-2021 Martin Wickham     licensed under MIT
fn bench(alloc: Allocator, run: anytype, stdout: anytype) !void {
    var i: usize = 0;
    var best_time: usize = std.math.maxInt(usize);
    var total_time: usize = 0;
    const num_runs = 10000;
    while (i < num_runs and total_time < 20 * 1000 * 1000 * 1000) : (i += 1) {
        if (i % 100 == 0) {
            try stdout.print("\rIteration no. {}", .{i});
        }
        std.mem.doNotOptimizeAway(total_time);
        const timer = try std.time.Timer.start();
        try @call(.{}, run, .{ alloc, null });
        asm volatile ("" ::: "memory");
        const lap_time = timer.read();
        if (best_time > lap_time) best_time = lap_time;
        total_time += lap_time;
    }
    try stdout.print("\n\nmin: ", .{});
    try printTime(stdout, best_time);

    try stdout.print("avg: ", .{});
    try printTime(stdout, total_time / i);
}

fn printTime(stdout: anytype, time: u64) !void {
    if (time < 1_000) {
        try stdout.print("{}ns\n", .{time});
    } else if (time < 1_000_000) {
        const ftime: f64 = @intToFloat(f64, time) / 1000.0;
        try stdout.print("{d:.2}μs\n", .{ftime});
    } else {
        const ftime: f64 = @intToFloat(f64, time) / 1_000_000.0;
        try stdout.print("{d:.2}ms\n", .{ftime});
    }
}
