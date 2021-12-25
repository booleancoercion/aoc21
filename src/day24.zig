// The following code is NOT the solution. This program
// merely tries to minimize the given expression and fails
// miserably because it's much easier to interpret as a program.

// Here's how I solved it by hand:
// list1 = [14,13,15,13,-2,10,13,-15,11,-9,-9,-7,-4,-6]
// list2 = [00,12,14,00,03,15,11, 12,01,12,03,10,14,12]
// i     =   0  1  2  3  4  5  6   7  8  9 10 11 12 13

// for i in range(14):
//     x = peek() + list1[i]
//     if list1[i] < 0:
//         pop()
//     if x != n[i]:
//         push(n[i] + list2[i])

// Each index where list1 is negative matches some other
// index where it's positive, like a stack.
// The lists provide dummy numbers that are added to the
// value contained in the stack, from which we extract
// the following equations:

// in[3] + 0 - 2 == in[4]
// in[6] + 11 - 15 == in[7]
// in[8] + 1 - 9 == in[9]
// in[5] + 15 - 9 == in[10]
// in[2] + 14 - 7 == in[11]
// in[1] + 12 - 4 == in[12]
// in[0] + 0 - 6 == in[13]

// in[3] - 2 == in[4]
// in[6] - 4 == in[7]
// in[8] - 8 == in[9]
// in[5] + 6 == in[10]
// in[2] + 7 == in[11]
// in[1] + 8 == in[12]
// in[0] - 6 == in[13]

// -- Part 1 --

// in[3] == 9
// in[4] == 7
// in[6] == 9
// in[7] == 5
// in[8] == 9
// in[9] == 1
// in[5] == 3
// in[10] == 9
// in[2] == 2
// in[11] == 9
// in[1] == 1
// in[12] == 9
// in[0] == 9
// in[13] == 3

// in[0] == 9
// in[1] == 1
// in[2] == 2
// in[3] == 9
// in[4] == 7
// in[5] == 3
// in[6] == 9
// in[7] == 5
// in[8] == 9
// in[9] == 1
// in[10] == 9
// in[11] == 9
// in[12] == 9
// in[13] == 3

// 91297395919993

// -- Part 2 --

// in[3] = 3
// in[4] = 1
// in[6] = 5
// in[7] = 1
// in[8] = 9
// in[9] = 1
// in[5] = 1
// in[10] = 7
// in[2] = 1
// in[11] = 8
// in[1] = 1
// in[12] = 9
// in[0] = 7
// in[13] = 1

// in[0] = 7
// in[1] = 1
// in[2] = 1
// in[3] = 3
// in[4] = 1
// in[5] = 1
// in[6] = 5
// in[7] = 1
// in[8] = 9
// in[9] = 1
// in[10] = 7
// in[11] = 8
// in[12] = 9
// in[13] = 1

// 71131151917891

const std = @import("std");
const helper = @import("helper.zig");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const HashMap = std.AutoHashMap;

const input = @embedFile("../inputs/day24.txt");

pub fn run(alloc: Allocator, stdout_: anytype) !void {
    const instructions = try parseInstructions(alloc, input);
    defer alloc.free(instructions);

    var consteval = ConstEval.init(alloc);
    defer consteval.deinit();
    consteval.evalMany(instructions);

    if (stdout_) |stdout| {
        try consteval.get(.z).print(stdout);
        try stdout.print("\n{}\n", .{consteval.minmax.get(consteval.get(.z))});
    }
}

const Reg = enum(usize) {
    w,
    x,
    y,
    z,

    pub fn fromLetter(letter: u8) Reg {
        return switch (letter) {
            'w' => .w,
            'x' => .x,
            'y' => .y,
            'z' => .z,
            else => unreachable,
        };
    }
};
const RegNum = union(enum) { reg: Reg, num: i64 };
const RegPair = struct { a: Reg, b: RegNum };

