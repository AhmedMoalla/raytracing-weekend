const vec = @import("vec3.zig");
const Point = vec.Point;
const Vec3f = vec.Vec3f;

const s = vec.s;

const Ray = @This();

// Ray equation: P(t) = Q + t * d
// where:
// Q: origin
// d: direction

origin: Point,
direction: Vec3f,

pub fn init(origin: Point, direction: Vec3f) Ray {
    return .{
        .origin = origin,
        .direction = direction,
    };
}

pub fn at(self: Ray, t: f64) Point {
    return self.origin + s(t) * self.direction;
}
