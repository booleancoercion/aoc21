const std = @import("std");
const helper = @import("helper.zig");
const Allocator = std.mem.Allocator;

const input = @embedFile("../inputs/day8.txt");

const digits: [10][7]bool = .{
    .{ true, true, true, false, true, true, true },
    .{ false, false, true, false, false, true, false },
    .{ true, false, true, true, true, false, true },
    .{ true, false, true, true, false, true, true },
    .{ false, true, true, true, false, true, false },
    .{ true, true, false, true, false, true, true },
    .{ true, true, false, true, true, true, true },
    .{ true, false, true, false, false, true, false },
    .{ true, true, true, true, true, true, true },
    .{ true, true, true, true, false, true, true },
};

const Entry = struct {
    input: [10][]const u8,
    output: [4][]const u8,

    const Self = @This();

    pub fn fromLine(line: []const u8) Self {
        var sections = split(u8, line, "|");
        const section1 = sections.next().?;
        const section2 = sections.next().?;

        var input_arr: [10][]u8 = undefined;
        Self.populateHelper(section1, &input_arr);

        var output_arr: [4][]u8 = undefined;
        Self.populateHelper(section2, &output_arr);

        return Self{ .input = input_arr, .output = output_arr };
    }

    fn populateHelper(section: []const u8, arr: [][]const u8) void {
        var tokens = tokenize(u8, section, " ");
        for (arr) |*elem| {
            elem.* = tokens.next().?;
        }

        if (tokens.next() != null) unreachable;
    }
};

pub fn run(alloc: *Allocator, stdout: anytype) !void {
    const parsed = try parseInput(alloc);
    defer alloc.free(parsed);

    const res1 = part1(parsed);
    const res2 = part2(parsed);

    try stdout.print("Part 1: {}\n", .{res1});
    try stdout.print("Part 2: {}\n", .{res2});
}

fn part1(parsed: []Entry) i32 {
    var counter: i32 = 0;
    for (parsed) |*entry| {
        for (entry.output) |output| {
            const len = output.len;
            if (len == 2 or len == 4 or len == 3 or len == 7) {
                counter += 1;
            }
        }
    }

    return counter;
}

fn part2(parsed: []Entry) i32 {
    var sum: i32 = 0;
    for (parsed) |*entry| {
        sum += solveEntry(entry);
    }

    return sum;
}

fn solveEntry(entry: *const Entry) i32 {
    var letter_opts: [7][7]bool = .{.{true} ** 7} ** 7;

    eliminateEasy(entry, &letter_opts);
    // bruteforce is okay because there's exactly 8 possibilities to check
    const letter_maps = bruteforceOpts(entry, &letter_opts);

    return decipherEntry(entry, letter_maps);
}

fn eliminateEasy(entry: *const Entry, opts: *[7][7]bool) void {
    for (entry.input) |inp| {
        const digit: usize = switch (inp.len) {
            2 => 1,
            3 => 7,
            4 => 4,
            else => continue,
        };

        applyDigit(digit, inp, opts);
    }
}

fn applyDigit(digit: usize, inp: []const u8, opts: *[7][7]bool) void {
    for (opts) |*opt, i| {
        const letter = @intCast(u8, i) + 'a';
        const contained = std.mem.indexOfScalar(u8, inp, letter) != null;
        applyDigitToOpt(digit, opt, contained);
    }
}

fn applyDigitToOpt(digit: usize, opt: *[7]bool, contained: bool) void {
    const digit_arr: []const bool = &digits[digit];
    for (opt) |*field, i| {
        if (digit_arr[i] != contained) {
            field.* = false;
        }
    }
    // optimized from:
    //if (contained) {
    //    // only conserve stuff that's `true` in the digit's array
    //    for (opt) |*field, i| {
    //        if (!digit_arr[i]) {
    //            field.* = false;
    //        }
    //    }
    //} else {
    //    // only conserve stuff that's `false` in the digit's array
    //    for (opt) |*field, i| {
    //        if (digit_arr[i]) {
    //            field.* = false;
    //        }
    //    }
    //}
}

fn bruteforceOpts(entry: *const Entry, letter_opts: *const [7][7]bool) [7]usize {
    // 8 because exactly 8 possibilities
    const possible_meanings: [8][7]usize = getPossibleMeanings(letter_opts);
    for (possible_meanings) |meaning| {
        if (isConsistent(entry, &meaning)) return meaning;
    }

    unreachable; // the loop must find a consistent option
}

// this is so ugly
fn getPossibleMeanings(letter_opts: *const [7][7]bool) [8][7]usize {
    var meanings: [8][7]usize = undefined;

    for (meanings) |*meaning, i| {
        const choices: [3]bool = getChoices(i);
        var choice_idx: usize = 0;

        var occupied: [7]bool = .{false} ** 7;

        for (letter_opts) |*letter, letter_num| {
            var available: i32 = 0;
            for (letter) |opt, idx| {
                if (!opt) continue;
                if (occupied[idx]) continue;
                available += 1;
            }
            const needs_choice = available == 2;
            var chosen: bool = false;
            for (letter) |opt, idx| {
                if (!opt) continue;
                if (occupied[idx]) continue;
                if (!needs_choice or chosen) {
                    meaning[letter_num] = idx;
                    occupied[idx] = true;
                    break;
                }

                if (!choices[choice_idx]) {
                    choice_idx += 1;
                    meaning[letter_num] = idx;
                    occupied[idx] = true;
                    break;
                } else {
                    choice_idx += 1;
                    chosen = true;
                    continue;
                }
            }
        }
    }

    return meanings;
}

fn getChoices(x: usize) [3]bool {
    return .{
        x & 0b001 != 0,
        x & 0b010 != 0,
        x & 0b100 != 0,
    };
}

fn isConsistent(entry: *const Entry, meaning: *const [7]usize) bool {
    for (entry.input) |inp| {
        switch (inp.len) {
            2, 3, 4, 7 => continue, // these will always be consistent
            else => {},
        }

        if (getDigit(inp, meaning) == null) return false;
    }

    return true;
}

fn getDigit(inp: []const u8, meaning: *const [7]usize) ?usize {
    const digit = generateDigit(inp, meaning);
    return findDigit(&digit);
}

fn generateDigit(inp: []const u8, meaning: *const [7]usize) [7]bool {
    var digit: [7]bool = .{false} ** 7;
    for (inp) |letter| {
        const meaning_idx = @intCast(usize, letter - 'a');
        const idx = meaning[meaning_idx];
        digit[idx] = true;
    }

    return digit;
}

fn findDigit(digit_arr: *const [7]bool) ?usize {
    for (digits) |*digit, i| {
        if (std.mem.eql(bool, digit, digit_arr)) return i;
    }

    return null;
}

fn decipherEntry(entry: *const Entry, letter_maps: [7]usize) i32 {
    var result: i32 = 0;
    for (entry.output) |output| {
        const digit = getDigit(output, &letter_maps).?;

        result *= 10;
        result += @intCast(i32, digit);
    }

    return result;
}

fn parseInput(alloc: *Allocator) ![]Entry {
    const num_lines = count(u8, input, "\n");
    var entries = try alloc.alloc(Entry, num_lines);

    var lines = tokenize(u8, input, "\r\n");
    for (entries) |*entry| {
        entry.* = Entry.fromLine(lines.next().?);
    }

    if (lines.next() != null) unreachable;

    return entries;
}

const tokenize = std.mem.tokenize;
const split = std.mem.split;
const count = std.mem.count;
const parseUnsigned = std.fmt.parseUnsigned;
const parseInt = std.fmt.parseInt;
const sort = std.sort.sort;
