const std = @import("std");
const Allocator = std.mem.Allocator;

const assert = std.debug.assert;
const print = std.debug.print;
const parseInt = std.fmt.parseInt;
const isDigit = std.ascii.isDigit;

const Node = @Vector(2, u8);
const NodeList = std.ArrayList(Node);

fn part1(alloc: Allocator, input: []const u8) !i64 {
    var adj = std.AutoArrayHashMap(Node, Set(Node)).init(alloc);
    defer {
        var it = adj.iterator();
        while (it.next()) |item| {
            item.value_ptr.deinit();
        }
        adj.deinit();
    }

    var line_it = std.mem.tokenizeScalar(u8, input, '\n');
    while (line_it.next()) |line| {
        const a: Node = .{ line[0], line[1] };
        const b: Node = .{ line[3], line[4] };

        var aa = try adj.getOrPutValue(a, .init(alloc));
        try aa.value_ptr.put(b);

        var ba = try adj.getOrPutValue(b, .init(alloc));
        try ba.value_ptr.put(a);
    }

    var count: i64 = 0;

    var a_it = adj.iterator();
    while (a_it.next()) |item| {
        const a = item.key_ptr.*;
        const a_adj = item.value_ptr;

        var b_it = a_adj.iterator();
        while (b_it.next()) |b| {
            if (lte(b, a)) continue;

            var c_it = a_adj.intersection(adj.get(b).?);
            while (c_it.next()) |c| {
                if (lte(c, b)) continue;

                if (a[0] == 't' or b[0] == 't' or c[0] == 't') {
                    count += 1;
                }
            }
        }
    }
    return count;
}

fn part2(alloc: Allocator, input: []const u8) ![]const u8 {
    var adj = std.AutoArrayHashMap(Node, Set(Node)).init(alloc);
    defer {
        var it = adj.iterator();
        while (it.next()) |item| {
            item.value_ptr.deinit();
        }
        adj.deinit();
    }

    var line_it = std.mem.tokenizeScalar(u8, input, '\n');
    while (line_it.next()) |line| {
        const a: Node = .{ line[0], line[1] };
        const b: Node = .{ line[3], line[4] };

        var aa = try adj.getOrPutValue(a, .init(alloc));
        try aa.value_ptr.put(b);

        var ba = try adj.getOrPutValue(b, .init(alloc));
        try ba.value_ptr.put(a);
    }

    var best = NodeList.init(alloc);
    defer best.deinit();

    var nodes = NodeList.init(alloc);
    defer nodes.deinit();

    var it = adj.iterator();
    while (it.next()) |item| {
        try nodes.append(item.key_ptr.*);
    }

    var r = NodeList.init(alloc);
    defer r.deinit();

    var x = NodeList.init(alloc);
    defer x.deinit();

    try bronKerbosch(alloc, &adj, &best, &r, &nodes, &x);

    const lte_fn = struct {
        pub fn inner(_: void, a: Node, b: Node) bool {
            return lte(a, b);
        }
    }.inner;
    std.mem.sort(Node, best.items, {}, lte_fn);

    const res = try alloc.alloc(u8, 2 * best.items.len + best.items.len - 1);
    for (0.., best.items) |i, n| {
        res[3 * i] = n[0];
        res[3 * i + 1] = n[1];
        if (i != best.items.len - 1) {
            res[3 * i + 2] = ',';
        }
    }
    return res;
}

fn intersection(alloc: Allocator, a: *const NodeList, b: Set(Node)) !NodeList {
    var out: NodeList = .init(alloc);
    for (a.items) |n| {
        if (b.contains(n)) {
            try out.append(n);
        }
    }
    return out;
}

