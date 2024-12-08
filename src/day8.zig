const std = @import("std");
const Allocator = std.mem.Allocator;

const assert = std.debug.assert;
const print = std.debug.print;
const parseInt = std.fmt.parseInt;
const isDigit = std.ascii.isDigit;

fn Set(Type: type) type {
    return std.AutoArrayHashMap(Type, void);
}

const Vec2 = @Vector(2, i32);

/// Matrix backed by input data txt
const Mat = struct {
    width: usize,
    height: usize,
    data: []const u8,

    /// Keeps a refernce to given input slice
    pub fn init(input: []const u8) Mat {
        const width = std.mem.indexOfScalar(u8, input, '\n');
        assert(width != null);

        var height: usize = std.mem.count(u8, input, "\n");
        assert(height > 0);

        // If no trailing \n we need to add last row ourself
        if (input[input.len - 1] != '\n') {
            height += 1;
        }

        return .{
            .width = width.?,
            .height = height,
            .data = input,
        };
    }

    pub fn get(self: Mat, x: usize, y: usize) u8 {
        assert(x < self.width);
        assert(y < self.height);

        // +1 to account for \n
        return self.data[y * (self.width + 1) + x];
    }
};

pub fn part1(alloc: Allocator, input: []const u8) !i32 {
    const mat: Mat = .init(input);

    var groups: std.AutoArrayHashMap(u8, std.ArrayList(Vec2)) = .init(alloc);
    defer {
        var it = groups.iterator();
        while (it.next()) |a| {
            a.value_ptr.deinit();
        }
        groups.deinit();
    }

    // Find antennas
    for (0..mat.height) |y| {
        for (0..mat.width) |x| {
            const id = mat.get(x, y);
            if (id != '.') {
                const group = try groups.getOrPut(id);
                if (!group.found_existing) {
                    group.value_ptr.* = .init(alloc);
                }
                try group.value_ptr.append(.{ @intCast(x), @intCast(y) });
            }
        }
    }

    // Find pairs
    var pairs: Set(struct { u8, Vec2, Vec2 }) = .init(alloc);
    defer pairs.deinit();

    var group_it = groups.iterator();
    while (group_it.next()) |group| {
        for (group.value_ptr.items) |a1| {
            for (group.value_ptr.items) |a2| {
                // Sort (a1, a2) to avoid duplicates
                const a1_rank = a1[0] + a1[1] * @as(i32, @intCast(mat.width));
                const a2_rank = a2[0] + a2[1] * @as(i32, @intCast(mat.width));

                // Same antenna
                if (a1_rank == a2_rank) {
                    continue;
                }

                const pair = .{
                    group.key_ptr.*,
                    if (a1_rank <= a2_rank) a1 else a2,
                    if (a1_rank <= a2_rank) a2 else a1,
                };
                try pairs.put(pair, {});
            }
        }
    }

    // Antinodes can't overlap so we need unique positions
    var antinodes: Set(Vec2) = .init(alloc);
    defer antinodes.deinit();

    var pair_it = pairs.iterator();
    while (pair_it.next()) |entry| {
        _, const n1, const n2 = entry.key_ptr.*;

        const diff = n2 - n1;
        const step = @select(i32, diff != Vec2{ 0, 0 }, .{ 1, 1 }, .{ 0, 0 });

        // Antinodes
        const an1: Vec2 = n1 - step * diff;
        const an2: Vec2 = n2 + step * diff;

        if (an1[0] >= 0 and
            an1[0] < mat.width and
            an1[1] >= 0 and
            an1[1] < mat.height)
        {
            try antinodes.put(an1, {});
        }
        if (an2[0] >= 0 and
            an2[0] < mat.width and
            an2[1] >= 0 and
            an2[1] < mat.height)
        {
            try antinodes.put(an2, {});
        }
    }

    return @intCast(antinodes.count());
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const input = @embedFile("input/day8.txt");
    const ans1 = try part1(arena.allocator(), input);
    print("Part 1: {d}\n", .{ans1});
}

const test_alloc = std.testing.allocator;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;
const expectEqualSlices = std.testing.expectEqualSlices;
const expectError = std.testing.expectError;

test {
    const input =
        \\............
        \\........0...
        \\.....0......
        \\.......0....
        \\....0.......
        \\......A.....
        \\............
        \\............
        \\........A...
        \\.........A..
        \\............
        \\............
    ;
    try expectEqual(14, try part1(test_alloc, input));
}
