const std = @import("std");
const Allocator = std.mem.Allocator;

const assert = std.debug.assert;
const print = std.debug.print;
const parseInt = std.fmt.parseInt;
const isDigit = std.ascii.isDigit;

const IntList = std.ArrayList(i32);
const RuleList = std.ArrayList(struct { i32, i32 });

/// Part 1
fn isCorrect(rules: RuleList, numbers: []const i32) bool {
    for (rules.items) |rule| {
        const n1, const n2 = rule;
        if (std.mem.indexOfScalar(i32, numbers, n1)) |i| {
            if (std.mem.indexOfScalar(i32, numbers, n2)) |j| {
                if (i > j) {
                    return false;
                }
            }
        }
    }
    return true;
}

/// Part 2
/// In-place reordering of `numbers`
fn fixOrder(rules: RuleList, numbers: []i32) void {
    while (!isCorrect(rules, numbers)) {
        for (rules.items) |rule| {
            const n1, const n2 = rule;
            if (std.mem.indexOfScalar(i32, numbers, n1)) |i| {
                if (std.mem.indexOfScalar(i32, numbers, n2)) |j| {
                    if (i > j) {
                        const x = numbers[i];
                        const y = numbers[j];
                        numbers[i] = y;
                        numbers[j] = x;
                    }
                }
            }
        }
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    const input = @embedFile("input/day5.txt");

    var parts_it = std.mem.tokenizeSequence(u8, input, "\n\n");
    const rules = try parseRules(alloc, parts_it.next() orelse @panic("Invalid input"));
    defer rules.deinit();

    var update_it = std.mem.tokenizeScalar(
        u8,
        parts_it.next() orelse @panic("Invalid input"),
        '\n',
    );

    var sum: i32 = 0;
    var sum_fixed: i32 = 0;
    while (update_it.next()) |update| {
        const numbers = try parseIntList(alloc, update);
        defer numbers.deinit();

        if (isCorrect(rules, numbers.items)) {
            const mid = numbers.items[@divFloor(numbers.items.len, 2)];
            sum += mid;
        } else {
            fixOrder(rules, numbers.items);
            const mid = numbers.items[@divFloor(numbers.items.len, 2)];
            sum_fixed += mid;
        }
    }
    print("Sum: {d}\n", .{sum});
    print("Sum (fixed): {d}\n", .{sum_fixed});
}

fn parseRules(allocator: Allocator, rules_input: []const u8) !RuleList {
    var rules = RuleList.init(allocator);
    errdefer rules.deinit();

    var it = std.mem.tokenizeScalar(u8, rules_input, '\n');
    while (it.next()) |line| {
        var line_it = std.mem.tokenizeScalar(u8, line, '|');

        const l = line_it.next() orelse return error.UnexpectedInput;
        const r = line_it.next() orelse return error.UnexpectedInput;

        const n1 = try std.fmt.parseInt(i32, l, 10);
        const n2 = try std.fmt.parseInt(i32, r, 10);

        try rules.append(.{ n1, n2 });
    }
    return rules;
}
fn parseIntList(allocator: Allocator, input: []const u8) !IntList {
    var out = IntList.init(allocator);
    var it = std.mem.tokenizeScalar(u8, input, ',');
    while (it.next()) |t| {
        try out.append(try std.fmt.parseInt(i32, t, 10));
    }
    return out;
}

const test_alloc = std.testing.allocator;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;
const expectEqualSlices = std.testing.expectEqualSlices;
const expectError = std.testing.expectError;

test "parseRules" {
    const input =
        \\47|53
        \\97|13
        \\97|61
        \\97|47
    ;
    const rules = try parseRules(test_alloc, input);
    defer rules.deinit();

    try expectEqual(4, rules.items.len);
}
test "parseIntList" {
    const lst = try parseIntList(test_alloc, "75,47,61,53,29");
    defer lst.deinit();

    try expectEqualSlices(i32, &.{ 75, 47, 61, 53, 29 }, lst.items);
}
test "isCorrect" {
    const input =
        \\47|53
        \\97|13
        \\97|61
        \\97|47
        \\75|29
        \\61|13
        \\75|53
        \\29|13
        \\97|29
        \\53|29
        \\61|53
        \\97|53
        \\61|29
        \\47|13
        \\75|47
        \\97|75
        \\47|61
        \\75|61
        \\47|29
        \\75|13
        \\53|13
        \\10|20
        \\20|10
    ;

    const rules = try parseRules(test_alloc, input);
    defer rules.deinit();

    try expect(isCorrect(rules, &.{ 75, 47, 61, 53, 29 }));
    try expect(isCorrect(rules, &.{ 97, 61, 53, 29, 13 }));
    try expect(isCorrect(rules, &.{ 75, 29, 13 }));
    try expect(!isCorrect(rules, &.{ 75, 97, 47, 61, 53 }));
    try expect(!isCorrect(rules, &.{ 61, 13, 29 }));
    try expect(!isCorrect(rules, &.{ 97, 13, 75, 29, 47 }));
}
test "fixOrder" {
    const input =
        \\47|53
        \\97|13
        \\97|61
        \\97|47
        \\75|29
        \\61|13
        \\75|53
        \\29|13
        \\97|29
        \\53|29
        \\61|53
        \\97|53
        \\61|29
        \\47|13
        \\75|47
        \\97|75
        \\47|61
        \\75|61
        \\47|29
        \\75|13
        \\53|13
        \\10|20
        \\20|10
    ;

    const rules = try parseRules(test_alloc, input);
    defer rules.deinit();

    var a = [_]i32{ 75, 97, 47, 61, 53 };
    fixOrder(rules, &a);
    try expectEqualSlices(i32, &.{ 97, 75, 47, 61, 53 }, &a);

    var b = [_]i32{ 61, 13, 29 };
    fixOrder(rules, &b);
    try expectEqualSlices(i32, &.{ 61, 29, 13 }, &b);

    var c = [_]i32{ 97, 13, 75, 29, 47 };
    fixOrder(rules, &c);
    try expectEqualSlices(i32, &.{ 97, 75, 47, 29, 13 }, &c);
}
