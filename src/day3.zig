const std = @import("std");
const Allocator = std.mem.Allocator;

const assert = std.debug.assert;
const print = std.debug.print;
const parseInt = std.fmt.parseInt;
const isDigit = std.ascii.isDigit;

/// Fixed buffer reader for strings
pub const Reader = struct {
    buffer: []const u8,
    pos: usize = 0,

    pub fn eof(self: Reader) bool {
        return self.pos >= self.buffer.len;
    }

    /// Peek at next n bytes
    pub fn peek(self: *Reader, n: usize) ![]const u8 {
        if (self.pos + n > self.buffer.len) {
            return error.OutOfBounds;
        }
        return self.buffer[self.pos .. self.pos + n];
    }
    /// Skip n bytes
    pub fn skip(self: *Reader, n: usize) !void {
        if (self.pos + n > self.buffer.len) {
            return error.OutOfBounds;
        }
        self.pos += n;
    }
    /// Reads full int starting at pos
    pub fn readInt(self: *Reader) !i32 {
        var end = self.pos;
        while (isDigit(self.buffer[end]) and end < self.buffer.len) : (end += 1) {}

        if (end == self.pos) {
            return error.NotANumber;
        }

        const x = try parseInt(i32, self.buffer[self.pos..end], 10);
        self.pos = end;

        return x;
    }
    /// Reads until the given char is encountered
    /// error.Eof if char not found
    pub fn readUntil(self: *Reader, char: u8) ![]const u8 {
        const start = self.pos;
        var end = start;
        while (end < self.buffer.len and self.buffer[end] != char) : (end += 1) {}
        if (end == self.buffer.len) {
            return error.Eof;
        }
        self.pos = end;
        return self.buffer[start..end];
    }
    /// If next char in buffer is char, read it, if not, keep pos intact and
    /// return error
    pub fn ensureRead(self: *Reader, char: u8) !void {
        if ((try self.peek(1))[0] != char) {
            return error.EnsureFailed;
        }
        try self.skip(1);
    }
};

fn parseMul(reader: *Reader) !i32 {
    try reader.ensureRead('(');
    const a = try reader.readInt();
    try reader.ensureRead(',');
    const b = try reader.readInt();
    try reader.ensureRead(')');
    return a * b;
}
fn parseDo(reader: *Reader) !void {
    try reader.ensureRead('(');
    try reader.ensureRead(')');
}
fn parseDont(reader: *Reader) !void {
    try reader.ensureRead('(');
    try reader.ensureRead(')');
}

pub fn runString(str: []const u8) i32 {
    const Op = enum {
        find_op,
        mul,
        do,
        dont,
    };

    // Comptime!
    const functions = .{
        .{ "mul", Op.mul },
        .{ "do", Op.do },
        .{ "don't", Op.dont },
    };

    var sum: i32 = 0;
    var do = true;

    var reader: Reader = .{
        .buffer = str,
    };
    sw: switch (@as(Op, .find_op)) {
        .find_op => {
            const op_str = reader.readUntil('(') catch {
                // eof
                break :sw;
            };

            inline for (functions) |f| {
                const name, const op = f;
                if (std.mem.endsWith(u8, op_str, name)) {
                    continue :sw op;
                }
            }

            // skip '(' and look for next op
            reader.skip(1) catch {
                // eof
                break :sw;
            };
            continue :sw .find_op;
        },
        .mul => {
            const val = parseMul(&reader) catch continue :sw .find_op;
            if (do) {
                sum += val;
            }
            continue :sw .find_op;
        },
        .do => {
            parseDo(&reader) catch continue :sw .find_op;
            do = true;
            continue :sw .find_op;
        },
        .dont => {
            parseDont(&reader) catch continue :sw .find_op;
            do = false;
            continue :sw .find_op;
        },
    }
    return sum;
}

pub fn main() !void {
    const input = @embedFile("input/day3.txt");
    const res = runString(input);
    print("Result: {d}\n", .{res});
}

const test_alloc = std.testing.allocator;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;
const expectError = std.testing.expectError;

test "runString" {
    const input1 = "xmul(2,4)%&mul[3,7]!@^do_not_mul(5,5)+mul(32,64]then(mul(11,8)mul(8,5))";
    try expectEqual(161, runString(input1));
    const input2 = "xmul(2,4)&mul[3,7]!^don't()_mul(5,5)+mul(32,64](mul(11,8)undo()?mul(8,5))";
    try expectEqual(48, runString(input2));
}

test "Reader" {
    const buf = "aaasd(1234,4321)qwerty()asd";
    var reader: Reader = .{
        .buffer = buf,
    };

    // aaasd
    try expect(!reader.eof());
    try expectEqualStrings("aaa", try reader.peek(3));
    try expectError(error.NotANumber, reader.readInt());

    // aaasd(1234,4321)
    try expectEqualStrings("aaasd", try reader.readUntil('('));
    try reader.skip(1);
    try expectEqual(1234, try reader.readInt());
    try reader.ensureRead(',');
    try expectError(error.EnsureFailed, reader.ensureRead(','));
    try expectEqual(4321, try reader.readInt());
    try reader.skip(1);

    // qwerty()
    try expectEqualStrings("qwerty", try reader.readUntil('('));
    try reader.ensureRead('(');
    try reader.skip(1);

    try expectError(error.Eof, reader.readUntil('('));
    try expect(!reader.eof());

    // as
    try reader.skip(2);
    // d
    try expectEqualStrings("d", try reader.peek(1));
    try reader.skip(1);

    try expect(reader.eof());
    try expectError(error.OutOfBounds, reader.peek(1));
    try expectError(error.OutOfBounds, reader.skip(1));
}
