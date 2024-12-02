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
    assert(values.len >= 4);
    assert(values.len < MAX_REPORT_VALUE_COUNT);

    // Determine sign by majority voting
    // We know only 1 value is allowed to have a different sign
    const sign0 = (values[1] - values[0]) >= 0;
    const sign1 = (values[2] - values[1]) >= 0;
    const sign2 = (values[3] - values[2]) >= 0;
    const sign = (sign0 and sign1) or (sign1 and sign2) or (sign0 and sign2);

    // Number of failed checks
    var fails: i32 = 0;

    var i: usize = 0;
    while (i < values.len - 1) : (i += 1) {
        // Forward difference
        const d0 = values[i + 1] - values[i];
        // Check diff to closest neighbour
        if ((d0 >= 0) == sign and 0 < @abs(d0) and @abs(d0) <= 3) {
            continue;
        }

        if (fails > 0) {
            return false;
        }

        fails += 1;

        // Didn't work, attempt to delete value[i+1]
        if (i + 2 == values.len) {
            // No diff to re-evalute if last value goes
            continue;
        }

        const d1 = values[i + 2] - values[i];
        if ((d1 >= 0) == sign and 0 < @abs(d1) and @abs(d1) <= 3) {
            i += 1; // we just deleted i+1, so skip it
            continue;
        }

        // Attempt to delete value[i]
        if (i == 0) {
            // No diff to re-evalute if first value goes
            continue;
        }

        const d2 = values[i + 1] - values[i - 1];
        if ((d2 >= 0) == sign and 0 < @abs(d2) and @abs(d2) <= 3) {
            continue;
        }

        return false;
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
    print("Safe reports: {d}\n", .{count});
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
    try expectEqual(true, checkSafe(&.{ 1, 3, 2, 4, 5 }));
    try expectEqual(true, checkSafe(&.{ 8, 6, 4, 4, 1 }));
    try expectEqual(true, checkSafe(&.{ 1, 3, 6, 7, 9 }));
    try expectEqual(true, checkSafe(&.{ 1, 3, 6, 7, 9, 10 }));
    try expectEqual(true, checkSafe(&.{ 1, 3, 6, 7, 9, 1 }));
    try expectEqual(false, checkSafe(&.{ 10, 3, 6, 7, 9, 1 }));
    try expectEqual(true, checkSafe(&.{ 24, 21, 18, 15, 13, 8 }));
    try expectEqual(true, checkSafe(&.{ 86, 82, 85, 84, 81, 78 }));
}
test "countSafe" {
    const input =
        \\7 6 4 2 1
        \\1 2 7 8 9
        \\9 7 6 2 1
        \\1 3 2 4 5
        \\8 6 4 4 1
        \\1 3 6 7 9
    ;
    try expectEqual(4, countSafe(input));
}
