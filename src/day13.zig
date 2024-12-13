const std = @import("std");
const Allocator = std.mem.Allocator;

const assert = std.debug.assert;
const print = std.debug.print;
const parseInt = std.fmt.parseInt;
const isDigit = std.ascii.isDigit;

const Vec2 = @Vector(2, usize);

const Config = struct {
    a: Vec2,
    b: Vec2,
    price: Vec2,
};

const ConfigList = std.ArrayList(Config);

fn minTokens(configs: []const Config) !usize {
    var sum: usize = 0;
    for (configs) |cfg| {
        // Problem:
        // Assuming input has only a single (or no) solution
        // Solves:
        // ax * a  + bx * b = px
        // ay * a  + by * b = py
        //
        // (ax, ay) move when pushing A
        // (bx, by) move when pushing B
        // (px, py) position of price

        const ax: f64 = @floatFromInt(cfg.a[0]);
        const ay: f64 = @floatFromInt(cfg.a[1]);
        const bx: f64 = @floatFromInt(cfg.b[0]);
        const by: f64 = @floatFromInt(cfg.b[1]);
        const px: f64 = @floatFromInt(cfg.price[0]);
        const py: f64 = @floatFromInt(cfg.price[1]);

        const d = (by * ax - bx * ay);

        // We assume colinearity and that the input only has a single
        // solution, which seems to be true.
        if (d == 0) {
            return error.InvalidInput;
        }

        const a = -(bx * py - by * px) / d;
        const b = -(px * ay - py * ax) / d;

        // Since we are dealing in counts, only whole numbers are valid
        // solutions.
        if (a == @round(a) and b == @round(b)) {
            sum += @intFromFloat(3 * a + b);
        }
    }
    return sum;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const input = @embedFile("input/day13.txt");
    const configs = try parseInput(arena.allocator(), input);
    defer configs.deinit();

    const ans1 = try minTokens(configs.items);
    print("Part 1: {d}\n", .{ans1});

    for (configs.items) |*cfg| {
        cfg.price += @splat(10000000000000);
    }

    const ans2 = try minTokens(configs.items);
    print("Part 2: {d}\n", .{ans2});
}

pub fn parseInput(alloc: Allocator, input: []const u8) !ConfigList {
    var list = ConfigList.init(alloc);
    errdefer list.deinit();

    var it = std.mem.tokenizeSequence(u8, input, "\n\n");
    while (it.next()) |machine| {
        var it2 = std.mem.tokenizeAny(u8, machine, "+,=\n");

        _ = it2.next();
        const ax = try parseInt(usize, it2.next().?, 10);
        _ = it2.next();
        const ay = try parseInt(usize, it2.next().?, 10);

        _ = it2.next();
        const bx = try parseInt(usize, it2.next().?, 10);
        _ = it2.next();
        const by = try parseInt(usize, it2.next().?, 10);

        _ = it2.next();
        const px = try parseInt(usize, it2.next().?, 10);
        _ = it2.next();
        const py = try parseInt(usize, it2.next().?, 10);

        try list.append(.{
            .a = .{ ax, ay },
            .b = .{ bx, by },
            .price = .{ px, py },
        });
    }

    return list;
}

const test_alloc = std.testing.allocator;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;
const expectEqualSlices = std.testing.expectEqualSlices;
const expectError = std.testing.expectError;

test "part1" {
    const input =
        \\Button A: X+94, Y+34
        \\Button B: X+22, Y+67
        \\Prize: X=8400, Y=5400
        \\
        \\Button A: X+26, Y+66
        \\Button B: X+67, Y+21
        \\Prize: X=12748, Y=12176
        \\
        \\Button A: X+17, Y+86
        \\Button B: X+84, Y+37
        \\Prize: X=7870, Y=6450
        \\
        \\Button A: X+69, Y+23
        \\Button B: X+27, Y+71
        \\Prize: X=18641, Y=10279
    ;

    const configs = try parseInput(test_alloc, input);
    defer configs.deinit();

    try expectEqual(480, try minTokens(configs.items));
}
