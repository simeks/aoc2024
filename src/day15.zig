const std = @import("std");
const Allocator = std.mem.Allocator;

const assert = std.debug.assert;
const print = std.debug.print;
const parseInt = std.fmt.parseInt;
const isDigit = std.ascii.isDigit;

const Vec2 = @Vector(2, i32);
const Move = enum {
    up,
    down,
    left,
    right,
};
const MoveList = std.ArrayList(Move);

const move_dir = std.enums.directEnumArray(Move, Vec2, 0, .{
    .up = .{ 0, -1 },
    .down = .{ 0, 1 },
    .left = .{ -1, 0 },
    .right = .{ 1, 0 },
});

fn push1(map: *Mat(u8), pos: Vec2, dir: Vec2) bool {
    const this = map.get(pos) catch {
        return false;
    };

    if (this == '#') {
        return false;
    }
    if (this == '.') {
        return true;
    }

    if (push1(map, pos + dir, dir)) {
        map.set(pos + dir, this) catch unreachable;
        return true;
    }
    return false;
}

fn part1(alloc: Allocator, input: []const u8) !usize {
    var map, const moves = try parseInput(alloc, input);
    defer map.deinit(alloc);
    defer moves.deinit();

    var pos = map.find('@') orelse return error.InvalidInput;

    for (moves.items) |m| {
        const dir = move_dir[@intFromEnum(m)];

        if (push1(&map, pos + dir, dir)) {
            try map.set(pos, '.');
            pos = pos + dir;
            try map.set(pos, '@');
        }
    }

    var score: usize = 0;
    for (0..map.height) |y| {
        for (0..map.width) |x| {
            if (try map.get(.{ @intCast(x), @intCast(y) }) == 'O') {
                score += 100 * y + x;
            }
        }
    }
    return score;
}

fn expand(alloc: Allocator, map: *const Mat(u8)) !Mat(u8) {
    var new_map = try Mat(u8).initZeros(alloc, map.width * 2, map.height);
    errdefer new_map.deinit(alloc);

    for (0..map.height) |y| {
        for (0..map.width) |x| {
            const old = map.get(.{ @intCast(x), @intCast(y) }) catch unreachable;

            if (old == '.') {
                new_map.set(.{ @intCast(2 * x), @intCast(y) }, '.') catch unreachable;
                new_map.set(.{ @intCast(2 * x + 1), @intCast(y) }, '.') catch unreachable;
            } else if (old == '#') {
                new_map.set(.{ @intCast(2 * x), @intCast(y) }, '#') catch unreachable;
                new_map.set(.{ @intCast(2 * x + 1), @intCast(y) }, '#') catch unreachable;
            } else if (old == 'O') {
                new_map.set(.{ @intCast(2 * x), @intCast(y) }, '[') catch unreachable;
                new_map.set(.{ @intCast(2 * x + 1), @intCast(y) }, ']') catch unreachable;
            } else if (old == '@') {
                new_map.set(.{ @intCast(2 * x), @intCast(y) }, '@') catch unreachable;
                new_map.set(.{ @intCast(2 * x + 1), @intCast(y) }, '.') catch unreachable;
            }
        }
    }
    return new_map;
}

fn canPush(map: *Mat(u8), pos: Vec2, dir: Vec2) bool {
    const this = map.get(pos) catch {
        return false;
    };

    if (this == '#') {
        return false;
    }
    if (this == '.') {
        return true;
    }

    if (dir[1] == 0) {
        if (canPush(map, pos + dir, dir)) {
            return true;
        }
    } else {
        const pos2 = pos + if (this == '[') Vec2{ 1, 0 } else Vec2{ -1, 0 };
        if (canPush(map, pos + dir, dir) and canPush(map, pos2 + dir, dir)) {
            return true;
        }
    }
    return false;
}

fn doPush(map: *Mat(u8), pos: Vec2, dir: Vec2) void {
    const this = map.get(pos) catch unreachable;

    if (this == '#' or this == '.') {
        return;
    }

    if (dir[1] == 0) {
        doPush(map, pos + dir, dir);
        map.set(pos + dir, this) catch unreachable;
    } else {
        const other: u8 = if (this == '[') ']' else '[';
        const pos2 = pos + if (this == '[') Vec2{ 1, 0 } else Vec2{ -1, 0 };

        doPush(map, pos + dir, dir);
        doPush(map, pos2 + dir, dir);

        map.set(pos + dir, this) catch unreachable;
        map.set(pos2 + dir, other) catch unreachable;
        map.set(pos, '.') catch unreachable;
        map.set(pos2, '.') catch unreachable;
    }
}

