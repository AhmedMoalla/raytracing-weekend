const std = @import("std");
const v = @import("vec3.zig");
const Vec3f = v.Vec3f;

var prng: std.Random.Xoshiro256 = undefined;
pub var rand: std.Random = undefined;

pub fn initGlobal() void {
    var seed: u64 = undefined;
    std.posix.getrandom(std.mem.asBytes(&seed)) catch unreachable;
    prng = std.Random.DefaultPrng.init(seed);
    rand = prng.random();
}

pub fn float() f64 {
    return rand.float(f64);
}

pub fn floatRange(min: f64, max: f64) f64 {
    return min + (max - min) * float();
}

pub fn square(offset: f64) Vec3f {
    return .{
        float() - offset,
        float() - offset,
        0,
    };
}

pub fn vec3f() Vec3f {
    return Vec3f{ float(), float(), float() };
}

pub fn vec3fRange(min: f64, max: f64) Vec3f {
    return Vec3f{
        floatRange(min, max),
        floatRange(min, max),
        floatRange(min, max),
    };
}

pub fn unit() Vec3f {
    while (true) {
        const vec = vec3fRange(-1, 1);
        const len_sq = v.len_squared(vec);
        if (1e-160 < len_sq and len_sq <= 1) {
            return vec / v.s(@sqrt(len_sq));
        }
    }
}

pub fn hemisphere(normal: Vec3f) Vec3f {
    const on_unit_sphere = unit();
    if (v.dot(on_unit_sphere, normal) > 0) { // In the same hemisphere as the normal
        return on_unit_sphere;
    } else {
        return -on_unit_sphere;
    }
}
