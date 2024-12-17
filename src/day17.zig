const std = @import("std");
const Allocator = std.mem.Allocator;

const assert = std.debug.assert;
const print = std.debug.print;
const parseInt = std.fmt.parseInt;
const isDigit = std.ascii.isDigit;

const OpCode = enum(u3) {
    adv = 0,
    bxl = 1,
    bst = 2,
    jnz = 3,
    bxc = 4,
    out = 5,
    bdv = 6,
    cdv = 7,
};

const Context = struct {
    a: u64,
    b: u64,
    c: u64,
    program: []const u3,
    ip: usize = 0,

    output: std.ArrayList(u3),

    pub fn deinit(self: Context, alloc: Allocator) void {
        alloc.free(self.program);
        self.output.deinit();
    }

    fn combo(self: *Context) u64 {
        self.ip += 1;
        return switch (self.program[self.ip]) {
            0 => 0,
            1 => 1,
            2 => 2,
            3 => 3,
            4 => self.a,
            5 => self.b,
            6 => self.c,
            7 => @panic("Invalid program"),
        };
    }
    fn literal(self: *Context) u64 {
        self.ip += 1;
        return @intCast(self.program[self.ip]);
    }
    fn peek(self: *Context) OpCode {
        return @enumFromInt(self.program[self.ip]);
    }
    fn next(self: *Context) ?OpCode {
        self.ip += 1;
        if (self.ip >= self.program.len) {
            return null;
        }
        return @enumFromInt(self.program[self.ip]);
    }
    fn jump(self: *Context, ip: u64) ?OpCode {
        self.ip = @intCast(ip);
        if (self.ip >= self.program.len) {
            return null;
        }
        return @enumFromInt(self.program[self.ip]);
    }
    fn run(self: *Context) !void {
        self.ip = 0;
        self.output.clearRetainingCapacity();
        sw: switch (self.peek()) {
            .adv => {
                self.a = shift(self.a, self.combo());
                continue :sw self.next() orelse break :sw;
            },
            .bxl => {
                self.b = self.b ^ self.literal();
                continue :sw self.next() orelse break :sw;
            },
            .bst => {
                self.b = self.combo() & 0b111;
                continue :sw self.next() orelse break :sw;
            },
            .jnz => {
                if (self.a != 0) {
                    continue :sw self.jump(self.literal()) orelse break :sw;
                }
                _ = self.combo();
                continue :sw self.next() orelse break :sw;
            },
            .bxc => {
                self.b = self.b ^ self.c;
                _ = self.combo();
                continue :sw self.next() orelse break :sw;
            },
            .out => {
                try self.output.append(@intCast(self.combo() % 8));
                continue :sw self.next() orelse break :sw;
            },
            .bdv => {
                self.b = shift(self.a, self.combo());
                continue :sw self.next() orelse break :sw;
            },
            .cdv => {
                self.c = shift(self.a, self.combo());
                continue :sw self.next() orelse break :sw;
            },
        }
    }
};

fn shift(a: u64, b: u64) u64 {
    return @truncate(@as(u128, @intCast(a)) >> @min(b, @typeInfo(u128).int.bits - 1));
}

fn part1(alloc: Allocator, input: []const u8) ![]const u8 {
    var ctx = try parseInput(alloc, input);
    defer ctx.deinit(alloc);

    try ctx.run();

    var out = try alloc.alloc(u8, ctx.output.items.len + ctx.output.items.len - 1);
    for (0.., ctx.output.items) |i, v| {
        out[2 * i] = @intCast('0' + @as(u8, @intCast(v)));
        if (i != ctx.output.items.len - 1) {
            out[2 * i + 1] = ',';
        }
    }

    return out;
}
fn part2(alloc: Allocator, input: []const u8) !u64 {
    // Solve part 2 by reversing the instructions received as input:
    // 2,4, bst ($a)
    // 1,5, bxl (5)
    // 7,5, cdv ($b)
    // 0,3, adv (3)
    // 4,0, bxc
    // 1,6, bxl (6)
    // 5,5, out ($b % 8)
    // 3,0, jnz (0)
    //
    // Which translates to
    //
    // while (a != 0) {
    //    b = a & 0b111;
    //    b = b ^ 0b101;
    //    c = a >> b;
    //    a = a >> 3;
    //    b = b ^ c;
    //    b = b ^ 0b110;
    //    out(b & 0b111);
    // }
    //
    // Observations
    // * Iterates over `a` in steps of octals (3 bits), lowest to highest
    // * Output is computed on current `a` and higher bits

    var ctx = try parseInput(alloc, input);
    defer ctx.deinit(alloc);

    var stack = std.ArrayList(struct { usize, u64 }).init(alloc);
    defer stack.deinit();
    try stack.append(.{ 0, 0 });

    var smallest: usize = std.math.maxInt(u64);

    // Search for a valid `a` by building `a` from the back (highest bit)
    // In reverse as output of current 3 bits of `a` depends on higher bits.
    while (stack.popOrNull()) |item| {
        const i, const aa = item;

        if (i == ctx.program.len) {
            smallest = @min(aa, smallest);
            continue;
        }

        const j = ctx.program.len - i - 1;

        // Find all solutions for `a` by reversing
        //    b = a & 0b111;
        //    b = b ^ 0b101;
        //    c = a >> b;
        //    a = a >> 3;
        //    b = b ^ c;
        //    b = b ^ 0b110;
        //    out(b & 0b111);
        // We might get multiple solutions and can't determine which is correct
        // until later 3 bit blocks, so branch on each solution.

        // `a` is 3 bit so try all
        for (0..8) |a| {
            var b = a ^ 0b101;
            const c = shift((aa << 3) + a, b);
            b = b ^ c;
            b = b ^ 0b110;
            if ((b & 0b111) == ctx.program[j]) {
                try stack.append(.{ i + 1, (aa << 3) + a });
            }
        }
    }

    return smallest;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const input = @embedFile("input/day17.txt");

    const ans1 = try part1(arena.allocator(), input);
    print("Part 1: {s}\n", .{ans1});

    const ans2 = try part2(arena.allocator(), input);
    print("Part 2: {d}\n", .{ans2});
}

