const std = @import("std");
const Allocator = std.mem.Allocator;

const assert = std.debug.assert;
const print = std.debug.print;
const parseInt = std.fmt.parseInt;
const isDigit = std.ascii.isDigit;

const Op = enum {
    add,
    mul,
    cat,
};

const op_fn = std.enums.directEnumArray(Op, *const fn (i64, i64) i64, 0, .{
    .add = add,
    .mul = mul,
    .cat = cat,
});

fn add(a: i64, b: i64) i64 {
    return a + b;
}
fn mul(a: i64, b: i64) i64 {
    return a * b;
}
/// Concats two numbers (12, 34) -> 1234
/// Assuming a and b is > 0
fn cat(a: i64, b: i64) i64 {
    const n: i64 = @intCast(std.math.log10(@as(u64, @intCast(b))));
    return a * std.math.pow(i64, 10, n + 1) + b;
}

/// Recursively checks if `numbers` produces given `sum`
/// `hold` tracks current sum and should be 0 at start
/// `ops` specifies what operators to apply.
fn isValid(
    sum: i64,
    numbers: []i64,
    hold: i64,
    comptime ops: []const Op,
) bool {
    if (numbers.len == 1) {
        inline for (ops) |op| {
            const func = op_fn[@intFromEnum(op)];
            if (func(hold, numbers[0]) == sum) {
                return true;
            }
        }
        return false;
    }

    inline for (ops) |op| {
        const func = op_fn[@intFromEnum(op)];
        const val = func(hold, numbers[0]);
        if (val <= sum and isValid(sum, numbers[1..], val, ops)) {
            return true;
        }
    }
    return false;
}

/// Runs day 7 algo applying the operators provided in ops.
/// Part 1 expects 'add' and 'mul'
/// Part 2 expects 'add', 'mul', and 'cat'
fn run(alloc: Allocator, input: []const u8, comptime ops: []const Op) !i64 {
    var res: i64 = 0;
    var it = std.mem.tokenizeScalar(u8, input, '\n');
    while (it.next()) |line| {
        const sum, const numbers = try parseLine(alloc, line);
        defer numbers.deinit();

        if (isValid(sum, numbers.items, 0, ops)) {
            res += sum;
        }
    }
    return res;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());

    const input = @embedFile("input/day7.txt");

    const res1 = try run(arena.allocator(), input, &.{ .add, .mul });
    print("Part 1: {d}\n", .{res1});

    const res2 = try run(arena.allocator(), input, &.{ .add, .mul, .cat });
    print("Part 2: {d}\n", .{res2});
}

const NumberList = std.ArrayList(i64);

fn parseLine(alloc: Allocator, input: []const u8) !struct { i64, NumberList } {
    var it = std.mem.tokenizeScalar(u8, input, ':');
    const sum_txt = it.next() orelse return error.UnexpectedInput;
    const numbers_txt = it.next() orelse return error.UnexpectedInput;

    const sum = try parseInt(i64, sum_txt, 10);

    var numbers = NumberList.init(alloc);
    errdefer numbers.deinit();

    var numbers_it = std.mem.tokenizeScalar(u8, numbers_txt, ' ');
    while (numbers_it.next()) |number| {
        try numbers.append(try parseInt(i64, number, 10));
    }

    return .{ sum, numbers };
}

const test_alloc = std.testing.allocator;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;
const expectEqualSlices = std.testing.expectEqualSlices;
const expectError = std.testing.expectError;

test "part1" {
    const input =
        \\190: 10 19
        \\3267: 81 40 27
        \\83: 17 5
        \\156: 15 6
        \\7290: 6 8 6 15
        \\161011: 16 10 13
        \\192: 17 8 14
        \\21037: 9 7 18 13
        \\292: 11 6 16 20
        \\292: 29 10 2 1
    ;
    try expectEqual(3749 + 292, try run(test_alloc, input, &.{ .add, .mul }));
}
test "part2" {
    const input =
        \\190: 10 19
        \\3267: 81 40 27
        \\83: 17 5
        \\156: 15 6
        \\7290: 6 8 6 15
        \\161011: 16 10 13
        \\192: 17 8 14
        \\21037: 9 7 18 13
        \\292: 11 6 16 20
    ;
    try expectEqual(11387, try run(test_alloc, input, &.{ .add, .mul, .cat }));
}

test "parseLine" {
    const sum, const numbers = try parseLine(test_alloc, "500: 10 20 30 40");
    defer numbers.deinit();
    try expectEqual(500, sum);
    try expectEqual(4, numbers.items.len);
    try expectEqual(10, numbers.items[0]);
    try expectEqual(20, numbers.items[1]);
    try expectEqual(30, numbers.items[2]);
    try expectEqual(40, numbers.items[3]);
}
