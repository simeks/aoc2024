const std = @import("std");
const Allocator = std.mem.Allocator;

const assert = std.debug.assert;
const print = std.debug.print;
const parseInt = std.fmt.parseInt;
const isDigit = std.ascii.isDigit;

/// Cache number of stones at max depth
/// Maps (number, depth) -> number of stones
const NumberCache = std.AutoArrayHashMap(struct { u32, Number }, usize);

pub fn recursionCount(
    max_depth: u32,
    depth: u32,
    number: Number,
    cache: *NumberCache,
) usize {
    if (depth == max_depth) {
        return 1;
    }

    if (cache.get(.{ depth, number })) |count| {
        return count;
    }

    const count = blk: {
        if (number == 0) {
            break :blk recursionCount(max_depth, depth + 1, 1, cache);
        }

        const p = std.math.log10_int(number) + 1;
        if (p % 2 == 0) {
            // Split numbers (1234 -> 12, 34)
            const base = std.math.pow(Number, 10, @divFloor(p, 2));
            const a = @divFloor(number, base);
            const b = number % base;
            break :blk recursionCount(max_depth, depth + 1, a, cache) +
                recursionCount(max_depth, depth + 1, b, cache);
        }

        break :blk recursionCount(max_depth, depth + 1, 2024 * number, cache);
    };

    cache.put(.{ depth, number }, count) catch @panic("OOM");

    return count;
}

pub fn stoneCount(alloc: Allocator, max_depth: u32, numbers: NumberList) !usize {
    var cache = NumberCache.init(alloc);
    defer cache.deinit();

    // Preallocate some room
    try cache.ensureTotalCapacity(200000);

    var count: usize = 0;
    for (numbers.items) |n| {
        count += recursionCount(max_depth, 0, n, &cache);
    }

    return count;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const input = @embedFile("input/day11.txt");
    const numbers = try parseNumbers(arena.allocator(), input);
    defer numbers.deinit();

    const ans1 = try stoneCount(arena.allocator(), 25, numbers);
    print("Part 1: {d}\n", .{ans1});

    const ans2 = try stoneCount(arena.allocator(), 75, numbers);
    print("Part 2: {d}\n", .{ans2});
}

const Number = usize;
const NumberList = std.ArrayList(Number);

fn parseNumbers(alloc: Allocator, input: []const u8) !NumberList {
    var out = NumberList.init(alloc);
    var t = std.mem.tokenizeAny(u8, input, "\n ");
    while (t.next()) |n| {
        try out.append(try parseInt(Number, n, 10));
    }
    return out;
}

const test_alloc = std.testing.allocator;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;
const expectEqualSlices = std.testing.expectEqualSlices;
const expectError = std.testing.expectError;

test "part1" {
    const input = "125 17";
    const numbers = try parseNumbers(test_alloc, input);
    defer numbers.deinit();

    try expectEqual(55312, try stoneCount(test_alloc, 25, numbers));
}
