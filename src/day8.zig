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

    pub fn isInside(self: Mat, p: Vec2) bool {
        return (p[0] >= 0 and
            p[0] < self.width and
            p[1] >= 0 and
            p[1] < self.height);
    }
};

/// harmonics: Consider full line as opposed to only closest step (part 2)
fn run(alloc: Allocator, input: []const u8, harmonics: bool) !i32 {
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

    // Find antinodes

    // Antinodes can't overlap so we need unique positions
    var antinodes: Set(Vec2) = .init(alloc);
    defer antinodes.deinit();

    var pair_it = pairs.iterator();
    while (pair_it.next()) |entry| {
        _, const n1, const n2 = entry.key_ptr.*;

        const diff = n2 - n1;
        const step = @select(i32, diff != Vec2{ 0, 0 }, .{ 1, 1 }, .{ 0, 0 });

        if (harmonics) {
            // Part 2
            var i: i32 = 0; // 0 to include the antennas
            while (true) : (i += 1) {
                // Antinodes
                const an1: Vec2 = n1 - @as(Vec2, @splat(i)) * step * diff;
                const an2: Vec2 = n2 + @as(Vec2, @splat(i)) * step * diff;

                var added: i32 = 0;
                if (mat.isInside(an1)) {
                    try antinodes.put(an1, {});
                    added += 1;
                }
                if (mat.isInside(an2)) {
                    try antinodes.put(an2, {});
                    added += 1;
                }
                // Run until both are outside mat
                if (added == 0) {
                    break;
                }
            }
        } else {
            // Antinodes
            const an1: Vec2 = n1 - step * diff;
            const an2: Vec2 = n2 + step * diff;

            if (mat.isInside(an1)) {
                try antinodes.put(an1, {});
            }
            if (mat.isInside(an2)) {
                try antinodes.put(an2, {});
            }
        }
    }
    return @intCast(antinodes.count());
}
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const input = @embedFile("input/day8.txt");
    const ans1 = try run(arena.allocator(), input, false);
    print("Part 1: {d}\n", .{ans1});

    const ans2 = try run(arena.allocator(), input, true);
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
    try expectEqual(14, try run(test_alloc, input, false));
}
test "part2" {
    const input =
        \\T.........
        \\...T......
        \\.T........
        \\..........
        \\..........
        \\..........
        \\..........
        \\..........
        \\..........
        \\..........
    ;
    try expectEqual(9, try run(test_alloc, input, true));

    const input2 =
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
    try expectEqual(34, try run(test_alloc, input2, true));
}