const Inst = union(enum) {
    inp: Reg,
    add: RegPair,
    mul: RegPair,
    div: RegPair,
    mod: RegPair,
    eql: RegPair,

    pub fn parse(line: []const u8) !Inst {
        var splut = split(u8, line, " ");
        const opcode = splut.next().?;
        const reg1 = Reg.fromLetter(splut.next().?[0]);

        if (std.mem.eql(u8, opcode, "inp")) {
            return Inst{ .inp = reg1 };
        }

        const reg2str = splut.next().?;
        var reg2: RegNum = undefined;
        if (std.ascii.isDigit(reg2str[0]) or reg2str[0] == '-') {
            reg2 = .{ .num = try parseInt(i64, reg2str, 10) };
        } else {
            reg2 = .{ .reg = Reg.fromLetter(reg2str[0]) };
        }

        const pair = RegPair{ .a = reg1, .b = reg2 };
        return if (std.mem.eql(u8, opcode, "add"))
            Inst{ .add = pair }
        else if (std.mem.eql(u8, opcode, "mul"))
            Inst{ .mul = pair }
        else if (std.mem.eql(u8, opcode, "div"))
            Inst{ .div = pair }
        else if (std.mem.eql(u8, opcode, "mod"))
            Inst{ .mod = pair }
        else if (std.mem.eql(u8, opcode, "eql"))
            Inst{ .eql = pair }
        else
            unreachable;
    }
};

fn parseInstructions(alloc: Allocator, inp: []const u8) ![]const Inst {
    var list = ArrayList(Inst).init(alloc);

    var lines = helper.getlines(inp);
    while (lines.next()) |line| try list.append(try Inst.parse(line));

    return list.toOwnedSlice();
}

const ExprPair = struct { a: *const Expr, b: *const Expr };

const ExprKind = enum { value, variable, add, mul, div, mod, eql };
const Expr = union(ExprKind) {
    value: i64,
    variable: u8, // variable index
    add: ExprPair,
    mul: ExprPair,
    div: ExprPair,
    mod: ExprPair,
    eql: ExprPair,

    const Self = @This();

    pub fn equals(self: *const Self, other: *const Self) bool {
        const kind1: ExprKind = self.*;
        const kind2: ExprKind = other.*;

        if (kind1 != kind2) return false;
        return switch (self.*) {
            .value => |val| val == other.value,
            .variable => |val| val == other.variable,
            .add => |pair| return pair.a.equals(other.add.a) and pair.b.equals(other.add.b) or pair.a.equals(other.add.b) and pair.b.equals(other.add.a),
            .mul => |pair| return pair.a.equals(other.mul.a) and pair.b.equals(other.mul.b) or pair.a.equals(other.mul.b) and pair.b.equals(other.mul.a),
            .div => |pair| return pair.a.equals(other.div.a) and pair.b.equals(other.div.b),
            .mod => |pair| return pair.a.equals(other.mod.a) and pair.b.equals(other.mod.b),
            .eql => |pair| return pair.a.equals(other.eql.a) and pair.b.equals(other.eql.b) or pair.a.equals(other.eql.b) and pair.b.equals(other.eql.a),
        };
    }

    pub fn print(self: *const Self, stdout: anytype) @TypeOf(stdout).Error!void {
        switch (self.*) {
            .value => |num| try stdout.print("{}", .{num}),
            .variable => |num| try stdout.print("x{}", .{num}),
            .add => |pair| try printPair(pair, stdout, '+'),
            .mul => |pair| try printPair(pair, stdout, '*'),
            .div => |pair| try printPair(pair, stdout, '/'),
            .mod => |pair| try printPair(pair, stdout, '%'),
            .eql => |pair| try printPair(pair, stdout, '='),
        }
    }

    pub fn printPair(pair: ExprPair, stdout: anytype, op: u8) !void {
        if (op != '*') try stdout.print("(", .{});
        try pair.a.print(stdout);
        try stdout.print(" {c} ", .{op});
        try pair.b.print(stdout);
        if (op != '*') try stdout.print(")", .{});
    }
};

