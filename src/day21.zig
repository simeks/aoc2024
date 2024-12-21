const std = @import("std");
const Allocator = std.mem.Allocator;

const assert = std.debug.assert;
const print = std.debug.print;
const parseInt = std.fmt.parseInt;
const isDigit = std.ascii.isDigit;

const Vec2 = @Vector(2, i32);
const Path = std.BoundedArray(u8, 16);

const Keypad = struct {
    buttons: []const []const u8,

    pub fn isInside(self: Keypad, idx: Vec2) bool {
        return idx[0] >= 0 and
            idx[0] < self.buttons[0].len and
            idx[1] >= 0 and
            idx[1] < self.buttons.len;
    }
    pub fn get(self: Keypad, idx: Vec2) ?u8 {
        if (!self.isInside(idx)) return null;
        return self.buttons[@intCast(idx[1])][@intCast(idx[0])];
    }
    pub fn find(self: Keypad, what: u8) ?Vec2 {
        for (0.., self.buttons) |y, line| {
            for (0.., line) |x, b| {
                if (b == what) {
                    return .{ @intCast(x), @intCast(y) };
                }
            }
        }
        return null;
    }
};

const num_keypad: Keypad = .{ .buttons = &.{
    "789",
    "456",
    "123",
    " 0A",
} };
const dir_keypad: Keypad = .{ .buttons = &.{
    " ^A",
    "<v>",
} };

/// Find all variations of button presses producing target
fn findButtons(alloc: Allocator, pad: *const Keypad, target: []const u8) !std.ArrayList(Path) {
    var out = std.ArrayList(Path).init(alloc);
    errdefer out.deinit();

    var queue = std.ArrayList(struct { Vec2, usize, Path }).init(alloc);
    defer queue.deinit();

    const start = pad.find('A') orelse return error.InvalidInput;

    try queue.append(.{ start, 0, try Path.init(0) });

    while (queue.popOrNull()) |item| {
        const curr, const i, const path = item;

        if (!pad.isInside(curr)) {
            continue;
        }

        if (pad.get(curr) == ' ') {
            continue;
        }

        if (i == target.len) {
            try out.append(path);
            continue;
        }

        const end = pad.find(target[i]) orelse return error.InvalidInput;
        if (@reduce(.And, curr == end)) {
            var new_path = path;
            try new_path.append('A');
            try queue.append(.{ curr, i + 1, new_path });
        }

        const sign = @max(Vec2{ -1, -1 }, @min(end - curr, Vec2{ 1, 1 }));
        if (sign[0] != 0) {
            var new_path = path;
            try new_path.append(if (sign[0] > 0) '>' else '<');
            try queue.append(.{ curr + Vec2{ sign[0], 0 }, i, new_path });
        }
        if (sign[1] != 0) {
            var new_path = path;
            try new_path.append(if (sign[1] > 0) 'v' else '^');
            try queue.append(.{ curr + Vec2{ 0, sign[1] }, i, new_path });
        }
    }
    return out;
}

const Cache = std.AutoArrayHashMap(struct { i32, Path }, usize);

fn search(
    alloc: Allocator,
    max_depth: i32,
    depth: i32,
    target: Path,
    cache: *Cache,
) !usize {
    if (depth == max_depth) {
        return 1;
    }

    if (cache.get(.{ depth, target })) |ret| {
        return ret;
    }

    var min: ?usize = null;

    const keypad = if (depth == 0) &num_keypad else &dir_keypad;

    var possible = try findButtons(alloc, keypad, target.slice());
    defer possible.deinit();
    for (possible.items) |p| {
        var len: usize = 0;
        var it = std.mem.splitScalar(u8, p.slice()[0 .. p.len - 1], 'A');
        while (it.next()) |t| {
            var path: Path = try .fromSlice(t);
            try path.append('A');

            len += try search(alloc, max_depth, depth + 1, path, cache);
        }
        if (min == null or min.? > len) {
            min = len;
        }
    }
    try cache.put(.{ depth, target }, min.?);
    return min.?;
}

fn part1(alloc: Allocator, input: []const u8) !usize {
    const max_depth = 4;

    var cache: Cache = .init(alloc);
    defer cache.deinit();

    var total: usize = 0;

    var line_it = std.mem.tokenizeScalar(u8, input, '\n');
    while (line_it.next()) |line| {
        const pin = try parseInt(usize, line[0 .. line.len - 1], 10);
        const len = try search(alloc, max_depth, 0, try .fromSlice(line), &cache);
        total += pin * len;
    }

    return total;
}
fn part2(alloc: Allocator, input: []const u8) !usize {
    const max_depth = 27;

    var cache: Cache = .init(alloc);
    defer cache.deinit();

    var total: usize = 0;

    var line_it = std.mem.tokenizeScalar(u8, input, '\n');
    while (line_it.next()) |line| {
        const pin = try parseInt(usize, line[0 .. line.len - 1], 10);
        const len = try search(alloc, max_depth, 0, try .fromSlice(line), &cache);
        total += pin * len;
    }

    return total;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const input = @embedFile("input/day21.txt");

    const ans1 = try part1(arena.allocator(), input);
    print("Part 1: {d}\n", .{ans1});

    const ans2 = try part2(arena.allocator(), input);
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
        \\029A
        \\980A
        \\179A
        \\456A
        \\379A
    ;

    try expectEqual(126384, try part1(test_alloc, input));
}
