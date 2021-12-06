const std = @import("std");

pub fn sum(comptime T: type, slice: []const T) T {
    var s: T = 0;
    for (slice) |elem| {
        s = s + elem;
    }

    return s;
}