fn bronKerbosch(
    alloc: Allocator,
    adj: *const std.AutoArrayHashMap(Node, Set(Node)),
    best: *NodeList,
    r: *NodeList,
    p: *const NodeList,
    x: *const NodeList,
) !void {
    if (p.items.len == 0 and x.items.len == 0) {
        if (r.items.len > best.items.len) {
            best.clearRetainingCapacity();
            for (r.items) |n| {
                try best.append(n);
            }
        }
    }

    var copy_p = try p.clone();
    defer copy_p.deinit();

    while (copy_p.items.len > 0) {
        const v = copy_p.items[copy_p.items.len - 1];
        const ip = try intersection(alloc, &copy_p, adj.get(v).?);
        defer ip.deinit();
        const ix = try intersection(alloc, x, adj.get(v).?);
        defer ix.deinit();

        try r.append(v);
        try bronKerbosch(alloc, adj, best, r, &ip, &ix);
        _ = r.pop();
        _ = copy_p.pop();
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const input = @embedFile("input/day23.txt");

    const ans1 = try part1(arena.allocator(), input);
    print("Part 1: {d}\n", .{ans1});

    const ans2 = try part2(arena.allocator(), input);
    print("Part 2: {s}\n", .{ans2});
}

fn Set(Type: type) type {
    return struct {
        const Map = std.AutoArrayHashMap(Type, void);

        const Self = @This();
        const Iterator = struct {
            it: Map.Iterator,

            pub fn next(self: *@This()) ?Type {
                if (self.it.next()) |item| {
                    return item.key_ptr.*;
                }
                return null;
            }
        };
        const IntersectIterator = struct {
            it: Map.Iterator,
            other: Self,

            pub fn next(self: *@This()) ?Type {
                while (self.it.next()) |item| {
                    if (self.other.contains(item.key_ptr.*)) {
                        return item.key_ptr.*;
                    }
                }
                return null;
            }
        };

        data: Map,

        pub fn init(alloc: Allocator) Self {
            return .{
                .data = .init(alloc),
            };
        }
        pub fn deinit(self: *Self) void {
            self.data.deinit();
        }
        pub fn put(self: *Self, key: Type) !void {
            try self.data.put(key, {});
        }
        pub fn contains(self: Self, key: Type) bool {
            return self.data.contains(key);
        }

        pub fn iterator(self: Self) Iterator {
            return .{
                .it = self.data.iterator(),
            };
        }
        pub fn intersection(self: Self, other: Self) IntersectIterator {
            return .{
                .it = self.data.iterator(),
                .other = other,
            };
        }
    };
}

fn lte(a: Node, b: Node) bool {
    return a[0] < b[0] or (a[0] == b[0] and a[1] <= b[1]);
}

test "lte" {
    try expect(lte(.{ 'b', 'b' }, .{ 'c', 'c' }));
    try expect(lte(.{ 'b', 'b' }, .{ 'b', 'c' }));
    try expect(lte(.{ 'b', 'b' }, .{ 'c', 'b' }));
    try expect(lte(.{ 'b', 'b' }, .{ 'c', 'a' }));
    try expect(lte(.{ 'b', 'b' }, .{ 'b', 'b' }));
    try expect(!lte(.{ 'b', 'b' }, .{ 'b', 'a' }));
    try expect(!lte(.{ 'b', 'b' }, .{ 'a', 'b' }));
    try expect(!lte(.{ 'b', 'b' }, .{ 'a', 'a' }));
}

const test_alloc = std.testing.allocator;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;
const expectEqualSlices = std.testing.expectEqualSlices;
const expectError = std.testing.expectError;

test "Set" {
    var set = Set(Node).init(test_alloc);
    defer set.deinit();

    try set.put(.{ 'a', 'b' });
    try set.put(.{ 'b', 'a' });
    try set.put(.{ 'c', 'a' });

    var set2 = Set(Node).init(test_alloc);
    defer set2.deinit();

    try set2.put(.{ 'b', 'a' });
    try set2.put(.{ 'x', 'y' });
    try set2.put(.{ 'a', 'b' });
    try set2.put(.{ 'c', 'c' });

    var it = set.intersection(set2);
    try expectEqual(.{ 'a', 'b' }, it.next().?);
    try expectEqual(.{ 'b', 'a' }, it.next().?);
    try expectEqual(null, it.next());
}
test "part1" {
    const input =
        \\kh-tc
        \\qp-kh
        \\de-cg
        \\ka-co
        \\yn-aq
        \\qp-ub
        \\cg-tb
        \\vc-aq
        \\tb-ka
        \\wh-tc
        \\yn-cg
        \\kh-ub
        \\ta-co
        \\de-co
        \\tc-td
        \\tb-wq
        \\wh-td
        \\ta-ka
        \\td-qp
        \\aq-cg
        \\wq-ub
        \\ub-vc
        \\de-ta
        \\wq-aq
        \\wq-vc
        \\wh-yn
        \\ka-de
        \\kh-ta
        \\co-tc
        \\wh-qp
        \\tb-vc
        \\td-yn
    ;

    try expectEqual(7, try part1(test_alloc, input));
}
test "part2" {
    const input =
        \\kh-tc
        \\qp-kh
        \\de-cg
        \\ka-co
        \\yn-aq
        \\qp-ub
        \\cg-tb
        \\vc-aq
        \\tb-ka
        \\wh-tc
        \\yn-cg
        \\kh-ub
        \\ta-co
        \\de-co
        \\tc-td
        \\tb-wq
        \\wh-td
        \\ta-ka
        \\td-qp
        \\aq-cg
        \\wq-ub
        \\ub-vc
        \\de-ta
        \\wq-aq
        \\wq-vc
        \\wh-yn
        \\ka-de
        \\kh-ta
        \\co-tc
        \\wh-qp
        \\tb-vc
        \\td-yn
    ;
    const ans = try part2(test_alloc, input);
    defer test_alloc.free(ans);
    try expectEqualStrings("co,de,ka,ta", ans);
}
