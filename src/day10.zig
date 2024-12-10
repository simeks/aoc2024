const std = @import("std");
const Allocator = std.mem.Allocator;

const assert = std.debug.assert;
const print = std.debug.print;
const parseInt = std.fmt.parseInt;
const isDigit = std.ascii.isDigit;

fn Set(Type: type) type {
    return std.AutoArrayHashMap(Type, void);
}

const Visited = union(enum) {
    set: *Set(Vec2),
    sum: *usize,
};

const Vec2 = @Vector(2, i32);

const neightbors = [_]Vec2{
    .{ -1, 0 },
    .{ 1, 0 },
    .{ 0, -1 },
    .{ 0, 1 },
};

fn search(visited: Visited, mat: *const Mat, p: Vec2, cur: u8) !void {
    if (cur == '9') {
        switch (visited) {
            .set => |set| try set.put(p, {}),
            .sum => |sum| sum.* += 1,
        }
        return;
    }

    for (neightbors) |n| {
        const p2 = p + n;
        if (mat.isInside(p2)) {
            if (mat.get(p2) == cur + 1) {
                try search(visited, mat, p2, cur + 1);
            }
        }
    }
}

fn part1(alloc: Allocator, input: []const u8) !usize {
    const mat = Mat.init(input);

    var v = Set(Vec2).init(alloc);
    defer v.deinit();

    var score: usize = 0;
    for (0..@intCast(mat.height)) |y| {
        for (0..@intCast(mat.width)) |x| {
            const p: Vec2 = .{ @intCast(x), @intCast(y) };
            if (mat.get(p) == '0') {
                try search(.{ .set = &v }, &mat, p, '0');

                score += v.count();
                v.clearRetainingCapacity();
            }
        }
    }
    return score;
}

fn part2(input: []const u8) !usize {
    const mat = Mat.init(input);

    var score: usize = 0;
    for (0..@intCast(mat.height)) |y| {
        for (0..@intCast(mat.width)) |x| {
            const p: Vec2 = .{ @intCast(x), @intCast(y) };
            if (mat.get(p) == '0') {
                try search(.{ .sum = &score }, &mat, p, '0');
            }
        }
    }
    return score;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());

    const input = @embedFile("input/day10.txt");
    const ans1 = try part1(arena.allocator(), input);
    print("Part 1: {d}\n", .{ans1});

    const ans2 = try part2(input);
    print("Part 2: {d}\n", .{ans2});
}

/// Matrix backed by input data txt
const Mat = struct {
    width: i32,
    height: i32,
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
            .width = @intCast(width.?),
            .height = @intCast(height),
            .data = input,
        };
    }

    pub fn get(self: Mat, p: Vec2) u8 {
        assert(p[0] < self.width);
        assert(p[1] < self.height);

        // +1 to account for \n
        return self.data[@intCast(p[1] * (self.width + 1) + p[0])];
    }

    pub fn isInside(self: Mat, p: Vec2) bool {
        return (p[0] >= 0 and
            p[0] < self.width and
            p[1] >= 0 and
            p[1] < self.height);
    }
};

const test_alloc = std.testing.allocator;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;
const expectEqualSlices = std.testing.expectEqualSlices;
const expectError = std.testing.expectError;

test "part1" {
    const input =
        \\89010123
        \\78121874
        \\87430965
        \\96549874
        \\45678903
        \\32019012
        \\01329801
        \\10456732
    ;
    try expectEqual(36, try part1(test_alloc, input));
}

test "part2" {
    const input =
        \\89010123
        \\78121874
        \\87430965
        \\96549874
        \\45678903
        \\32019012
        \\01329801
        \\10456732
    ;
    try expectEqual(81, try part2(input));
}