fn parseInput(alloc: Allocator, input: []const u8) !Context {
    var it = std.mem.tokenizeAny(u8, input, "\n:");
    _ = it.next();
    const reg_a = try parseInt(u32, it.next().?[1..], 10);
    _ = it.next();
    const reg_b = try parseInt(u32, it.next().?[1..], 10);
    _ = it.next();
    const reg_c = try parseInt(u32, it.next().?[1..], 10);
    _ = it.next();

    const inst_line = it.next().?;

    var insts = try alloc.alloc(u3, @divFloor(inst_line.len, 2));
    errdefer alloc.free(insts);
    var inst_count: usize = 0;

    var inst_it = std.mem.tokenizeScalar(
        u8,
        inst_line[1..],
        ',',
    );
    while (inst_it.next()) |i| : (inst_count += 1) {
        insts[inst_count] = try parseInt(u3, i, 10);
    }

    return .{
        .a = reg_a,
        .b = reg_b,
        .c = reg_c,
        .program = insts,
        .output = .init(alloc),
    };
}

const test_alloc = std.testing.allocator;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;
const expectEqualSlices = std.testing.expectEqualSlices;
const expectError = std.testing.expectError;

test "parse" {
    const input =
        \\Register A: 729
        \\Register B: 0
        \\Register C: 0
        \\
        \\Program: 0,1,5,4,3,0
    ;

    const ctx = try parseInput(test_alloc, input);
    defer ctx.deinit(test_alloc);

    try expectEqual(729, ctx.a);
    try expectEqual(0, ctx.b);
    try expectEqual(0, ctx.c);
    try expectEqual(6, ctx.program.len);
    try expectEqualSlices(u3, &.{ 0, 1, 5, 4, 3, 0 }, ctx.program);
}

test "part1" {
    const input =
        \\Register A: 729
        \\Register B: 0
        \\Register C: 0
        \\
        \\Program: 0,1,5,4,3,0
    ;

    const out = try part1(test_alloc, input);
    defer test_alloc.free(out);

    try expectEqualSlices(u8, "4,6,3,5,6,3,5,2,1,0", out);
}
test "part1_1" {
    const input =
        \\Register A: 0
        \\Register B: 0
        \\Register C: 9
        \\
        \\Program: 2,6
    ;

    var ctx = try parseInput(test_alloc, input);
    defer ctx.deinit(test_alloc);

    try ctx.run();

    try expectEqual(1, ctx.b);
}
test "part1_2" {
    const input =
        \\Register A: 10
        \\Register B: 0
        \\Register C: 0
        \\
        \\Program: 5,0,5,1,5,4
    ;

    var ctx = try parseInput(test_alloc, input);
    defer ctx.deinit(test_alloc);

    try ctx.run();

    try expectEqualSlices(u3, &.{ 0, 1, 2 }, ctx.output.items);
}
test "part1_3" {
    const input =
        \\Register A: 2024
        \\Register B: 0
        \\Register C: 0
        \\
        \\Program: 0,1,5,4,3,0
    ;

    var ctx = try parseInput(test_alloc, input);
    defer ctx.deinit(test_alloc);

    try ctx.run();

    try expectEqualSlices(u3, &.{ 4, 2, 5, 6, 7, 7, 7, 7, 3, 1, 0 }, ctx.output.items);
    try expectEqual(0, ctx.a);
}
test "part1_4" {
    const input =
        \\Register A: 0
        \\Register B: 29
        \\Register C: 0
        \\
        \\Program: 1,7
    ;

    var ctx = try parseInput(test_alloc, input);
    defer ctx.deinit(test_alloc);

    try ctx.run();

    try expectEqual(26, ctx.b);
}
test "part1_5" {
    const input =
        \\Register A: 0
        \\Register B: 2024
        \\Register C: 43690
        \\
        \\Program: 4,0
    ;

    var ctx = try parseInput(test_alloc, input);
    defer ctx.deinit(test_alloc);

    try ctx.run();

    try expectEqual(44354, ctx.b);
}
