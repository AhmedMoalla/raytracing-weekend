pub fn as(comptime to: type, value: anytype) to {
    const to_info = @typeInfo(to);
    return switch (@typeInfo(@TypeOf(value))) {
        .int, .comptime_int => switch (to_info) {
            .float, .comptime_float => @as(to, @floatFromInt(value)),
            .vector => |vec| @as(@Vector(vec.len, vec.child), @splat(as(vec.child, value))),
            .int, .comptime_int => value,
            else => unreachable,
        },
        .float, .comptime_float => switch (to_info) {
            .int, .comptime_int => @as(to, @intFromFloat(value)),
            .vector => |vec| @as(@Vector(vec.len, vec.child), @splat(as(vec.child, value))),
            .float, .comptime_float => value,
            else => unreachable,
        },
        else => unreachable,
    };
}
