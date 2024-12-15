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

fn part1(alloc: Allocator, input: []const u8) !usize {
    var map, const moves = try parseInput(alloc, input);
    defer map.deinit(alloc);
    defer moves.deinit();

    var pos = map.find('@') orelse return error.InvalidInput;

    for (moves.items) |m| {
        const dir = move_dir[@intFromEnum(m)];

        var check = pos + dir;
        var end: i32 = 0;
        while (true) {
            if (try map.get(check) == '.') {
                end += 1;
                break;
            } else if (try map.get(check) == '#') {
                end = 0;
                break;
            }
            check += dir;
            end += 1;
        }

        while (end > 0) : (end -= 1) {
            const new: Vec2 = .{
                pos[0] + dir[0] * end,
                pos[1] + dir[1] * end,
            };
            const old: Vec2 = .{
                pos[0] + dir[0] * (end - 1),
                pos[1] + dir[1] * (end - 1),
            };

            try map.set(new, try map.get(old));

            if (end == 1) {
                try map.set(old, '.');
                pos = new;
            }
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

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const input = @embedFile("input/day15.txt");

    const ans1 = try part1(arena.allocator(), input);
    print("Part 1: {d}\n", .{ans1});
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
