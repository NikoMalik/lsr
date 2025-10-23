//! This file is a port of C implementaion that can be found here
//! https://github.com/sourcefrog/natsort.
const std = @import("std");
const isSpace = std.ascii.isWhitespace;
const isDigit = std.ascii.isDigit;
const Order = std.math.Order;
const testing = std.testing;

pub inline fn order(a: []const u8, b: []const u8) Order {
    return natOrder(a, b, false);
}

pub inline fn orderIgnoreCase(a: []const u8, b: []const u8) Order {
    return natOrder(a, b, true);
}

inline fn natOrder(a: []const u8, b: []const u8, comptime fold_case: bool) Order {
    var ai: usize = 0;
    var bi: usize = 0;
    const a_len = a.len;
    const b_len = b.len;

    while (true) {
        while (ai < a_len and isSpace(a[ai])) ai += 1;
        while (bi < b_len and isSpace(b[bi])) bi += 1;

        const ca = if (ai < a_len) a[ai] else 0;
        const cb = if (bi < b_len) b[bi] else 0;

        if (isDigit(ca) and isDigit(cb)) {
            const result = compareNumbers(a[ai..], b[bi..]);
            if (result != .eq) return result;

            while (ai < a_len and isDigit(a[ai])) ai += 1;
            while (bi < b_len and isDigit(b[bi])) bi += 1;
            continue;
        }

        if (ca == 0 and cb == 0) return .eq;

        const cmp_ca = if (fold_case) toUpper(ca) else ca;
        const cmp_cb = if (fold_case) toUpper(cb) else cb;

        if (cmp_ca < cmp_cb) return .lt;
        if (cmp_ca > cmp_cb) return .gt;

        ai += 1;
        bi += 1;
    }
}

const SortContext = struct {
    ignore_case: bool = false,
    reverse: bool = false,

    inline fn compare(self: @This(), a: []const u8, b: []const u8) bool {
        const ord: std.math.Order = if (self.reverse) .gt else .lt;
        if (self.ignore_case) {
            return orderIgnoreCase(a, b) == ord;
        } else {
            return order(a, b) == ord;
        }
    }
};

inline fn compareNumbers(a: []const u8, b: []const u8) Order {
    var i: usize = 0;
    const a_len = a.len;
    const b_len = b.len;

    const a_has_leading_zero = a_len > 0 and a[0] == '0';
    const b_has_leading_zero = b_len > 0 and b[0] == '0';

    if (a_has_leading_zero or b_has_leading_zero) {
        while (i < a_len and i < b_len) {
            const ca = a[i];
            const cb = b[i];

            if (!isDigit(ca) or !isDigit(cb)) {
                if (!isDigit(ca) and !isDigit(cb)) return .eq;
                return if (!isDigit(ca)) .lt else .gt;
            }

            if (ca < cb) return .lt;
            if (ca > cb) return .gt;

            i += 1;
        }

        if (i < a_len and isDigit(a[i])) return .gt;
        if (i < b_len and isDigit(b[i])) return .lt;
        return .eq;
    }

    var num_a: u64 = 0;
    var num_b: u64 = 0;
    var len_a: usize = 0;
    var len_b: usize = 0;

    while (i < a_len and isDigit(a[i])) {
        if (len_a < 18) {
            num_a = num_a * 10 + (a[i] - '0');
        }
        len_a += 1;
        i += 1;
    }

    i = 0;
    while (i < b_len and isDigit(b[i])) {
        if (len_b < 18) {
            num_b = num_b * 10 + (b[i] - '0');
        }
        len_b += 1;
        i += 1;
    }

    if (len_a < len_b) return .lt;
    if (len_a > len_b) return .gt;

    if (num_a < num_b) return .lt;
    if (num_a > num_b) return .gt;

    return .eq;
}

test "lt" {
    try testing.expectEqual(Order.lt, order("a_1", "a_10"));
}

test "eq" {
    try testing.expectEqual(Order.eq, order("a_1", "a_1"));
}

test "gt" {
    try testing.expectEqual(Order.gt, order("a_10", "a_1"));
}

fn sortAndAssert(context: SortContext, input: [][]const u8, want: []const []const u8) !void {
    pdq([]const u8, input, context, SortContext.compare);

    for (input, want) |actual, expected| {
        try testing.expectEqualStrings(expected, actual);
    }
}

test "sorting" {
    const context = SortContext{};
    var items = [_][]const u8{
        "item100",
        "item10",
        "item1",
    };
    const want = [_][]const u8{
        "item1",
        "item10",
        "item100",
    };

    try sortAndAssert(context, &items, &want);
}

