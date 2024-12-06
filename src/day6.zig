const std = @import("std");
const Allocator = std.mem.Allocator;

const assert = std.debug.assert;
const print = std.debug.print;
const parseInt = std.fmt.parseInt;
const isDigit = std.ascii.isDigit;

/// No set in std, so ugly hack Set:
fn Set(Type: type) type {
    return std.AutoArrayHashMap(Type, void);
}

const Vec2 = @Vector(2, i32);
const Line = struct { Vec2, Vec2 };
const Direction = enum {
    up,
    right,
    down,
    left,
};

fn step(pos: Vec2, dir: Direction) Vec2 {
    return pos + switch (dir) {
        .up => Vec2{ 0, -1 },
        .right => Vec2{ 1, 0 },
        .down => Vec2{ 0, 1 },
        .left => Vec2{ -1, 0 },
    };
}

/// Search start pos, assuming it's '^'
fn findStart(mat: Mat) !Vec2 {
    for (0..mat.height) |y| {
        for (0..mat.width) |x| {
            if (try mat.get(.{ @intCast(x), @intCast(y) }) == '^') {
                return .{ @intCast(x), @intCast(y) };
            }
        }
    }
    return error.NotFound;
}

/// Turn direction 90 degrees to the right
fn turn90(dir: Direction) Direction {
    switch (dir) {
        .up => return .right,
        .right => return .down,
        .down => return .left,
        .left => return .up,
    }
}

/// Returns a set of the visited points
fn part1(alloc: Allocator, input: []const u8) !Set(Vec2) {
    var mat = try Mat.init(alloc, input);
    defer mat.deinit(alloc);

    var visited = Set(Vec2).init(alloc);

    // Assumes we start looking upwards
    var pos = try findStart(mat);
    var dir = Direction.up;
    try visited.put(pos, {});

    while (true) {
        const next = step(pos, dir);
        const next_pixel = mat.get(next) catch {
            // Outside volume
            break;
        };

        if (next_pixel == '#') {
            dir = turn90(dir);
        } else {
            pos = next;
            try visited.put(pos, {});
        }
    }
    return visited;
}

/// Return true if a loop is detected in the given `mat`.
fn isLoop(alloc: Allocator, mat: Mat, start: Vec2) !bool {
    // Find loops by just stepping through the board. If we ever step the same line
    // twice (line represented as start + direction), we know we are in a loop.

    // We need to track both position and direction, since lines can overlap.
    var visited = Set(struct { Vec2, Direction }).init(alloc);
    defer visited.deinit();

    // Pre-allocate some memory based on what we've seen
    try visited.ensureTotalCapacity(200);

    // Assumes we start looking upwards
    var pos = start;
    var dir = Direction.up;
    try visited.put(.{ pos, dir }, {});

    blk: while (true) {
        // Move one "line" at a time, this reduces the number of points we need
        // to keep track of in `visited`. E.g. we only track the "turn" points.
        while (true) {
            const next = step(pos, dir);
            const next_pixel = mat.get(next) catch {
                // Outside volume
                break :blk;
            };
            if (next_pixel == '#') {
                break;
            }
            pos = next;
        }
        dir = turn90(dir);
        if (visited.contains(.{ pos, dir })) {
            // Running along same line twice
            return true;
        } else {
            try visited.put(.{ pos, dir }, {});
        }
    }
    return false;
}

fn part2(alloc: Allocator, input: []const u8) !i32 {
    var mat = try Mat.init(alloc, input);
    defer mat.deinit(alloc);

    const start = try findStart(mat);

    // To soften the blow of the memory allocs in the hot loop use a linear
    // allocator that we free quickly at the end of the iteration.
    var arena = std.heap.ArenaAllocator.init(alloc);

    var objects = Set(Vec2).init(alloc);
    defer objects.deinit();

    // To avoid brute-forcing the whole matrix, we can use part1 to determine
    // which positions are reasonable to block
    var visited = try part1(alloc, input);
    defer visited.deinit();

    var visit_it = visited.iterator();
    while (visit_it.next()) |visit| {
        const p = visit.key_ptr.*;
        if (p[0] == start[0] and p[1] == start[1]) {
            // Don't block start position
            continue;
        }

        try mat.set(p, '#');

        if (try isLoop(arena.allocator(), mat, start)) {
            try objects.put(p, {});
        }

        // Restore mat
        try mat.set(p, '.');

        _ = arena.reset(.free_all);
    }

    return @intCast(objects.count());
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    const input = @embedFile("input/day6.txt");

    var p1_output = try part1(alloc, input);
    defer p1_output.deinit();
    print("Part 1: {d}\n", .{p1_output.count()});

    const p2_output = try part2(alloc, input);
    print("Part 2: {d}\n", .{p2_output});
}

const Mat = struct {
    width: usize,
    height: usize,
    data: []u8,

    pub fn init(allocator: Allocator, input: []const u8) !Mat {
        const width = std.mem.indexOfScalar(u8, input, '\n') orelse {
            return error.InvalidInput;
        };
        var height: usize = std.mem.count(u8, input, "\n");

        // If no trailing \n we need to add last row ourself
        if (input[input.len - 1] != '\n') {
            height += 1;
        }

        const data = try allocator.alloc(u8, width * height);
        for (0..height) |y| {
            @memcpy(
                data[y * (width) .. y * (width) + width],
                // +1 for the \n
                input[y * (width + 1) .. y * (width + 1) + width],
            );
        }

        return .{
            .width = width,
            .height = height,
            .data = data,
        };
    }
    pub fn deinit(self: *Mat, allocator: Allocator) void {
        allocator.free(self.data);
        self.* = undefined;
    }

    pub fn get(self: Mat, index: Vec2) !u8 {
        if (index[0] < 0 or
            index[0] >= self.width or
            index[1] < 0 or
            index[1] >= self.height)
        {
            return error.OutOfBounds;
        }

        return self.data[
            @as(usize, @intCast(index[1])) *
                self.width + @as(usize, @intCast(index[0]))
        ];
    }
    pub fn set(self: *Mat, index: Vec2, value: u8) !void {
        if (index[0] < 0 or
            index[0] >= self.width or
            index[1] < 0 or
            index[1] >= self.height)
        {
            return error.OutOfBounds;
        }

        self.data[
            @as(usize, @intCast(index[1])) *
                self.width + @as(usize, @intCast(index[0]))
        ] = value;
    }
};

const test_alloc = std.testing.allocator;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;
const expectEqualSlices = std.testing.expectEqualSlices;
const expectError = std.testing.expectError;

test {
    const input =
        \\....#.....
        \\.........#
        \\..........
        \\..#.......
        \\.......#..
        \\..........
        \\.#..^.....
        \\........#.
        \\#.........
        \\......#...
    ;
    var visited = try part1(test_alloc, input);
    defer visited.deinit();
    try expectEqual(41, visited.count());
}

test {
    const input =
        \\....#.....
        \\.........#
        \\..........
        \\..#.......
        \\.......#..
        \\..........
        \\.#..^.....
        \\........#.
        \\#.........
        \\......#...
    ;
    try expectEqual(6, try part2(test_alloc, input));
}
