const std = @import("std");
const Allocator = std.mem.Allocator;

const assert = std.debug.assert;
const print = std.debug.print;
const parseInt = std.fmt.parseInt;
const isDigit = std.ascii.isDigit;

const Vec2 = @Vector(2, i32);

const Robot = struct {
    pos: Vec2,
    vel: Vec2,
};
const RobotList = std.ArrayList(Robot);

fn step(robots: []Robot, board_size: Vec2) void {
    for (robots) |*robot| {
        robot.pos = @mod(robot.pos + robot.vel, board_size);
    }
}

/// Count number of robots in each quadrant
fn countQuads(robots: []const Robot, board_size: Vec2) @Vector(4, usize) {
    const mid: Vec2 = @divFloor(board_size, @as(Vec2, @splat(2)));
    var quads: @Vector(4, usize) = @splat(0);
    for (robots) |robot| {
        if (@reduce(.Or, robot.pos == mid)) {
            continue;
        }

        const i = @select(usize, robot.pos < mid, .{ 0, 0 }, .{ 1, 2 });
        quads[@reduce(.Add, i)] += 1;
    }
    return quads;
}

/// SAD between each robot
fn boardError(robots: []const Robot) usize {
    var sum: usize = 0;
    for (robots) |r1| {
        for (robots) |r2| {
            sum += @abs(r2.pos[0] - r1.pos[0]) + @abs(r2.pos[1] - r1.pos[1]);
        }
    }
    return sum;
}

fn part1(alloc: Allocator, input: []const u8, board_size: Vec2) !usize {
    const robots = try parseInput(alloc, input);
    defer robots.deinit();

    for (0..100) |_| {
        step(robots.items, board_size);
    }

    const quads = countQuads(robots.items, board_size);
    return @reduce(.Mul, quads);
}

fn part2(alloc: Allocator, input: []const u8, board_size: Vec2) !usize {
    const robots = try parseInput(alloc, input);
    defer robots.deinit();

    var best_board = try Mat(u8).initZeros(
        alloc,
        @intCast(board_size[0]),
        @intCast(board_size[1]),
    );
    defer best_board.deinit(alloc);

    // Find the board by minimizing a cost. We can either use
    // SAD: Assuming robots are clustered together forming the christmas tree
    // countQuads: Also a good metric for clustered robots, faster but since we
    //              use the procut we assume no quad is empty.

    var best: ?struct { usize, usize } = null;

    for (0..10000) |s| {
        step(robots.items, board_size);

        // SAD
        // const cost = boardError(robots.items);
        // Quadrant count
        const cost = @reduce(.Mul, countQuads(robots.items, board_size));

        if (best == null or cost < best.?.@"0") {
            // Save best board for printing later
            @memset(best_board.data, ' ');
            for (robots.items) |robot| {
                try best_board.set(robot.pos, 'X');
            }

            best = .{ cost, s + 1 };
        }
    }

    for (0..best_board.height) |y| {
        for (0..best_board.width) |x| {
            print("{c}", .{try best_board.get(.{ @intCast(x), @intCast(y) })});
        }
        print("\n", .{});
    }

    return best.?.@"1";
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const input = @embedFile("input/day14.txt");

    const ans1 = try part1(arena.allocator(), input, .{ 101, 103 });
    print("Part 1: {d}\n", .{ans1});

    const ans2 = try part2(arena.allocator(), input, .{ 101, 103 });
    print("Part 2: {d}\n", .{ans2});
}

fn parseInput(alloc: Allocator, input: []const u8) !RobotList {
    var robots = RobotList.init(alloc);
    var it = std.mem.tokenizeScalar(u8, input, '\n');
    while (it.next()) |line| {
        var it2 = std.mem.tokenizeAny(u8, line, "=, ");
        _ = it2.next();
        const px = try parseInt(i32, it2.next().?, 10);
        const py = try parseInt(i32, it2.next().?, 10);
        _ = it2.next();
        const vx = try parseInt(i32, it2.next().?, 10);
        const vy = try parseInt(i32, it2.next().?, 10);

        try robots.append(.{
            .pos = .{ px, py },
            .vel = .{ vx, vy },
        });
    }
    return robots;
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
        \\p=0,4 v=3,-3
        \\p=6,3 v=-1,-3
    ;
    const robots = try parseInput(test_alloc, input);
    defer robots.deinit();

    try expectEqual(2, robots.items.len);
    try expectEqual(.{ 0, 4 }, robots.items[0].pos);
    try expectEqual(.{ 3, -3 }, robots.items[0].vel);
    try expectEqual(.{ 6, 3 }, robots.items[1].pos);
    try expectEqual(.{ -1, -3 }, robots.items[1].vel);
}
test "part1" {
    const input =
        \\p=0,4 v=3,-3
        \\p=6,3 v=-1,-3
        \\p=10,3 v=-1,2
        \\p=2,0 v=2,-1
        \\p=0,0 v=1,3
        \\p=3,0 v=-2,-2
        \\p=7,6 v=-1,-3
        \\p=3,0 v=-1,-2
        \\p=9,3 v=2,3
        \\p=7,3 v=-1,2
        \\p=2,4 v=2,-3
        \\p=9,5 v=-3,-3
    ;
    try expectEqual(12, try part1(test_alloc, input, .{ 11, 7 }));
}