test "sorting 2" {
    const context = SortContext{};
    var items = [_][]const u8{
        "item_30",
        "item_15",
        "item_3",
        "item_2",
        "item_10",
    };
    const want = [_][]const u8{
        "item_2",
        "item_3",
        "item_10",
        "item_15",
        "item_30",
    };

    try sortAndAssert(context, &items, &want);
}

test "leading zeros" {
    const context = SortContext{};
    var items = [_][]const u8{
        "item100",
        "item999",
        "item001",
        "item010",
        "item000",
    };
    const want = [_][]const u8{
        "item000",
        "item001",
        "item010",
        "item100",
        "item999",
    };

    try sortAndAssert(context, &items, &want);
}

test "dates" {
    const context = SortContext{};
    var items = [_][]const u8{
        "2000-1-10",
        "2000-1-2",
        "1999-12-25",
        "2000-3-23",
        "1999-3-3",
    };
    const want = [_][]const u8{
        "1999-3-3",
        "1999-12-25",
        "2000-1-2",
        "2000-1-10",
        "2000-3-23",
    };

    try sortAndAssert(context, &items, &want);
}

test "fractions" {
    const context = SortContext{};
    var items = [_][]const u8{
        "Fractional release numbers",
        "1.011.02",
        "1.010.12",
        "1.009.02",
        "1.009.20",
        "1.009.10",
        "1.002.08",
        "1.002.03",
        "1.002.01",
    };
    const want = [_][]const u8{
        "1.002.01",
        "1.002.03",
        "1.002.08",
        "1.009.02",
        "1.009.10",
        "1.009.20",
        "1.010.12",
        "1.011.02",
        "Fractional release numbers",
    };

    try sortAndAssert(context, &items, &want);
}

test "words" {
    const context = SortContext{};
    var items = [_][]const u8{
        "fred",
        "pic2",
        "pic100a",
        "pic120",
        "pic121",
        "jane",
        "tom",
        "pic02a",
        "pic3",
        "pic4",
        "1-20",
        "pic100",
        "pic02000",
        "10-20",
        "1-02",
        "1-2",
        "x2-y7",
        "x8-y8",
        "x2-y08",
        "x2-g8",
        "pic01",
        "pic02",
        "pic 6",
        "pic   7",
        "pic 5",
        "pic05",
        "pic 5 ",
        "pic 5 something",
        "pic 4 else",
    };
    const want = [_][]const u8{
        "1-02",
        "1-2",
        "1-20",
        "10-20",
        "fred",
        "jane",
        "pic01",
        "pic02",
        "pic02a",
        "pic02000",
        "pic05",
        "pic2",
        "pic3",
        "pic4",
        "pic 4 else",
        "pic 5",
        "pic 5 ",
        "pic 5 something",
        "pic 6",
        "pic   7",
        "pic100",
        "pic100a",
        "pic120",
        "pic121",
        "tom",
        "x2-g8",
        "x2-y08",
        "x2-y7",
        "x8-y8",
    };

    try sortAndAssert(context, &items, &want);
}

test "fuzz" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;

            const a = input[0..(input.len / 2)];
            const b = input[(input.len / 2)..];
            _ = order(a, b);
        }
    };

    try std.testing.fuzz(Context{}, Context.testOne, .{});
}

const upper_table: [256]u8 = blk: {
    var table: [256]u8 = undefined;
    for (0..256) |i| {
        table[i] = if (i >= 'a' and i <= 'z') @intCast(i - 32) else @intCast(i);
    }
    break :blk table;
};

inline fn toUpper(c: u8) u8 {
    return upper_table[c];
}

pub fn pdq(
    comptime T: type,
    items: []T,
    context: anytype,
    comptime lessThanFn: fn (context: @TypeOf(context), lhs: T, rhs: T) callconv(.@"inline") bool,
) void {
    const Context = struct {
        items: []T,
        sub_ctx: @TypeOf(context),

        pub inline fn lessThan(ctx: @This(), a: usize, b: usize) bool {
            return lessThanFn(ctx.sub_ctx, ctx.items[a], ctx.items[b]);
        }

        pub inline fn swap(ctx: @This(), a: usize, b: usize) void {
            return std.mem.swap(T, &ctx.items[a], &ctx.items[b]);
        }
    };

    std.sort.pdqContext(0, items.len, Context{ .items = items, .sub_ctx = context });
}
