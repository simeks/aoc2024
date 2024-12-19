const std = @import("std");
const Allocator = std.mem.Allocator;

const assert = std.debug.assert;
const print = std.debug.print;
const parseInt = std.fmt.parseInt;
const isDigit = std.ascii.isDigit;

const StringSet = std.StringArrayHashMap(void);
const CacheBool = std.StringArrayHashMap(bool);
const Cache = std.StringArrayHashMap(usize);

fn check1(input: *const Input, cache: *CacheBool, design: []const u8) bool {
    if (cache.get(design)) |b| {
        return b;
    }

    var valid = false;
    if (input.patterns.contains(design)) {
        valid = true;
    }

    if (!valid) {
        var p_it = input.patterns.iterator();
        while (p_it.next()) |entry| {
            const p = entry.key_ptr.*;
            if (std.mem.startsWith(u8, design, p)) {
                if (check1(input, cache, design[p.len..])) {
                    valid = true;
                    break;
                }
            }
        }
    }

    cache.put(design, valid) catch @panic("oom");
    return valid;
}

fn part1(alloc: Allocator, input: []const u8) !usize {
    var inp = try parseInput(alloc, input);
    defer inp.deinit();

    var cache = CacheBool.init(alloc);
    defer cache.deinit();

    var sum: usize = 0;
    for (inp.designs.items) |d| {
        if (check1(&inp, &cache, d)) {
            sum += 1;
        }
    }

    return sum;
}

fn check2(input: *const Input, cache: *Cache, design: []const u8) usize {
    if (cache.get(design)) |c| {
        return c;
    }

    var sum: usize = 0;
    if (design.len == 0) {
        sum = 1;
    }

    if (sum == 0) {
        var p_it = input.patterns.iterator();
        while (p_it.next()) |entry| {
            const p = entry.key_ptr.*;
            if (std.mem.startsWith(u8, design, p)) {
                sum += check2(input, cache, design[p.len..]);
            }
        }
    }

    cache.put(design, sum) catch @panic("oom");
    return sum;
}

fn part2(alloc: Allocator, input: []const u8) !usize {
    var inp = try parseInput(alloc, input);
    defer inp.deinit();

    var cache = Cache.init(alloc);
    defer cache.deinit();

    var sum: usize = 0;
    for (inp.designs.items) |d| {
        sum += check2(&inp, &cache, d);
    }

    return sum;
}

const Input = struct {
    patterns: StringSet,
    designs: std.ArrayList([]const u8),

    pub fn deinit(self: *Input) void {
        self.patterns.deinit();
        self.designs.deinit();
    }
};

/// Returned Input only valid as long as input is available
fn parseInput(alloc: Allocator, input: []const u8) !Input {
    var it = std.mem.tokenizeSequence(u8, input, "\n\n");

    var patterns = StringSet.init(alloc);
    errdefer patterns.deinit();

    var p_it = std.mem.tokenizeSequence(u8, it.next().?, ", ");
    while (p_it.next()) |p| {
        try patterns.put(p, {});
    }

    var designs = std.ArrayList([]const u8).init(alloc);
    errdefer designs.deinit();

    var d_it = std.mem.tokenizeScalar(u8, it.next().?, '\n');
    while (d_it.next()) |d| {
        try designs.append(d);
    }
    return .{
        .patterns = patterns,
        .designs = designs,
    };
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const input = @embedFile("input/day19.txt");

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
        \\r, wr, b, g, bwu, rb, gb, br
        \\
        \\brwrr
        \\bggr
        \\gbbr
        \\rrbgbr
        \\ubwu
        \\bwurrg
        \\brgr
        \\bbrgwb
    ;

    try expectEqual(6, try part1(test_alloc, input));
}
test "part2" {
    const input =
        \\r, wr, b, g, bwu, rb, gb, br
        \\
        \\brwrr
        \\bggr
        \\gbbr
        \\rrbgbr
        \\ubwu
        \\bwurrg
        \\brgr
        \\bbrgwb
    ;

    try expectEqual(16, try part2(test_alloc, input));
}
