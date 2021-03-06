const std = @import("std");
const Allocator = std.mem.Allocator;
const Writer = std.io.Writer;
const GPA = std.heap.GeneralPurposeAllocator(.{
    .safety = true,
    .never_unmap = false, // for debugging, change this to true
});

const art = @embedFile("../art.txt");

const Days = @import("days.zig").Days;
const days: usize = std.meta.declarations(Days).len;

pub fn main() !void {
    var gpa: GPA = .{};
    const alloc = gpa.allocator();
    defer { // for leak detection
        _ = gpa.deinit();
    }

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
                const stdout_: @TypeOf(stdout, null) = stdout;
                return cmd.run(alloc, stdout_);
            }
        }

        // if we're here, none of the days have been executed.
        std.log.err("This day hasn't been solved yet!\n", .{});
    }
}
