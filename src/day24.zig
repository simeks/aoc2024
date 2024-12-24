const std = @import("std");
const Allocator = std.mem.Allocator;

const assert = std.debug.assert;
const print = std.debug.print;
const parseInt = std.fmt.parseInt;
const isDigit = std.ascii.isDigit;

const Node = @Vector(3, u8);

fn Set(Type: type) type {
    return std.AutoArrayHashMap(Type, void);
}

fn part1(alloc: Allocator, input: []const u8) !u64 {
    var ctx = try parseInput(alloc, input);
    defer ctx.deinit();

    // Topological sort

    var sorted = std.ArrayList(Node).init(alloc);
    defer sorted.deinit();

    var edges = std.AutoArrayHashMap(Node, Set(Node)).init(alloc);
    defer {
        var it = edges.iterator();
        while (it.next()) |v| {
            v.value_ptr.deinit();
        }
        edges.deinit();
    }

    for (ctx.ops.items) |op| {
        if (edges.getPtr(op.in0)) |e| {
            try e.put(op.out, {});
        } else {
            var lst: Set(Node) = .init(alloc);
            try lst.put(op.out, {});
            try edges.put(op.in0, lst);
        }

        if (edges.getPtr(op.in1)) |e| {
            try e.put(op.out, {});
        } else {
            var lst: Set(Node) = .init(alloc);
            try lst.put(op.out, {});
            try edges.put(op.in1, lst);
        }
    }

    var s = Set(Node).init(alloc);
    defer s.deinit();

    var in_it = ctx.values.iterator();
    while (in_it.next()) |n| {
        try s.put(n.key_ptr.*, {});
    }

    while (s.popOrNull()) |item| {
        const v = item.key;
        try sorted.append(v);

        if (edges.getPtr(v)) |e| {
            while (e.popOrNull()) |w| {
                var other = false;

                var it = edges.iterator();
                while (it.next()) |e2| {
                    if (e2.value_ptr.contains(w.key)) {
                        other = true;
                        break;
                    }
                }

                if (!other) {
                    try s.put(w.key, {});
                }
            }
        }
    }

    var ops = std.AutoArrayHashMap(Node, Op).init(alloc);
    defer ops.deinit();

    for (ctx.ops.items) |op| {
        try ops.put(op.out, op);
    }

    for (sorted.items) |n| {
        if (ops.get(n)) |op| {
            const in0 = ctx.values.get(op.in0).?;
            const in1 = ctx.values.get(op.in1).?;

            const out = switch (op.op) {
                .AND => in0 & in1,
                .OR => in0 | in1,
                .XOR => in0 ^ in1,
            };

            try ctx.values.put(op.out, out);
        }
    }

    var out: usize = 0;

    for (0..46) |i| {
        const n: Node = .{
            'z',
            '0' + @as(u8, @intCast(@divFloor(i, 10))),
            '0' + @as(u8, @intCast(@mod(i, 10))),
        };
        const v: usize = @intCast(ctx.values.get(n).?);
        out |= v << @intCast(i);
    }

    return out;
}

fn part2(alloc: Allocator, input: []const u8) !i64 {
    _ = alloc;
    _ = input;

    // Part 2 solved mostly manually. We know its a adder circuit with carry and we know
    // which bits are incorrect by comparing actual output to expected output. Backtrack
    // the incorrect outputs and find the incorrect nodes of the adder. Knowing the
    // expected layout of the circuit it is trivial to derive what to replace with.

    return 0;
}

const Op = struct {
    op: enum { AND, OR, XOR },
    in0: Node,
    in1: Node,
    out: Node,
};

const Context = struct {
    values: std.AutoArrayHashMap(Node, u1),
    ops: std.ArrayList(Op),

    pub fn init(alloc: Allocator) Context {
        return .{
            .values = .init(alloc),
            .ops = .init(alloc),
        };
    }
    pub fn deinit(self: *Context) void {
        self.values.deinit();
        self.ops.deinit();
    }
};

fn parseInput(alloc: Allocator, input: []const u8) !Context {
    var ctx: Context = .init(alloc);
    errdefer ctx.deinit();

    var part_it = std.mem.tokenizeSequence(u8, input, "\n\n");

    var in_it = std.mem.tokenizeScalar(u8, part_it.next().?, '\n');
    while (in_it.next()) |v| {
        const n: Node = .{ v[0], v[1], v[2] };
        try ctx.values.put(n, if (v[5] == '1') 1 else 0);
    }

    var op_it = std.mem.tokenizeScalar(u8, part_it.next().?, '\n');
    while (op_it.next()) |line| {
        var it = std.mem.tokenizeScalar(u8, line, ' ');
        const in0 = it.next().?;
        const op = it.next().?;
        const in1 = it.next().?;
        _ = it.next().?;
        const out = it.next().?;

        try ctx.ops.append(.{
            .op = switch (op[0]) {
                'A' => .AND,
                'O' => .OR,
                'X' => .XOR,
                else => @panic("invalid input"),
            },
            .in0 = .{ in0[0], in0[1], in0[2] },
            .in1 = .{ in1[0], in1[1], in1[2] },
            .out = .{ out[0], out[1], out[2] },
        });
    }
    return ctx;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const input = @embedFile("input/day24.txt");

    const ans1 = try part1(arena.allocator(), input);
    print("Part 1: {d}\n", .{ans1});

    const ans2 = try part2(arena.allocator(), input);
    print("Part 2: {d}\n", .{ans2});
}