const MinMax = struct { min: i64, max: i64 };
const MinMaxManager = struct {
    memo: HashMap(*const Expr, MinMax),

    const Self = @This();

    pub fn init(alloc: Allocator) Self {
        return .{ .memo = HashMap(*const Expr, MinMax).init(alloc) };
    }

    pub fn deinit(self: *Self) void {
        self.memo.deinit();
    }

    pub fn get(self: *Self, expr: *const Expr) MinMax {
        if (self.memo.get(expr)) |minmax| return minmax;

        var minmax: MinMax = undefined;

        switch (expr.*) {
            .value => |num| {
                minmax.min = num;
                minmax.max = num;
            },
            .variable => {
                minmax.min = 1;
                minmax.max = 9;
            },
            .add => |pair| {
                const minmax1 = self.get(pair.a);
                const minmax2 = self.get(pair.b);

                minmax.min = minmax1.min + minmax2.min;
                minmax.max = minmax1.max + minmax2.max;
            },
            .mul => |pair| {
                minmax = self.naiveMinMax(pair, mulop);
            },
            .div => |pair| {
                minmax = self.naiveMinMax(pair, divop);
            },
            .mod => |pair| {
                const bminmax = self.get(pair.b);
                minmax = .{ .min = 0, .max = bminmax.max - 1 };
            },
            .eql => {
                minmax.min = 0;
                minmax.max = 1;
            },
        }

        self.memo.put(expr, minmax) catch unreachable;
        return minmax;
    }

    fn naiveMinMax(self: *Self, pair: ExprPair, op: fn (i64, i64) i64) MinMax {
        const minmax1 = self.get(pair.a);
        const minmax2 = self.get(pair.b);
        const val1 = op(minmax1.min, minmax2.min);
        const val2 = op(minmax1.min, minmax2.max);
        const val3 = op(minmax1.max, minmax2.min);
        const val4 = op(minmax1.max, minmax2.max);

        const min = std.math.min(std.math.min3(val1, val2, val3), val4);
        const max = std.math.max(std.math.max3(val1, val2, val3), val4);
        return MinMax{ .min = min, .max = max };
    }
};

fn mulop(x: i64, y: i64) i64 {
    return x * y;
}

fn divop(x: i64, y: i64) i64 {
    return @divTrunc(x, y);
}

