const utils = @import("utils.zig");

pub const Vec3f = @Vector(3, f64);
pub const Color = Vec3f;
pub const Point = Vec3f;

pub fn unit(vec: Vec3f) Vec3f {
    return vec / s(len(vec));
}

pub fn dot(u: Vec3f, v: Vec3f) f64 {
    return u[0] * v[0] + u[1] * v[1] + u[2] * v[2];
}

pub fn len(v: anytype) f64 {
    return @sqrt(len_squared(v));
}

pub fn len_squared(v: anytype) f64 {
    return v[0] * v[0] + v[1] * v[1] + v[2] * v[2];
}

pub fn nearZero(vec: Vec3f) bool {
    const epsilon: f64 = 1e-8;
    return @reduce(.And, @abs(vec) < s(epsilon));
}

pub fn reflect(vec: Vec3f, normal: Vec3f) Vec3f {
    return vec - s(2) * s(dot(vec, normal)) * normal;
}

// Scalar
pub fn s(value: anytype) Vec3f {
    return utils.as(Vec3f, value);
}
