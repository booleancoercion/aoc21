const std = @import("std");
const Allocator = std.mem.Allocator;
const TokenIterator = std.mem.TokenIterator;
const BoardList = std.TailQueue(*Board);

const input = @embedFile("../inputs/day04.txt");

const board_side = 5;

const Board = struct {
    nums: [board_side][board_side]u8,
    marks: [board_side][board_side]bool,

    row_counts: [board_side]u8,
    col_counts: [board_side]u8,

    /// Potentially marks the given number on this board.
    /// If the marking leads to a bingo, returns the resulting score,
    /// and otherwise returns null.
    pub fn markNum(self: *Board, num: u8) ?i32 {
        var bingo = false;

        var row: usize = 0;
        while (row < board_side) : (row += 1) {
            var col: usize = 0;
            while (col < board_side) : (col += 1) {
                if (self.nums[row][col] != num) continue;
                if (self.marks[row][col]) unreachable; // why would a number be called twice?

                self.marks[row][col] = true;
                self.row_counts[row] += 1;
                self.col_counts[col] += 1;

                if (self.row_counts[row] == board_side or self.col_counts[col] == board_side) {
                    bingo = true;
                    // we must continue marking the board
                }
            }
        }

        if (bingo) {
            return self.calculateScore(num);
        } else {
            return null;
        }
    }

    pub fn reset(self: *Board) void {
        var i: usize = 0;
        while (i < board_side) : (i += 1) {
            self.row_counts[i] = 0;
            self.col_counts[i] = 0;

            var j: usize = 0;
            while (j < board_side) : (j += 1) {
                self.marks[i][j] = false;
            }
        }
    }

    fn calculateScore(self: *const Board, last_num: u8) i32 {
        var total: i32 = 0;

        var i: usize = 0;
        while (i < board_side) : (i += 1) {
            var j: usize = 0;
            while (j < board_side) : (j += 1) {
                if (!self.marks[i][j]) {
                    total += self.nums[i][j];
                }
            }
        }

        return total * last_num;
    }
};

const Input = struct {
    allocator: *Allocator,
    sequence: []const u8,
    boards: []Board,

    pub fn free(self: *const Input) void {
        self.allocator.free(self.sequence);
        self.allocator.free(self.boards);
    }
};

pub fn run(alloc: *Allocator, stdout: anytype) !void {
    const parsed = try parseInput(alloc);
    defer parsed.free();

    try stdout.print("Part 1: {}\n", .{part1(parsed)});
    for (parsed.boards) |*board| {
        board.reset();
    }
    try stdout.print("Part 1: {}\n", .{try part2(alloc, parsed)});
}

fn part1(parsed: Input) i32 {
    for (parsed.sequence) |num| {
        for (parsed.boards) |*board| {
            if (board.markNum(num)) |score| {
                return score;
            }
        }
    }

    unreachable;
}

fn part2(alloc: *Allocator, parsed: Input) !i32 {
    const board_nodes = try alloc.alloc(BoardList.Node, parsed.boards.len);
    defer alloc.free(board_nodes);

    var list = BoardList{};
    for (board_nodes) |*node, i| {
        node.data = &parsed.boards[i];
        list.append(node);
    }

    for (parsed.sequence) |num| {
        var curr = list.first;
        while (curr) |node| {
            if (node.data.markNum(num)) |score| {
                if (list.len == 1) {
                    return score;
                } else {
                    const next = node.next;
                    list.remove(node);
                    curr = next;
                }
            } else {
                curr = node.next;
            }
        }
    }

    unreachable;
}

fn parseInput(alloc: *Allocator) !Input {
    var tokens = std.mem.tokenize(u8, input, "\r\n");
    const first_line = tokens.next().?;

    const sequence = try parseSequence(alloc, first_line);
    const boards = try parseBoards(alloc, tokens);

    return Input{ .allocator = alloc, .sequence = sequence, .boards = boards };
}

fn parseBoards(alloc: *Allocator, tokens_c: TokenIterator(u8)) ![]Board {
    var tokens = tokens_c;
    // Each board has exactly (board_side + 1) newlines corresponding to it, except for the
    // last board which has one less (thus we add an extra 1)
    const num_boards: usize = (std.mem.count(u8, tokens.rest(), "\n") + 1) / (board_side + 1);
    var boards = try alloc.alloc(Board, num_boards);

    var i: usize = 0;
    while (i < num_boards) : (i += 1) {
        var j: usize = 0;
        while (j < board_side) : (j += 1) {
            boards[i].row_counts[j] = 0;
            boards[i].col_counts[j] = 0;

            const line = tokens.next().?;
            var numbers = std.mem.tokenize(u8, line, " ");

            var k: usize = 0;
            while (k < board_side) : (k += 1) {
                const number = numbers.next().?;
                boards[i].nums[j][k] = try std.fmt.parseUnsigned(u8, number, 10);
                boards[i].marks[j][k] = false;
            }

            if (numbers.next() != null) unreachable;
        }
    }

    if (tokens.next() != null) unreachable;

    return boards;
}

fn parseSequence(alloc: *Allocator, line: []const u8) ![]u8 {
    // every two numbers in the sequence are separated by a comma
    const seq_len = std.mem.count(u8, line, ",") + 1;

    var sequence = try alloc.alloc(u8, seq_len);
    var split = std.mem.split(u8, line, ",");

    var i: usize = 0;
    while (split.next()) |num| : (i += 1) {
        sequence[i] = try std.fmt.parseUnsigned(u8, num, 10);
    }

    if (i < seq_len) unreachable; // sanity check

    return sequence;
}
