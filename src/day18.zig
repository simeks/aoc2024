const std = @import("std");
const Allocator = std.mem.Allocator;

const assert = std.debug.assert;
const print = std.debug.print;
const parseInt = std.fmt.parseInt;
const isDigit = std.ascii.isDigit;

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

fn part1(
    alloc: Allocator,
    input: []const u8,
    width: usize,
    height: usize,
    fallen: usize,
) !usize {
    var map = try parseInput(alloc, input, width, height, fallen);
    defer map.deinit(alloc);

    const start: Vec2 = .{ 0, 0 };
    const end: Vec2 = .{ @intCast(width - 1), @intCast(height - 1) };

    // Dijkstras algorithm

    var queue = std.PriorityQueue(QueueItem, void, lessThan).init(alloc, {});
    defer queue.deinit();
    try queue.add(.{ start, 0 });

    var dist = std.AutoArrayHashMap(Vec2, i32).init(alloc);
    defer dist.deinit();

    while (queue.removeOrNull()) |node| {
        const u, const u_dist = node;

        if (@reduce(.And, u == end)) {
            break;
        }

        for (neighbors) |v_dir| {
            const v = u + v_dir;
            if (!map.isInside(v)) {
                continue;
            }

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
    return @intCast(dist.get(end).?);
}
fn part2(alloc: Allocator, input: []const u8) !usize {
    _ = alloc;
    _ = input;
    return 0;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const input = @embedFile("input/day18.txt");

    const ans1 = try part1(arena.allocator(), input, 71, 71, 1024);
    print("Part 1: {d}\n", .{ans1});

    // const ans2 = try part2(arena.allocator(), input);
    // print("Part 2: {d}\n", .{ans2});
}

fn parseInput(
    alloc: Allocator,
    input: []const u8,
    width: usize,
    height: usize,
    fallen: usize,
) !Mat(u8) {
    var map = try Mat(u8).initZeros(alloc, width, height);
    errdefer map.deinit(alloc);

    var i: usize = 0;
    var line_it = std.mem.tokenizeScalar(u8, input, '\n');
    while (line_it.next()) |line| : (i += 1) {
        if (i >= fallen) break;

        var it = std.mem.tokenizeScalar(u8, line, ',');
        const x = try parseInt(i32, it.next().?, 10);
        const y = try parseInt(i32, it.next().?, 10);
        try map.set(.{ x, y }, '#');
    }

    return map;
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
        \\5,4
        \\4,2
        \\4,5
        \\3,0
        \\2,1
        \\6,3
        \\2,4
        \\1,5
        \\0,6
        \\3,3
        \\2,6
        \\5,1
        \\1,2
        \\5,5
        \\2,5
        \\6,5
        \\1,4
        \\0,4
        \\6,4
        \\1,1
        \\6,1
        \\1,0
        \\0,5
        \\1,6
        \\2,0
    ;

    try expectEqual(22, try part1(test_alloc, input, 7, 7, 12));
}

test "part2" {}