fn part2(alloc: Allocator, input: []const u8) !usize {
    var small_map, const moves = try parseInput(alloc, input);
    defer small_map.deinit(alloc);
    defer moves.deinit();

    var map = try expand(alloc, &small_map);
    defer map.deinit(alloc);

    var pos = map.find('@') orelse return error.InvalidInput;

    for (moves.items) |m| {
        const dir = move_dir[@intFromEnum(m)];

        if (canPush(&map, pos + dir, dir)) {
            doPush(&map, pos + dir, dir);
            try map.set(pos, '.');
            pos = pos + dir;
            try map.set(pos, '@');
        }
    }

    var score: usize = 0;
    for (0..map.height) |y| {
        for (0..map.width) |x| {
            if (try map.get(.{ @intCast(x), @intCast(y) }) == '[') {
                assert(try map.get(.{ @intCast(x + 1), @intCast(y) }) == ']');
                score += 100 * y + x;
            }
        }
    }
    return score;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const input = @embedFile("input/day15.txt");

    const ans1 = try part1(arena.allocator(), input);
    print("Part 1: {d}\n", .{ans1});

    const ans2 = try part2(arena.allocator(), input);
    print("Part 2: {d}\n", .{ans2});
}

fn parseInput(alloc: Allocator, input: []const u8) !struct { Mat(u8), MoveList } {
    var it = std.mem.tokenizeSequence(u8, input, "\n\n");
    const map = try Mat(u8).initFromInput(alloc, it.next().?);
    errdefer map.deinit(alloc);

    var moves = MoveList.init(alloc);
    errdefer moves.deinit();

    const move_str = it.next().?;
    for (move_str) |m| {
        if (m == '^') {
            try moves.append(.up);
        } else if (m == 'v') {
            try moves.append(.down);
        } else if (m == '<') {
            try moves.append(.left);
        } else if (m == '>') {
            try moves.append(.right);
        }
    }

    return .{ map, moves };
}

fn Mat(Type: type) type {
    return struct {
        const Self = @This();

        width: usize,
        height: usize,
        data: []Type,

        pub fn initZeros(allocator: Allocator, width: usize, height: usize) !Self {
            const data = try allocator.alloc(Type, width * height);
            @memset(data, 0);
            return .{
                .width = width,
                .height = height,
                .data = data,
            };
        }

        pub fn initFromInput(allocator: Allocator, input: []const u8) !Self {
            const width = std.mem.indexOfScalar(u8, input, '\n') orelse {
                return error.InvalidInput;
            };
            var height: usize = std.mem.count(u8, input, "\n");

            // If no trailing \n we need to add last row ourself
            if (input[input.len - 1] != '\n') {
                height += 1;
            }

            const data = try allocator.alloc(Type, width * height);
            for (0..height) |y| {
                for (0..width) |x| {
                    data[y * width + x] = @intCast(input[y * (width + 1) + x]);
                }
            }

            return .{
                .width = width,
                .height = height,
                .data = data,
            };
        }
        pub fn deinit(self: Self, allocator: Allocator) void {
            allocator.free(self.data);
        }

        pub fn find(self: Self, what: Type) ?Vec2 {
            for (0..self.height) |y| {
                for (0..self.width) |x| {
                    const p: Vec2 = .{ @intCast(x), @intCast(y) };
                    if (self.get(p) catch unreachable == what) {
                        return p;
                    }
                }
            }
            return null;
        }

        pub fn get(self: Self, index: Vec2) !Type {
            if (!self.isInside(index)) {
                return error.OutOfBounds;
            }

            return self.data[
                @as(usize, @intCast(index[1])) *
                    self.width + @as(usize, @intCast(index[0]))
            ];
        }
        pub fn set(self: *Self, index: Vec2, value: Type) !void {
            if (!self.isInside(index)) {
                return error.OutOfBounds;
            }

            self.data[
                @as(usize, @intCast(index[1])) *
                    self.width + @as(usize, @intCast(index[0]))
            ] = value;
        }

        pub fn isInside(self: Self, p: Vec2) bool {
            return (p[0] >= 0 and
                p[0] < @as(i32, @intCast(self.width)) and
                p[1] >= 0 and
                p[1] < @as(i32, @intCast(self.height)));
        }
    };
}

