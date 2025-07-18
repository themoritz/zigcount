const std = @import("std");

const MAX_PRECISION = 9;

pub const Number = struct {
    value: i64,
    /// Number of decimal places
    precision: u32,

    pub fn fromFloat(f: f64) Number {
        if (f == 0.0) {
            return Number{ .value = 0, .precision = 0 };
        }
        var precision: u32 = 0;
        var scaled = f;
        var rounded = std.math.round(scaled);
        while (precision < MAX_PRECISION) {
            if (std.math.approxEqAbs(f64, scaled, rounded, 1e-9)) break;
            scaled *= 10;
            precision += 1;
            rounded = std.math.round(scaled);
        }
        return Number{
            .value = @intFromFloat(rounded),
            .precision = precision,
        };
    }

    pub fn fromInt(i: i64) Number {
        return Number{ .value = i, .precision = 0 };
    }

    pub fn fromSlice(bytes: []const u8) std.fmt.ParseIntError!Number {
        std.debug.assert(bytes.len <= 64);
        var buf: [64]u8 = undefined;
        var j: usize = 0;
        var precision: u32 = 0;
        var seen_dot = false;
        for (bytes) |b| {
            switch (b) {
                ',' => {},
                '.' => seen_dot = true,
                else => {
                    buf[j] = b;
                    j += 1;
                    if (seen_dot) precision += 1;
                    if (precision == MAX_PRECISION) break;
                },
            }
        }
        const cleaned_bytes = buf[0..j];
        return Number{
            .value = try std.fmt.parseInt(i64, cleaned_bytes, 10),
            .precision = precision,
        };
    }

    pub fn toFloat(self: Number) f64 {
        const scaled: f64 = @floatFromInt(self.value);
        const divisor: f64 = @floatFromInt(pow10(self.precision));
        return scaled / divisor;
    }

    pub fn add(self: Number, other: Number) Number {
        const p = @max(self.precision, other.precision);
        const self_factor = if (self.precision < p) pow10(p - self.precision) else 1;
        const other_factor = if (other.precision < p) pow10(p - other.precision) else 1;
        const self_scaled = self.value * self_factor;
        const other_scaled = other.value * other_factor;
        return Number{
            .value = self_scaled + other_scaled,
            .precision = p,
        };
    }

    pub fn sub(self: Number, other: Number) Number {
        const p = @max(self.precision, other.precision);
        const self_factor = if (self.precision < p) pow10(p - self.precision) else 1;
        const other_factor = if (other.precision < p) pow10(p - other.precision) else 1;
        const self_scaled = self.value * self_factor;
        const other_scaled = other.value * other_factor;
        return Number{
            .value = self_scaled - other_scaled,
            .precision = p,
        };
    }

    pub fn mul(self: Number, other: Number) Number {
        return Number{
            .value = self.value * other.value,
            .precision = self.precision + other.precision,
        };
    }

    pub fn negate(self: Number) Number {
        return Number{ .value = -self.value, .precision = self.precision };
    }

    pub fn div(self: Number, other: Number) !Number {
        if (other.value == 0) return error.DivisionByZero;
        const self_float = self.toFloat();
        const other_float = other.toFloat();
        return Number.fromFloat(self_float / other_float);
    }

    pub fn toString(self: Number, allocator: std.mem.Allocator) ![]const u8 {
        const float_val = self.toFloat();

        var buf: [64]u8 = undefined;
        const used = try std.fmt.formatFloat(&buf, float_val, .{
            .mode = .decimal,
            .precision = self.precision,
        });
        return try allocator.dupe(u8, used);
    }

    pub fn format(self: Number, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        const float_val = self.toFloat();
        var buf: [64]u8 = undefined;
        const used = std.fmt.formatFloat(&buf, float_val, .{
            .mode = .decimal,
            .precision = self.precision,
        }) catch "[too many digits]";
        try std.fmt.format(writer, "{s}", .{used});
    }

    pub fn zero() Number {
        return Number{
            .value = 0,
            .precision = 0,
        };
    }

    pub fn is_zero(self: Number) bool {
        return self.value == 0;
    }
};

fn pow10(n: u32) i64 {
    var result: i64 = 1;
    for (0..n) |_| {
        result *= 10;
    }
    return result;
}

test Number {
    const alloc = std.testing.allocator;

    try std.testing.expectEqual(Number.fromFloat(1.13), try Number.fromSlice("1.13"));

    const a = Number.fromFloat(1.2345);
    const b = Number.fromFloat(2);

    const a_str = try a.toString(alloc);
    const b_str = try b.toString(alloc);
    defer alloc.free(a_str);
    defer alloc.free(b_str);

    try std.testing.expectEqualStrings("1.2345", a_str);
    try std.testing.expectEqualStrings("2", b_str);

    try std.testing.expectEqual(Number.fromFloat(3.2345), a.add(b));
    try std.testing.expectEqual(Number.fromFloat(-0.7655), a.sub(b));

    try std.testing.expectEqual(Number.fromFloat(2.25), Number.fromFloat(1.5).mul(Number.fromFloat(1.5)));
    try std.testing.expectEqual(Number.fromFloat(0.142857143), Number.fromInt(1).div(Number.fromInt(7)));

    try std.testing.expectEqual(Number.fromFloat(123456.4), try Number.fromSlice("123,456.4"));
}
