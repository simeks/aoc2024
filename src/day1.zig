const std = @import("std");
const Allocator = std.mem.Allocator;

const assert = std.debug.assert;
const print = std.debug.print;

const IntList = std.ArrayList(i32);

pub fn readLists(
    allocator: Allocator,
    input: []const u8,
) !struct { IntList, IntList } {
    var left = IntList.init(allocator);
    var right = IntList.init(allocator);

    var it = std.mem.tokenizeScalar(u8, input, '\n');
    while (it.next()) |line| {
        var line_it = std.mem.tokenizeScalar(u8, line, ' ');

        const l = line_it.next() orelse return error.UnexpectedInput;
        const r = line_it.next() orelse return error.UnexpectedInput;

        try left.append(try std.fmt.parseInt(i32, l, 10));
        try right.append(try std.fmt.parseInt(i32, r, 10));
    }

    return .{ left, right };
}

pub fn sortList(list: *IntList) void {
    std.mem.sort(i32, list.items, {}, std.sort.asc(i32));
}

pub fn totalDistance(allocator: Allocator, input: []const u8) !i32 {
    var left, var right = try readLists(allocator, input);
    defer left.deinit();
    defer right.deinit();

    sortList(&left);
    sortList(&right);

    var sum: i32 = 0;
    for (0..left.items.len) |i| {
        sum += @intCast(@abs(left.items[i] - right.items[i]));
    }
    return sum;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    const input = @embedFile("input/day1.txt");
    const sum = try totalDistance(alloc, input);
    print("Sum: {d}\n", .{sum});
}

const test_alloc = std.testing.allocator;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "readLists" {
    const input =
        \\3   4
        \\4   3
        \\2   5
        \\1   3
        \\3   9
        \\3   3
    ;

    const left, const right = try readLists(test_alloc, input);
    defer left.deinit();
    defer right.deinit();

    try expectEqual(6, left.items.len);
    try expectEqual(6, right.items.len);

    try expectEqual(3, left.items[0]);
    try expectEqual(4, left.items[1]);
    try expectEqual(2, left.items[2]);
    try expectEqual(1, left.items[3]);
    try expectEqual(3, left.items[4]);
    try expectEqual(3, left.items[5]);

    try expectEqual(4, right.items[0]);
    try expectEqual(3, right.items[1]);
    try expectEqual(5, right.items[2]);
    try expectEqual(3, right.items[3]);
    try expectEqual(9, right.items[4]);
    try expectEqual(3, right.items[5]);
}
test "sortList" {
    var list = try IntList.initCapacity(test_alloc, 6);
    defer list.deinit();
    try list.append(3);
    try list.append(4);
    try list.append(2);
    try list.append(1);
    try list.append(3);
    try list.append(3);

    sortList(&list);

    try expectEqual(1, list.items[0]);
    try expectEqual(2, list.items[1]);
    try expectEqual(3, list.items[2]);
    try expectEqual(3, list.items[3]);
    try expectEqual(3, list.items[4]);
    try expectEqual(4, list.items[5]);
}
test "totalDistance" {
    const input =
        \\3   4
        \\4   3
        \\2   5
        \\1   3
        \\3   9
        \\3   3
    ;

    const sum = try totalDistance(test_alloc, input);
    try expectEqual(11, sum);
}
