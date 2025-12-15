const std = @import("std");

const Interval = @This();

pub const empty: Interval = .{
    .min = std.math.inf(f64),
    .max = -std.math.inf(f64),
};

pub const universe: Interval = .{
    .min = -std.math.inf(f64),
    .max = std.math.inf(f64),
};

min: f64 = std.math.inf(f64),
max: f64 = -std.math.inf(f64),

pub fn size(self: @This()) f64 {
    return self.max - self.min;
}

pub fn contains(self: @This(), x: f64) bool {
    return self.min <= x and x <= self.max;
}

pub fn surrounds(self: @This(), x: f64) bool {
    return self.min < x and x < self.max;
}

pub fn clamp(self: @This(), x: f64) f64 {
    if (x < self.min) return self.min;
    if (x > self.max) return self.max;
    return x;
}
