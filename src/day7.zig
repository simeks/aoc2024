const std = @import("std");
const Allocator = std.mem.Allocator;

const assert = std.debug.assert;
const print = std.debug.print;
const parseInt = std.fmt.parseInt;
const isDigit = std.ascii.isDigit;

fn isValid(sum: i64, numbers: []i64, hold: i64) bool {
    if (numbers.len == 1) {
        return hold + numbers[0] == sum or hold * numbers[0] == sum;
    }

    if (hold + numbers[0] <= sum and
        isValid(sum, numbers[1..], hold + numbers[0]))
    {
        return true;
    }
    if (hold * numbers[0] <= sum and
        isValid(sum, numbers[1..], hold * numbers[0]))
    {
        return true;
    }
    return false;
}

fn part1(alloc: Allocator, input: []const u8) !i64 {
    var res: i64 = 0;
    var it = std.mem.tokenizeScalar(u8, input, '\n');
    while (it.next()) |line| {
        const sum, const numbers = try parseLine(alloc, line);
        defer numbers.deinit();
        if (isValid(sum, numbers.items, 0)) {
            res += sum;
        }
    }
    return res;
}

/// Merges two numbers (12, 34) -> 1234
/// Assuming a and b is > 0
fn merge(a: i64, b: i64) i64 {
    const n: i64 = @intCast(std.math.log10(@as(u64, @intCast(b))));
    return a * std.math.pow(i64, 10, n + 1) + b;
}

fn isValid2(sum: i64, numbers: []const i64, hold: i64) bool {
    if (numbers.len == 1) {
        return (hold + numbers[0] == sum or
            hold * numbers[0] == sum or
            merge(hold, numbers[0]) == sum);
    }

    if (hold + numbers[0] <= sum and
        isValid2(sum, numbers[1..], hold + numbers[0]))
    {
        return true;
    }
    if (hold * numbers[0] <= sum and
        isValid2(sum, numbers[1..], hold * numbers[0]))
    {
        return true;
    }
    if (merge(hold, numbers[0]) <= sum and
        isValid2(sum, numbers[1..], merge(hold, numbers[0])))
    {
        return true;
    }
    return false;
}

fn part2(alloc: Allocator, input: []const u8) !i64 {
    var res: i64 = 0;
    var it = std.mem.tokenizeScalar(u8, input, '\n');
    while (it.next()) |line| {
        const sum, const numbers = try parseLine(alloc, line);
        defer numbers.deinit();
        if (isValid2(sum, numbers.items, 0)) {
            res += sum;
        }
    }
    return res;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());

    const input = @embedFile("input/day7.txt");

    const res1 = try part1(arena.allocator(), input);
    print("Part 1: {d}\n", .{res1});

    const res2 = try part2(arena.allocator(), input);
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
    try expectEqual(3749 + 292, try part1(test_alloc, input));
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
    try expectEqual(11387, try part2(test_alloc, input));
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
