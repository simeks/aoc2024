const std = @import("std");
const Allocator = std.mem.Allocator;

const assert = std.debug.assert;
const print = std.debug.print;

const MAX_REPORT_VALUE_COUNT = 10;

const Report = std.BoundedArray(i32, MAX_REPORT_VALUE_COUNT);

pub fn readReport(line: []const u8) !Report {
    var line_it = std.mem.tokenizeScalar(u8, line, ' ');

    var report: Report = .{};
    while (line_it.next()) |t| {
        const val = std.fmt.parseInt(i32, t, 10) catch {
            return error.UnexpectedInput;
        };
        try report.append(val);
    }
    return report;
}
pub fn checkSafe(values: []const i32) bool {
    assert(values.len > 1);
    assert(values.len < MAX_REPORT_VALUE_COUNT);

    var diffs = std.BoundedArray(i32, MAX_REPORT_VALUE_COUNT - 1){};
    for (0..values.len - 1) |i| {
        diffs.append(values[i + 1] - values[i]) catch unreachable;
    }

    const incr = diffs.get(0) > 0;
    for (diffs.slice()) |d| {
        // All increasing or decreasing
        if (incr != (d > 0)) {
            return false;
        }
        // Outside limits
        if (@abs(d) <= 0 or @abs(d) > 3) {
            return false;
        }
    }

    return true;
}
pub fn countSafe(input: []const u8) !i32 {
    var count: i32 = 0;
    var it = std.mem.tokenizeScalar(u8, input, '\n');
    while (it.next()) |line| {
        const report = try readReport(line);
        if (checkSafe(report.slice())) {
            count += 1;
        }
    }
    return count;
}

pub fn main() !void {
    const input = @embedFile("input/day2.txt");
    const count = try countSafe(input);
    print("Safe report: {d}\n", .{count});
}

const test_alloc = std.testing.allocator;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectError = std.testing.expectError;

test "readReport" {
    const report = try readReport("4 21  1   5 2");
    try expectEqual(5, report.len);
    try expectEqual(4, report.get(0));
    try expectEqual(21, report.get(1));
    try expectEqual(1, report.get(2));
    try expectEqual(5, report.get(3));
    try expectEqual(2, report.get(4));

    try expectError(error.UnexpectedInput, readReport("1 2 3 4 a"));
    try expectError(error.Overflow, readReport("1 2 3 4 5 6 7 8 9 10 11"));
}
test "checkSafe" {
    try expectEqual(true, checkSafe(&.{ 7, 6, 4, 2, 1 }));
    try expectEqual(false, checkSafe(&.{ 1, 2, 7, 8, 9 }));
    try expectEqual(false, checkSafe(&.{ 9, 7, 6, 2, 1 }));
    try expectEqual(false, checkSafe(&.{ 1, 3, 2, 4, 5 }));
    try expectEqual(false, checkSafe(&.{ 8, 6, 4, 4, 1 }));
    try expectEqual(true, checkSafe(&.{ 1, 3, 6, 7, 9 }));
    try expectEqual(true, checkSafe(&.{ 1, 3, 6, 7, 9, 10 }));
}
test "countSafe" {
    const input =
        \\7 6 4 2 1
        \\1 2 7 8 9
        \\9 7 6 2 1
        \\1 3 2 4 5
        \\8 6 4 4 1
        \\1 3 6 7 9
        \\1 3 6 7 9 10
    ;
    try expectEqual(3, countSafe(input));
}
