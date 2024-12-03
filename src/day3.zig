const std = @import("std");
const Allocator = std.mem.Allocator;

const assert = std.debug.assert;
const print = std.debug.print;
const parseInt = std.fmt.parseInt;
const isDigit = std.ascii.isDigit;

pub fn runString(str: []const u8) i32 {
    var sum: i32 = 0;
    var i: usize = 0;

    var state: enum {
        op,
        a,
        comma,
        b,
        end,
    } = .op;

    var a: i32 = undefined;
    var b: i32 = undefined;

    while (i < str.len) {
        switch (state) {
            .op => {
                if (i + 3 >= str.len) {
                    break;
                }
                if (std.mem.eql(u8, str[i .. i + 4], "mul(")) {
                    i += 4;
                    state = .a;
                    continue;
                }
            },
            .a => {
                var end = i;
                while (isDigit(str[end])) : (end += 1) {}
                if (end == i) {
                    state = .op;
                    continue;
                } else {
                    a = parseInt(i32, str[i..end], 10) catch @panic("nope");
                    state = .comma;
                    i = end;
                    continue;
                }
            },
            .comma => {
                if (str[i] == ',') {
                    state = .b;
                } else {
                    state = .op;
                }
            },
            .b => {
                var end = i;
                while (isDigit(str[end])) : (end += 1) {}
                if (end == i) {
                    state = .op;
                } else {
                    b = parseInt(i32, str[i..end], 10) catch @panic("nope");
                    state = .end;
                    i = end;
                    continue;
                }
            },
            .end => {
                if (str[i] == ')') {
                    sum += a * b;
                }
                state = .op;
            },
        }
        i += 1;
    }
    return sum;
}

pub fn main() !void {
    const input = @embedFile("input/day3.txt");
    const res = runString(input);
    print("Result: {d}\n", .{res});
}

const test_alloc = std.testing.allocator;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectError = std.testing.expectError;

test "runString" {
    const input = "xmul(2,4)%&mul[3,7]!@^do_not_mul(5,5)+mul(32,64]then(mul(11,8)mul(8,5))";
    try expectEqual(161, runString(input));
}
