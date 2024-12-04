const std = @import("std");
const Allocator = std.mem.Allocator;

const assert = std.debug.assert;
const print = std.debug.print;
const parseInt = std.fmt.parseInt;
const isDigit = std.ascii.isDigit;

/// Matrix backed by input data txt
const Mat = struct {
    width: usize,
    height: usize,
    data: []const u8,

    /// Keeps a refernce to given input slice
    pub fn init(input: []const u8) Mat {
        const width = std.mem.indexOfScalar(u8, input, '\n');
        assert(width != null);

        var height: usize = std.mem.count(u8, input, "\n");
        assert(height > 0);

        // If no trailing \n we need to add last row ourself
        if (input[input.len - 1] != '\n') {
            height += 1;
        }

        return .{
            .width = width.?,
            .height = height,
            .data = input,
        };
    }

    pub fn get(self: Mat, x: usize, y: usize) u8 {
        assert(x < self.width);
        assert(y < self.height);

        // +1 to account for \n
        return self.data[y * (self.width + 1) + x];
    }
};

/// Counts XMAS/SAMX starting at (x,y)
/// Checks directions: (x+, 0), (0, y+), (x+ y+), (x+, y-)
fn countXmasAt(mat: Mat, x: usize, y: usize) i32 {
    var count: i32 = 0;
    var window: [4]u8 = undefined;

    // x+
    if (x + 4 <= mat.width) {
        for (0..4) |i| {
            window[i] = mat.get(x + i, y);
        }
        if (std.mem.eql(u8, &window, "XMAS")) {
            count += 1;
        } else if (std.mem.eql(u8, &window, "SAMX")) {
            count += 1;
        }
    }

    // y+
    if (y + 4 <= mat.height) {
        for (0..4) |i| {
            window[i] = mat.get(x, y + i);
        }
        if (std.mem.eql(u8, &window, "XMAS")) {
            count += 1;
        } else if (std.mem.eql(u8, &window, "SAMX")) {
            count += 1;
        }
    }

    // x+, y+
    if (x + 4 <= mat.width and y + 4 <= mat.height) {
        for (0..4) |i| {
            window[i] = mat.get(x + i, y + i);
        }
        if (std.mem.eql(u8, &window, "XMAS")) {
            count += 1;
        } else if (std.mem.eql(u8, &window, "SAMX")) {
            count += 1;
        }
    }

    // x+, y-
    if (x + 4 <= mat.width and y >= 3) {
        for (0..4) |i| {
            window[i] = mat.get(x + i, y - i);
        }
        if (std.mem.eql(u8, &window, "XMAS")) {
            count += 1;
        } else if (std.mem.eql(u8, &window, "SAMX")) {
            count += 1;
        }
    }

    return count;
}

fn countXmas(input: []const u8) i32 {
    var count: i32 = 0;
    const mat = Mat.init(input);
    for (0..mat.height) |y| {
        for (0..mat.width) |x| {
            count += countXmasAt(mat, x, y);
        }
    }
    return count;
}

fn checkWindow(mat: Mat, x: usize, y: usize) bool {
    // aa .  ac
    // .  bb .
    // ca .  cc
    const aa = mat.get(x, y);
    const ac = mat.get(x + 2, y);
    const bb = mat.get(x + 1, y + 1);
    const ca = mat.get(x, y + 2);
    const cc = mat.get(x + 2, y + 2);

    // M . S
    // . A .
    // M . S
    if ('M' == aa and
        'S' == ac and
        'A' == bb and
        'M' == ca and
        'S' == cc)
    {
        return true;
    }

    // S . M
    // . A .
    // S . M
    if ('S' == aa and
        'M' == ac and
        'A' == bb and
        'S' == ca and
        'M' == cc)
    {
        return true;
    }

    // S . S
    // . A .
    // M . M
    if ('S' == aa and
        'S' == ac and
        'A' == bb and
        'M' == ca and
        'M' == cc)
    {
        return true;
    }

    // M . M
    // . A .
    // S . S
    if ('M' == aa and
        'M' == ac and
        'A' == bb and
        'S' == ca and
        'S' == cc)
    {
        return true;
    }

    return false;
}

fn countXmas2(input: []const u8) i32 {
    const mat = Mat.init(input);
    const window_size = 3;

    var count: i32 = 0;
    for (0..mat.height - window_size + 1) |y| {
        for (0..mat.width - window_size + 1) |x| {
            count += if (checkWindow(mat, x, y)) 1 else 0;
        }
    }
    return count;
}

pub fn main() !void {
    const input = @embedFile("input/day4.txt");
    print("XMAS: {d}\n", .{countXmas(input)});
    print("X-MAS: {d}\n", .{countXmas2(input)});
}

const test_alloc = std.testing.allocator;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;
const expectError = std.testing.expectError;

test "part1" {
    const input =
        \\MMMSXXMASM
        \\MSAMXMSMSA
        \\AMXSXMAAMM
        \\MSAMASMSMX
        \\XMASAMXAMM
        \\XXAMMXXAMA
        \\SMSMSASXSS
        \\SAXAMASAAA
        \\MAMMMXMMMM
        \\MXMXAXMASX
    ;
    try expectEqual(18, countXmas(input));
}
test "part2" {
    const input =
        \\MMMSXXMASM
        \\MSAMXMSMSA
        \\AMXSXMAAMM
        \\MSAMASMSMX
        \\XMASAMXAMM
        \\XXAMMXXAMA
        \\SMSMSASXSS
        \\SAXAMASAAA
        \\MAMMMXMMMM
        \\MXMXAXMASX
    ;
    try expectEqual(9, countXmas2(input));
}
