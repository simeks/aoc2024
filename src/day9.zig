const std = @import("std");
const Allocator = std.mem.Allocator;

const assert = std.debug.assert;
const print = std.debug.print;
const parseInt = std.fmt.parseInt;
const isDigit = std.ascii.isDigit;

/// Part 1 without allocator
fn part1(input: []const u8) !usize {
    var checksum: usize = 0;
    var out_idx: usize = 0;
    var back_file: usize = @divFloor(input.len, 2);
    // Count blocks left in the current back file
    var blocks_left: usize = input[2 * back_file] - '0';

    for (0..input.len) |i| {
        if (2 * back_file < i) {
            break;
        }
        for (0..@intCast(input[i] - '0')) |_| {
            if (i % 2 == 0) {
                // Dance around to move blocks within the last file
                // if we are partially in.
                if (2 * back_file == i) {
                    if (blocks_left == 0) {
                        break;
                    }
                    blocks_left -= 1;
                }
                // Add current file to checksum
                checksum += out_idx * @divFloor(i, 2);
            } else {
                // Pick file from back and fill in slot
                // Block already had a chance to be moved

                if (blocks_left == 0) {
                    back_file -= 1;
                    blocks_left = input[2 * back_file] - '0';
                }
                blocks_left -= 1;

                checksum += out_idx * back_file;
            }
            out_idx += 1;
        }
    }

    return checksum;
}

fn part2(alloc: Allocator, input: []const u8) !usize {
    var blocks = std.ArrayList(struct { u32, u32 }).init(alloc);
    defer blocks.deinit();

    var block_offset: u32 = 0;
    for (input) |c| {
        const block_size: u32 = @intCast(c - '0');
        try blocks.append(.{ block_offset, block_size });
        block_offset += block_size;
    }

    var checksum: usize = 0;

    var file_idx: i32 = @intCast(blocks.items.len - 1);
    outer: while (file_idx >= 0) : (file_idx -= 2) {
        const file_offset, const file_size = blocks.items[@intCast(file_idx)];
        const file_id = @as(usize, @intCast(@divFloor(file_idx, 2)));

        var free_idx: i32 = 1;
        while (free_idx < file_idx) : (free_idx += 2) {
            const b_offset, const b_size = blocks.items[@intCast(free_idx)];

            if (file_size <= b_size) {
                for (b_offset..b_offset + file_size) |i| {
                    checksum += file_id * i;
                }
                blocks.items[@intCast(free_idx)] = .{
                    // Fill in block front to back
                    b_offset + file_size,
                    b_size - file_size,
                };
                continue :outer;
            }
        }
        // File not moved
        for (file_offset..file_offset + file_size) |i| {
            checksum += file_id * i;
        }
    }
    return checksum;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const input = std.mem.trimRight(u8, @embedFile("input/day9.txt"), "\n");

    const ans1 = try part1(input);
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
    const input = "2333133121414131402";
    try expectEqual(1928, try part1(input));
}
test "part2" {
    const input = "2333133121414131402";
    try expectEqual(2858, try part2(test_alloc, input));
}
