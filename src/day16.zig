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

const neighbors: [4]Vec2 = .{
    .{ 0, -1 },
    .{ 0, 1 },
    .{ -1, 0 },
    .{ 1, 0 },
};

const QueueItem = struct { Vec2, Vec2, i32 };

fn lessThan(context: void, a: QueueItem, b: QueueItem) std.math.Order {
    _ = context;
    return std.math.order(a.@"2", b.@"2");
}

fn part1(alloc: Allocator, input: []const u8) !usize {
    const map = try Mat(u8).initFromInput(alloc, input);
    defer map.deinit(alloc);

    var start: ?Vec2 = null;
    var end: ?Vec2 = null;

    for (0..map.height) |y| {
        for (0..map.width) |x| {
            const v: Vec2 = .{ @intCast(x), @intCast(y) };
            if (try map.get(v) == 'S') start = v;
            if (try map.get(v) == 'E') end = v;
        }
    }

    if (start == null or end == null) {
        return error.InvalidInput;
    }

    // Dijkstras algorithm

    var queue = std.PriorityQueue(QueueItem, void, lessThan).init(alloc, {});
    defer queue.deinit();
    try queue.add(.{ start.?, .{ 1, 0 }, 0 });

    var dist = std.AutoArrayHashMap(Vec2, i32).init(alloc);
    defer dist.deinit();

    while (queue.removeOrNull()) |node| {
        const u, const u_dir, const u_dist = node;

        if (@reduce(.And, u == end.?)) {
            break;
        }

        // Adjacency:
        // * Forward (if no wall): 1
        // * 90 degree turn: 1000
        // * -90 degree turn: 1000
        for (neighbors) |v_dir| {
            const v = u + v_dir;
            if (try map.get(v) == '#') {
                continue;
            }

            var n_dist: i32 = 0;
            if (@reduce(.And, v_dir == u_dir)) {
                n_dist = 1;
            } else if (@reduce(.And, v_dir == -u_dir)) {
                // Backwards
                continue;
            } else {
                n_dist = 1001;
            }

            const v_dist = u_dist + n_dist;
            if (!dist.contains(v) or v_dist < dist.get(v).?) {
                try dist.put(v, v_dist);
                try queue.add(.{ v, v_dir, v_dist });
            }
        }
    }
    return @intCast(dist.get(end.?).?);
}

fn part2(alloc: Allocator, input: []const u8) !usize {
    const map = try Mat(u8).initFromInput(alloc, input);
    defer map.deinit(alloc);

    var start: ?Vec2 = null;
    var end: ?Vec2 = null;

    for (0..map.height) |y| {
        for (0..map.width) |x| {
            const v: Vec2 = .{ @intCast(x), @intCast(y) };
            if (try map.get(v) == 'S') start = v;
            if (try map.get(v) == 'E') end = v;
        }
    }

    if (start == null or end == null) {
        return error.InvalidInput;
    }

    // Dijkstras again, but now we want to find nodes touched in all minimum paths.
    // Not optimal but we do Dijkstra twice to get the distance of all nodes to both
    // start and end. Then we pick then nodes that have a distance in both directions
    // that matches the shortest path.

    var queue = std.PriorityQueue(QueueItem, void, lessThan).init(alloc, {});
    defer queue.deinit();

    var dist_to_start = std.AutoArrayHashMap(Vec2, i32).init(alloc);
    defer dist_to_start.deinit();
    try dist_to_start.put(start.?, 0);

    try queue.add(.{ start.?, .{ 1, 0 }, 0 });
    while (queue.removeOrNull()) |node| {
        const u, const u_dir, const u_dist = node;

        for (neighbors) |v_dir| {
            const v = u + v_dir;
            if (try map.get(v) == '#') {
                continue;
            }

            var n_dist: i32 = 0;
            if (@reduce(.And, v_dir == u_dir)) {
                n_dist = 1;
            } else if (@reduce(.And, v_dir == -u_dir)) {
                // Backwards
                continue;
            } else {
                n_dist = 1001;
            }

            const v_dist = u_dist + n_dist;
            if (!dist_to_start.contains(v) or v_dist < dist_to_start.get(v).?) {
                try dist_to_start.put(v, v_dist);
                try queue.add(.{ v, v_dir, v_dist });
            }
        }
    }

    var dist_to_end = std.AutoArrayHashMap(Vec2, i32).init(alloc);
    defer dist_to_end.deinit();
    try dist_to_end.put(end.?, 0);

    // Do the dance again but backwards
    while (queue.removeOrNull()) |_| {} // Clear queue (no clear() :()
    try queue.add(.{ end.?, .{ 1, 0 }, 0 });
    while (queue.removeOrNull()) |node| {
        const u, const u_dir, const u_dist = node;

        for (neighbors) |v_dir| {
            const v = u + v_dir;
            if (try map.get(v) == '#') {
                continue;
            }

            var n_dist: i32 = 0;
            if (@reduce(.And, v_dir == u_dir)) {
                n_dist = 1;
            } else if (@reduce(.And, v_dir == -u_dir)) {
                // Backwards
                continue;
            } else {
                n_dist = 1001;
            }

            const v_dist = u_dist + n_dist;
            if (!dist_to_end.contains(v) or v_dist < dist_to_end.get(v).?) {
                try dist_to_end.put(v, v_dist);
                try queue.add(.{ v, v_dir, v_dist });
            }
        }
    }

    const shortest_dist = dist_to_start.get(end.?).?;

    var visited = Set(Vec2).init(alloc);
    defer visited.deinit();

    for (0..map.height) |y| {
        for (0..map.width) |x| {
            const p: Vec2 = .{ @intCast(x), @intCast(y) };
            if (dist_to_start.contains(p) and dist_to_end.contains(p)) {
                const total = dist_to_start.get(p).? + dist_to_end.get(p).?;
                // Checks +1000 since above doesn't account for a potential last rotation
                if (total == shortest_dist + 1000 or total == shortest_dist) {
                    try visited.put(p, {});
                }
            }
        }
    }

    return @intCast(visited.count());
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const input = @embedFile("input/day16.txt");

    const ans1 = try part1(arena.allocator(), input);
    print("Part 1: {d}\n", .{ans1});

    const ans2 = try part2(arena.allocator(), input);
    print("Part 2: {d}\n", .{ans2});
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

test "part1" {
    const input =
        \\###############
        \\#.......#....E#
        \\#.#.###.#.###.#
        \\#.....#.#...#.#
        \\#.###.#####.#.#
        \\#.#.#.......#.#
        \\#.#.#####.###.#
        \\#...........#.#
        \\###.#.#####.#.#
        \\#...#.....#.#.#
        \\#.#.#.###.#.#.#
        \\#.....#...#.#.#
        \\#.###.#.#.#.#.#
        \\#S..#.....#...#
        \\###############
    ;

    try expectEqual(7036, try part1(test_alloc, input));
}
test "part2" {
    const input =
        \\#################
        \\#...#...#...#..E#
        \\#.#.#.#.#.#.#.#.#
        \\#.#.#.#...#...#.#
        \\#.#.#.#.###.#.#.#
        \\#...#.#.#.....#.#
        \\#.#.#.#.#.#####.#
        \\#.#...#.#.#.....#
        \\#.#.#####.#.###.#
        \\#.#.#.......#...#
        \\#.#.###.#####.###
        \\#.#.#...#.....#.#
        \\#.#.#.#####.###.#
        \\#.#.#.........#.#
        \\#.#.#.#########.#
        \\#S#.............#
        \\#################
    ;

    try expectEqual(64, try part2(test_alloc, input));
}