const ConstEval = struct {
    regs: [4]*const Expr,
    var_counter: u8 = 1,
    arena: std.heap.ArenaAllocator,
    minmax: MinMaxManager,

    const Self = @This();

    pub fn init(alloc: Allocator) Self {
        var arena = std.heap.ArenaAllocator.init(alloc);

        var self = Self{
            .regs = undefined,
            .arena = arena,
            .minmax = MinMaxManager.init(alloc),
        };

        self.initRegs();
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.arena.deinit();
        self.minmax.deinit();
    }

    pub fn evalMany(self: *Self, insts: []const Inst) void {
        for (insts) |inst| self.eval(inst);
    }

    pub fn eval(self: *Self, inst: Inst) void {
        switch (inst) {
            .inp => |reg| self.evalInp(reg),
            .add => |regpair| self.evalOp(regpair, add),
            .mul => |regpair| self.evalOp(regpair, mul),
            .div => |regpair| self.evalOp(regpair, div),
            .mod => |regpair| self.evalOp(regpair, mod),
            .eql => |regpair| self.evalOp(regpair, eql),
        }
    }

    fn aexpr(self: *Self, expr: Expr) *Expr {
        const alloc = self.arena.allocator();
        const ptr = alloc.create(Expr) catch unreachable;
        ptr.* = expr;
        return ptr;
    }

    fn initRegs(self: *Self) void {
        for (self.regs) |*reg| {
            reg.* = self.aexpr(.{ .value = 0 });
        }
    }

    fn evalInp(self: *Self, reg: Reg) void {
        self.set(reg, self.aexpr(.{ .variable = self.var_counter }));
        self.var_counter += 1;
    }

    fn evalOp(self: *Self, regpair: RegPair, comptime op: fn (*Self, *const Expr, *const Expr) Expr) void {
        const reg1 = regpair.a;
        const expr1 = self.get(reg1);

        const expr2 = switch (regpair.b) {
            .reg => |reg2| self.get(reg2),
            .num => |num| self.aexpr(.{ .value = num }),
        };

        const expr = self.aexpr(op(self, expr1, expr2));
        const minmax = self.minmax.get(expr);

        if (minmax.min == minmax.max) {
            self.set(reg1, self.aexpr(.{ .value = minmax.min }));
        } else {
            self.set(reg1, expr);
        }
    }

    fn add(self: *Self, expr1: *const Expr, expr2: *const Expr) Expr {
        const kind1: ExprKind = expr1.*;
        const kind2: ExprKind = expr2.*;

        if (kind2 == .value and expr2.value == 0) {
            return expr1.*;
        } else if (kind1 == .value and expr1.value == 0) {
            return expr2.*;
        } else if (kind1 == .value and kind2 == .value) {
            return .{ .value = expr1.value + expr2.value };
        } else if (isNiceAdd(expr1) and kind2 == .value) {
            return .{ .add = .{ .a = expr1.add.a, .b = self.aexpr(self.add(expr1.add.b, expr2)) } };
        } else if (isNiceAdd(expr2) and kind1 == .value) {
            return self.add(expr2, expr1); // previous case
        } else if (isNiceAdd(expr1) and isNiceAdd(expr2)) {
            const add_first = self.aexpr(.{ .add = .{ .a = expr1.add.a, .b = expr2.add.a } });
            return .{ .add = .{ .a = add_first, .b = self.aexpr(self.add(expr1.add.b, expr2.add.b)) } };
        } else if (isNiceAdd(expr1)) {
            const add_first = self.aexpr(.{ .add = .{ .a = expr1.add.a, .b = expr2 } });
            return .{ .add = .{ .a = add_first, .b = self.aexpr(.{ .value = expr1.add.b.value }) } };
        } else if (isNiceAdd(expr2)) {
            const add_first = self.aexpr(.{ .add = .{ .a = expr2.add.a, .b = expr1 } });
            return .{ .add = .{ .a = add_first, .b = self.aexpr(.{ .value = expr2.add.b.value }) } };
        } else if (kind1 == .value) {
            return .{ .add = .{ .a = expr2, .b = expr1 } };
        } else {
            return .{ .add = .{ .a = expr1, .b = expr2 } };
        }
    }

    fn mul(self: *Self, expr1: *const Expr, expr2: *const Expr) Expr {
        const kind1: ExprKind = expr1.*;
        const kind2: ExprKind = expr2.*;

        if (kind2 == .value and expr2.value == 0) {
            return expr2.*; // 0
        } else if (kind1 == .value and expr1.value == 0) {
            return expr1.*; // 0
        } else if (kind2 == .value and expr2.value == 1) {
            return expr1.*; // do nothing
        } else if (kind1 == .value and expr1.value == 1) {
            return expr2.*; // do nothing
        } else if (kind1 == .value and kind2 == .value) {
            return .{ .value = expr1.value * expr2.value };
        } else if (isNiceMul(expr1) and kind2 == .value) {
            return .{ .mul = .{ .a = expr1.mul.a, .b = self.aexpr(self.mul(expr1.mul.b, expr2)) } };
        } else if (isNiceMul(expr2) and kind1 == .value) {
            return self.mul(expr2, expr1); // previous case
        } else if (isNiceMul(expr1) and isNiceMul(expr2)) {
            const mul_first = self.aexpr(.{ .mul = .{ .a = expr1.mul.a, .b = expr2.mul.a } });
            return .{ .add = .{ .a = mul_first, .b = self.aexpr(self.mul(expr1.mul.b, expr2.mul.b)) } };
        } else if (kind1 == .add) {
            return self.add(self.aexpr(self.mul(expr1.add.a, expr2)), self.aexpr(self.mul(expr1.add.b, expr2)));
        } else if (kind2 == .add) {
            return self.mul(expr2, expr1); // previous case
        } else if (kind1 == .value) {
            return .{ .mul = .{ .a = expr2, .b = expr1 } };
        } else {
            return .{ .mul = .{ .a = expr1, .b = expr2 } };
        }
    }

    fn div(self: *Self, expr1: *const Expr, expr2: *const Expr) Expr {
        const kind1: ExprKind = expr1.*;
        const kind2: ExprKind = expr2.*;

        if (kind2 == .value and (expr2.value == 0 or expr2.value == 1)) {
            return expr1.*;
        } else if (kind1 == .value and kind2 == .value) {
            return Expr{ .value = @divTrunc(expr1.value, expr2.value) };
        } else if (isNiceMul(expr1) and kind2 == .value) {
            const abs2 = std.math.absInt(expr2.value) catch unreachable;
            const coeff = expr1.mul.b.value;
            if (@mod(coeff, abs2) == 0) {
                return .{ .mul = .{ .a = expr1.mul.a, .b = self.aexpr(.{ .value = @divExact(coeff, expr2.value) }) } };
            }
        }

        return .{ .div = .{ .a = expr1, .b = expr2 } };
    }

    fn mod(self: *Self, expr1: *const Expr, expr2: *const Expr) Expr {
        const kind1: ExprKind = expr1.*;
        const kind2: ExprKind = expr2.*;

        if (kind2 == .value and expr2.value <= 0) {
            return expr1.*;
        } else if (kind1 == .value and expr1.value < 0) {
            return expr1.*;
        } else if (kind1 == .value and kind2 == .value) {
            return Expr{ .value = @mod(expr1.value, expr2.value) };
        } else if (isNiceMul(expr1) and kind2 == .value) {
            if (expr1.mul.b.value > 0) {
                const mul_first = self.aexpr(self.mod(expr1.mul.a, expr2));
                return self.mul(mul_first, expr1.mul.b);
            }
        }

        return .{ .mod = .{ .a = expr1, .b = expr2 } };
    }

    fn eql(self: *Self, expr1: *const Expr, expr2: *const Expr) Expr {
        _ = self;
        const kind1: ExprKind = expr1.*;
        const kind2: ExprKind = expr2.*;

        if (kind1 == .value and kind2 == .value) {
            return Expr{ .value = @boolToInt(expr1.value == expr2.value) };
        } else if (expr1.equals(expr2)) {
            return Expr{ .value = 1 };
        }

        const minmax1 = self.minmax.get(expr1);
        const minmax2 = self.minmax.get(expr2);

        if (minmax1.max < minmax2.min or minmax2.max < minmax1.min) {
            return Expr{ .value = 0 };
        }

        return Expr{ .eql = .{ .a = expr1, .b = expr2 } };
    }

    fn isNiceAdd(expr: *const Expr) bool {
        return expr.* == .add and expr.add.b.* == .value;
    }

    fn isNiceMul(expr: *const Expr) bool {
        return expr.* == .mul and expr.mul.b.* == .value;
    }

    pub fn get(self: Self, reg: Reg) *const Expr {
        return self.regs[@enumToInt(reg)];
    }

    pub fn set(self: *Self, reg: Reg, expr: *const Expr) void {
        self.regs[@enumToInt(reg)] = expr;
    }
};

const tokenize = std.mem.tokenize;
const split = std.mem.split;
const count = std.mem.count;
const parseUnsigned = std.fmt.parseUnsigned;
const parseInt = std.fmt.parseInt;
const sort = std.sort.sort;