const test_alloc = std.testing.allocator;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;
const expectEqualSlices = std.testing.expectEqualSlices;
const expectError = std.testing.expectError;

test "parseInput" {
    const input =
        \\####
        \\#.O#
        \\####
        \\
        \\v^
        \\<>
    ;
    const map, const moves = try parseInput(test_alloc, input);
    defer map.deinit(test_alloc);
    defer moves.deinit();

    try expectEqual(4, map.width);
    try expectEqual(3, map.height);
    try expectEqual('.', try map.get(.{ 1, 1 }));
    try expectEqual('O', try map.get(.{ 2, 1 }));
    try expectEqual('#', try map.get(.{ 0, 1 }));

    try expectEqual(4, moves.items.len);
    try expectEqual(.down, moves.items[0]);
    try expectEqual(.up, moves.items[1]);
    try expectEqual(.left, moves.items[2]);
    try expectEqual(.right, moves.items[3]);
}
test "part1" {
    const input =
        \\########
        \\#..O.O.#
        \\##@.O..#
        \\#...O..#
        \\#.#.O..#
        \\#...O..#
        \\#......#
        \\########
        \\
        \\<^^>>>vv<v>>v<<
    ;

    try expectEqual(2028, try part1(test_alloc, input));
}
test "expand" {
    const input =
        \\####
        \\#.O#
        \\#@.#
        \\####
    ;
    const in = try Mat(u8).initFromInput(test_alloc, input);
    defer in.deinit(test_alloc);
    const out = try expand(test_alloc, &in);
    defer out.deinit(test_alloc);

    try expectEqual(8, out.width);
    try expectEqual(4, out.height);

    for (0..out.width) |x| {
        try expectEqual('#', try out.get(.{ @intCast(x), 0 }));
        try expectEqual('#', try out.get(.{ @intCast(x), 3 }));
    }

    try expectEqual('[', try out.get(.{ 4, 1 }));
    try expectEqual(']', try out.get(.{ 5, 1 }));
    try expectEqual('@', try out.get(.{ 2, 2 }));
    try expectEqual('.', try out.get(.{ 3, 2 }));
}
test "part2" {
    const input =
        \\##########
        \\#..O..O.O#
        \\#......O.#
        \\#.OO..O.O#
        \\#..O@..O.#
        \\#O#..O...#
        \\#O..O..O.#
        \\#.OO.O.OO#
        \\#....O...#
        \\##########
        \\
        \\<vv>^<v^>v>^vv^v>v<>v^v<v<^vv<<<^><<><>>v<vvv<>^v^>^<<<><<v<<<v^vv^v>^
        \\vvv<<^>^v^^><<>>><>^<<><^vv^^<>vvv<>><^^v>^>vv<>v<<<<v<^v>^<^^>>>^<v<v
        \\><>vv>v^v^<>><>>>><^^>vv>v<^^^>>v^v^<^^>v^^>v^<^v>v<>>v^v^<v>v^^<^^vv<
        \\<<v<^>>^^^^>>>v^<>vvv^><v<<<>^^^vv^<vvv>^>v<^^^^v<>^>vvvv><>>v^<<^^^^^
        \\^><^><>>><>^^<<^^v>>><^<v>^<vv>>v>>>^v><>^v><<<<v>>v<v<v>vvv>^<><<>^><
        \\^>><>^v<><^vvv<^^<><v<<<<<><^v<<<><<<^^<v<^^^><^>>^<v^><<<^>>^v<v^v<v^
        \\>^>>^v>vv>^<<^v<>><<><<v<<v><>v<^vv<<<>^^v^>^^>>><<^v>>v^v><^^>>^<>vv^
        \\<><^^>^^^<><vvvvv^v<v<<>^v<v>v<<^><<><<><<<^^<<<^<<>><<><^^^>^^<>^>v<>
        \\^^>vv<^v^v<vv>^<><v<^v>^^^>>>^^vvv^>vvv<>>>^<^>>>>>^<<^v>^vvv<>^<><<v>
        \\v^^>>><<^^<>>^v^<v^vv<>v^<<>^<^v^v><^<<<><<^<v><v<>vv>>v><v^<vv<>v^<<^
    ;

    try expectEqual(9021, try part2(test_alloc, input));
}
