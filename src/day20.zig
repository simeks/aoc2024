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

const QueueItem = struct { Vec2, i32 };

fn lessThan(context: void, a: QueueItem, b: QueueItem) std.math.Order {
    _ = context;
    return std.math.order(a.@"1", b.@"1");
}

/// min_savings: Cheat must save at least this number of picoseconds
fn part1(alloc: Allocator, input: []const u8, min_savings: i32) !usize {
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

    var queue = std.PriorityQueue(QueueItem, void, lessThan).init(alloc, {});
    defer queue.deinit();

    var dist = std.AutoArrayHashMap(Vec2, i32).init(alloc);
    defer dist.deinit();
    try dist.put(end.?, 0);

    try queue.add(.{ end.?, 0 });
    while (queue.removeOrNull()) |node| {
        const u, const u_dist = node;

        for (neighbors) |v_dir| {
            const v = u + v_dir;
            if (try map.get(v) == '#') {
                continue;
            }

            const v_dist = u_dist + 1;
            if (!dist.contains(v) or v_dist < dist.get(v).?) {
                try dist.put(v, v_dist);
                try queue.add(.{ v, v_dist });
            }
        }
    }

    var ncheats: usize = 0;

    var dist_it = dist.iterator();
    while (dist_it.next()) |entry| {
        const u = entry.key_ptr.*;
        const du = entry.value_ptr.*;

        for (neighbors) |v_dir| {
            const v = u + v_dir;
            if (try map.get(v) == '#') {
                const w = v + v_dir;
                if (!map.isInside(w)) continue;
                if (dist.get(w)) |dw| {
                    const s = (du - dw - 2);
                    if (s >= min_savings) {
                        ncheats += 1;
                    }
                }
            }
        }
    }

    return ncheats;
}
/// min_savings: Cheat must save at least this number of picoseconds
fn part2(alloc: Allocator, input: []const u8, min_savings: i32) !usize {
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

    var queue = std.PriorityQueue(QueueItem, void, lessThan).init(alloc, {});
    defer queue.deinit();

    var dist = std.AutoArrayHashMap(Vec2, i32).init(alloc);
    defer dist.deinit();
    try dist.put(end.?, 0);

    try queue.add(.{ end.?, 0 });
    while (queue.removeOrNull()) |node| {
        const u, const u_dist = node;

        for (neighbors) |v_dir| {
            const v = u + v_dir;
            if (try map.get(v) == '#') {
                continue;
            }

            const v_dist = u_dist + 1;
            if (!dist.contains(v) or v_dist < dist.get(v).?) {
                try dist.put(v, v_dist);
                try queue.add(.{ v, v_dist });
            }
        }
    }

    var queue2 = std.PriorityQueue(QueueItem, void, lessThan).init(alloc, {});
    defer queue2.deinit();

    var cheats = std.AutoArrayHashMap(struct { Vec2, Vec2 }, i32).init(alloc);
    defer cheats.deinit();

    // Distance from u
    var dist2 = std.AutoArrayHashMap(Vec2, i32).init(alloc);
    defer dist2.deinit();

    var dist_it = dist.iterator();
    while (dist_it.next()) |entry| {
        // For every point, u, on path, run dijkstras again...

        const u = entry.key_ptr.*;
        const du = entry.value_ptr.*;

        while (queue2.removeOrNull()) |_| {}
        dist2.clearRetainingCapacity();

        for (neighbors) |v_dir| {
            try queue2.add(.{ u + v_dir, 1 });
        }

        while (queue2.removeOrNull()) |item| {
            const v, const steps = item;
            if (steps > 20) continue;

            if (try map.get(v) != '#') {
                const dv = dist.get(v).?;
                const s = (du - dv - steps);
                if (s >= min_savings) {
                    if (cheats.getPtr(.{ u, v })) |p| {
                        if (p.* > s) {
                            continue;
                        }
                    }
                    try cheats.put(.{ u, v }, s);
                }
            }

            for (neighbors) |w_dir| {
                const w = v + w_dir;
                if (!map.isInside(w)) continue;

                const w_dist = steps + 1;
                if (!dist2.contains(w) or w_dist < dist2.get(w).?) {
                    try dist2.put(w, w_dist);
                    try queue2.add(.{ w, steps + 1 });
                }
            }
        }
    }

    return cheats.count();
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const input = @embedFile("input/day20.txt");

    const ans1 = try part1(arena.allocator(), input, 100);
    print("Part 1: {d}\n", .{ans1});

    const ans2 = try part2(arena.allocator(), input, 100);
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
        \\#...#...#.....#
        \\#.#.#.#.#.###.#
        \\#S#...#.#.#...#
        \\#######.#.#.###
        \\#######.#.#...#
        \\#######.#.###.#
        \\###..E#...#...#
        \\###.#######.###
        \\#...###...#...#
        \\#.#####.#.###.#
        \\#.#...#.#.#...#
        \\#.#.#.#.#.#.###
        \\#...#...#...###
        \\###############
    ;

    try expectEqual(44, try part1(test_alloc, input, 0));
}
test "part2" {
    const input =
        \\###############
        \\#...#...#.....#
        \\#.#.#.#.#.###.#
        \\#S#...#.#.#...#
        \\#######.#.#.###
        \\#######.#.#...#
        \\#######.#.###.#
        \\###..E#...#...#
        \\###.#######.###
        \\#...###...#...#
        \\#.#####.#.###.#
        \\#.#...#.#.#...#
        \\#.#.#.#.#.#.###
        \\#...#...#...###
        \\###############
    ;

    try expectEqual(285, try part2(test_alloc, input, 50));
}
