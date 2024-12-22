const std = @import("std");
const Allocator = std.mem.Allocator;

const assert = std.debug.assert;
const print = std.debug.print;
const parseInt = std.fmt.parseInt;
const isDigit = std.ascii.isDigit;

fn Set(Type: type) type {
    return std.AutoArrayHashMap(Type, void);
}

fn part1(input: []const u8) !i64 {
    var sum: i64 = 0;
    var line_it = std.mem.tokenizeScalar(u8, input, '\n');
    while (line_it.next()) |line| {
        var secret = try parseInt(i64, line, 10);
        for (0..2000) |_| {
            secret ^= secret << 6;
            secret = @mod(secret, 16777216);
            secret ^= secret >> 5;
            secret = @mod(secret, 16777216);
            secret ^= secret << 11;
            secret = @mod(secret, 16777216);
        }
        sum += secret;
    }

    return sum;
}

fn part2(alloc: Allocator, input: []const u8) !i64 {
    const Diffs = @Vector(4, i8);

    var seen = Set(Diffs).init(alloc);
    defer seen.deinit();

    // Total number of bananas for the given diff sequence
    var bananas = std.AutoArrayHashMap(Diffs, i64).init(alloc);
    defer bananas.deinit();

    var line_it = std.mem.tokenizeScalar(u8, input, '\n');
    while (line_it.next()) |line| {
        seen.clearRetainingCapacity();

        var secret = try parseInt(i64, line, 10);

        var diff: Diffs = @splat(0);
        var prev: i8 = @intCast(@mod(secret, 10));

        for (0..2000) |i| {
            secret ^= secret << 6;
            secret = @mod(secret, 16777216);
            secret ^= secret >> 5;
            secret = @mod(secret, 16777216);
            secret ^= secret << 11;
            secret = @mod(secret, 16777216);

            const num: i8 = @intCast(@mod(secret, 10));
            if (i == 0) {
                prev = num;
                continue;
            }

            const d: i8 = prev - num;
            diff = @shuffle(i8, diff, undefined, @Vector(4, i32){ 1, 2, 3, 3 });
            diff[3] = d;
            prev = num;

            if (i > 3) {
                // Only the first instance of the diff sequence counts, so ignore
                // more than one.
                if (seen.contains(diff)) {
                    continue;
                }
                try seen.put(diff, {});

                (try bananas.getOrPutValue(diff, 0)).value_ptr.* += num;
            }
        }
    }

    // Pick the diff sequence with the most bananas
    var best: i64 = 0;
    var it = bananas.iterator();
    while (it.next()) |item| {
        best = @max(best, item.value_ptr.*);
    }

    return best;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const input = @embedFile("input/day22.txt");

    const ans1 = try part1(input);
    print("Part 1: {d}\n", .{ans1});

    const ans2 = try part2(arena.allocator(), input);
    print("Part 2: {d}\n", .{ans2});
}

const test_alloc = std.testing.allocator;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;
const expectEqualSlices = std.testing.expectEqualSlices;
const expectError = std.testing.expectError;

test "part1" {
    const input =
        \\1
        \\10
        \\100
        \\2024
    ;

    try expectEqual(37327623, try part1(input));
}
test "part2" {
    const input =
        \\1
        \\2
        \\3
        \\2024
    ;

    try expectEqual(23, try part2(test_alloc, input));
}
