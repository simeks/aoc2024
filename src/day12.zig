const std = @import("std");
const Allocator = std.mem.Allocator;

const assert = std.debug.assert;
const print = std.debug.print;
const parseInt = std.fmt.parseInt;
const isDigit = std.ascii.isDigit;

const Image = Mat(u32);
const Vec2 = @Vector(2, i32);

const neighbors: [4][2]i32 = .{
    .{ 0, -1 },
    .{ 0, 1 },
    .{ -1, 0 },
    .{ 1, 0 },
};

/// Returns {number of labels, label map}
/// Ignores background (pixel==0)
fn connectedComponents(alloc: Allocator, mat: *const Image) !struct { usize, Image } {
    var cc = try Image.initZeros(alloc, mat.width, mat.height);
    errdefer cc.deinit(alloc);

    var stack = std.ArrayList(Vec2).init(alloc);
    defer stack.deinit();

    var label: u32 = 1;
    for (0..mat.height) |y| {
        for (0..mat.width) |x| {
            const p: Vec2 = .{ @intCast(x), @intCast(y) };
            if (try cc.get(p) != 0) continue; // Already assigned

            const cur: u32 = try mat.get(p);
            if (cur == 0) continue; // Background

            // DFS
            stack.clearRetainingCapacity();
            try stack.append(p);

            while (stack.items.len > 0) {
                const p2 = stack.pop();
                try cc.set(p2, label);

                for (neighbors) |n| {
                    const pn = p2 + n;
                    if (!mat.isInside(pn)) continue;
                    if (try cc.get(pn) != 0) continue; // Already assigned
                    if (try mat.get(pn) != cur) continue; // Not same label
                    try stack.append(pn);
                }
            }
            label += 1;
        }
    }
    return .{ label - 1, cc };
}

fn measureArea(label_map: *const Image, label: u32) !usize {
    var area: usize = 0;
    for (0..label_map.height) |y| {
        for (0..label_map.width) |x| {
            const p: Vec2 = .{ @intCast(x), @intCast(y) };
            if (try label_map.get(p) != label) {
                continue;
            }
            area += 1;
        }
    }
    return area;
}
fn measurePerimeter(label_map: *const Image, label: u32) !usize {
    var perimeter: usize = 0;
    for (0..label_map.height) |y| {
        for (0..label_map.width) |x| {
            const p: Vec2 = .{ @intCast(x), @intCast(y) };
            if (try label_map.get(p) != label) {
                continue;
            }
            for (neighbors) |n| {
                const pn = p + n;
                if (!label_map.isInside(pn)) {
                    perimeter += 1;
                    continue;
                }

                // Perimeter for each 4C-neighbor not sharing label
                if (try label_map.get(pn) != label) {
                    perimeter += 1;
                }
            }
        }
    }
    return perimeter;
}
fn countSides(alloc: Allocator, label_map: *const Image, label: u32) !usize {
    var sides: Image = try .initZeros(alloc, label_map.width, label_map.height);
    defer sides.deinit(alloc);

    // Find full edges by for each direction:
    // * Mark pixels with edges in given direction
    // * Count connected components (pixels with edges)
    var num_sides: usize = 0;
    for (neighbors) |n| {
        @memset(sides.data, 0);

        for (0..label_map.height) |y| {
            for (0..label_map.width) |x| {
                const p: Vec2 = .{ @intCast(x), @intCast(y) };
                if (try label_map.get(p) != label) {
                    continue;
                }

                const pn = p + n;
                if (!label_map.isInside(pn) or try label_map.get(pn) != label) {
                    try sides.set(p, 1);
                }
            }
        }

        const ncc, var cc = try connectedComponents(alloc, &sides);
        defer cc.deinit(alloc);
        num_sides += ncc;
    }
    return num_sides;
}

fn part1(alloc: Allocator, input: []const u8) !usize {
    var mat = try Image.initFromInput(alloc, input);
    defer mat.deinit(alloc);
    const n, var cc = try connectedComponents(alloc, &mat);
    defer cc.deinit(alloc);

    var sum: usize = 0;
    for (1..n + 1) |label| {
        const area = try measureArea(&cc, @intCast(label));
        const perimeter = try measurePerimeter(&cc, @intCast(label));
        sum += area * perimeter;
    }
    return sum;
}

fn part2(alloc: Allocator, input: []const u8) !usize {
    var mat = try Image.initFromInput(alloc, input);
    defer mat.deinit(alloc);
    const n, var cc = try connectedComponents(alloc, &mat);
    defer cc.deinit(alloc);

    var sum: usize = 0;
    for (1..n + 1) |label| {
        const area = try measureArea(&cc, @intCast(label));
        const sides = try countSides(alloc, &cc, @intCast(label));
        sum += area * sides;
    }
    return sum;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const input = @embedFile("input/day12.txt");

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
        pub fn deinit(self: *Self, allocator: Allocator) void {
            allocator.free(self.data);
            self.* = undefined;
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
        \\RRRRIICCFF
        \\RRRRIICCCF
        \\VVRRRCCFFF
        \\VVRCCCJFFF
        \\VVVVCJJCFE
        \\VVIVCCJJEE
        \\VVIIICJJEE
        \\MIIIIIJJEE
        \\MIIISIJEEE
        \\MMMISSJEEE
    ;
    try expectEqual(1930, try part1(test_alloc, input));
}
test "part2" {
    const input =
        \\AAAAAA
        \\AAABBA
        \\AAABBA
        \\ABBAAA
        \\ABBAAA
        \\AAAAAA
    ;
    try expectEqual(368, try part2(test_alloc, input));
}
