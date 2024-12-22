const std = @import("std");
const Allocator = std.mem.Allocator;

const assert = std.debug.assert;
const print = std.debug.print;
const parseInt = std.fmt.parseInt;
const isDigit = std.ascii.isDigit;

fn part1(alloc: Allocator, input: []const u8) !i64 {
    _ = alloc;

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

fn calcSecrets(alloc: Allocator, init: i64) !std.ArrayList(i8) {
    var out = std.ArrayList(i8).init(alloc);
    var secret: i64 = init;
    for (0..2000) |_| {
        secret ^= secret << 6;
        secret = @mod(secret, 16777216);
        secret ^= secret >> 5;
        secret = @mod(secret, 16777216);
        secret ^= secret << 11;
        secret = @mod(secret, 16777216);
        try out.append(@intCast(@mod(secret, 10)));
    }
    return out;
}

fn part2(alloc: Allocator, input: []const u8) !i64 {
    var all_secrets = std.ArrayList(std.ArrayList(i8)).init(alloc);
    try all_secrets.ensureTotalCapacity(2000);
    var all_diffs = std.ArrayList(std.ArrayList(@Vector(4, i8))).init(alloc);
    try all_diffs.ensureTotalCapacity(2000);
    var all_price = std.ArrayList(std.ArrayList(i8)).init(alloc);
    try all_price.ensureTotalCapacity(2000);

    var line_it = std.mem.tokenizeScalar(u8, input, '\n');
    while (line_it.next()) |line| {
        try all_secrets.append(try calcSecrets(alloc, try parseInt(i64, line, 10)));
    }

    for (all_secrets.items) |secrets| {
        var diffs = std.ArrayList(@Vector(4, i8)).init(alloc);
        try diffs.ensureTotalCapacity(secrets.items.len);
        var price = std.ArrayList(i8).init(alloc);
        try price.ensureTotalCapacity(secrets.items.len);

        for (4..secrets.items.len) |i| {
            try diffs.append(.{
                @intCast(secrets.items[i - 4] - secrets.items[i - 3]),
                @intCast(secrets.items[i - 3] - secrets.items[i - 2]),
                @intCast(secrets.items[i - 2] - secrets.items[i - 1]),
                @intCast(secrets.items[i - 1] - secrets.items[i]),
            });

            try price.append(@intCast(secrets.items[i]));
        }
        try all_diffs.append(diffs);
        try all_price.append(price);
    }

    const val = [_]i8{ -9, -8, -7, -6, -5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 };

    var tries = std.ArrayList(@Vector(4, i8)).init(alloc);
    for (val) |i| {
        for (val) |j| {
            for (val) |k| {
                for (val) |l| {
                    try tries.append(.{ i, j, k, l });
                }
            }
        }
    }

    var best: i64 = 0;
    for (0.., tries.items) |ti, t| {
        if (ti % 100 == 0) {
            print("{d} / {d}\n", .{ ti + 1, tries.items.len });
        }
        var score: i64 = 0;
        for (0..all_diffs.items.len) |i| {
            for (0..all_diffs.items[0].items.len) |j| {
                if (@reduce(.And, all_diffs.items[i].items[j] == t)) {
                    score += all_price.items[i].items[j];
                    break;
                }
            }
        }
        best = @max(best, score);
    }

    return best;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const input = @embedFile("input/day22.txt");

    const ans1 = try part1(arena.allocator(), input);
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

    try expectEqual(37327623, try part1(test_alloc, input));
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
