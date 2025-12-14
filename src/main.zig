const std = @import("std");

const Vec3f = @Vector(3, f64);
const Color = Vec3f;
const Point = Vec3f;

const aspect_ratio: f64 = 16.0 / 9.0;
const width: usize = 400;

const height: usize = @max(1, as(usize, as(f64, width) / aspect_ratio));

pub fn main() !void {
    var stdout_buffer: [1024]u8 = std.mem.zeroes([1024]u8);
    var stdout_file = std.fs.File.stdout();
    var stdout_writer = stdout_file.writer(&stdout_buffer);
    var stdout = &stdout_writer.interface;

    const focal_length: Vec3f = Vec3f{ 0.0, 0.0, 1.0 };
    const viewport_height: Vec3f = s(2.0);
    const viewport_width: Vec3f = @splat(viewport_height[0] * (as(f64, width) / height));
    const camera_center = Point{ 0, 0, 0 };

    const viewport_u = Vec3f{ viewport_width[0], 0, 0 };
    const viewport_v = Vec3f{ 0, -viewport_height[0], 0 };
    const pixel_delta_u = viewport_u / s(width);
    const pixel_delta_v = viewport_v / s(height);

    const viewport_top_left = camera_center - focal_length - s(0.5) * (viewport_u + viewport_v);
    const pixel00_location = viewport_top_left + s(0.5) * (pixel_delta_u + pixel_delta_v);

    try stdout.print("P3\n{d} {d}\n255\n", .{ width, height });

    var progress = std.Progress.start(.{ .root_name = "raycasting" });
    defer progress.end();
    const render_progress = progress.start("render scanlines", height);
    for (0..height) |y| {
        for (0..width) |x| {
            const pixel_location = pixel00_location + (s(x) * pixel_delta_u) + (s(y) * pixel_delta_v);
            const direction = pixel_location - camera_center;
            const ray = Ray.init(camera_center, direction);
            const pixel_color = rayColor(ray);
            try writeColor(stdout, pixel_color);
        }
        render_progress.completeOne();
    }
    render_progress.end();

    try stdout.flush();
}

fn writeColor(writer: *std.io.Writer, color: Color) !void {
    const r, const g, const b = color;
    const ir: i32 = @intFromFloat(255.999 * r);
    const ig: i32 = @intFromFloat(255.999 * g);
    const ib: i32 = @intFromFloat(255.999 * b);

    try writer.print("{d} {d} {d}\n", .{ ir, ig, ib });
}

// Ray equation: P(t) = Q + t * d
// where:
// Q: origin
// d: direction
const Ray = struct {
    origin: Point,
    direction: Vec3f,

    pub fn init(origin: Point, direction: Vec3f) Ray {
        return .{
            .origin = origin,
            .direction = direction,
        };
    }

    pub fn at(self: Ray, t: f64) Point {
        return self.origin + t * self.direction;
    }
};

// Sphere x Ray intersection
// Sphere equation given
// - C: center of the sphere
// - r: radius of the sphere
// then every point on the sphere solves this equation:
//            (Cx - x)² + (Cy - y)²  + (Cz - z)²  = r²
// given P is the vector representing a point on a sphere then the equation becomes:
//           (Cx - Px)² + (Cy - Py)² + (Cz - Pz)² = r²
// it is known that (C - P) . (C - P) = (Cx - Px)² + (Cy - Py)² + (Cz - Pz)²
// the equation then becomes:
//                    (C - P) . (C - P)    = r²
// We want to know if a ray P(t) hits the sphere so this equation must be solved:
//                 (C - P(t)) . (C - P(t)) = r²
// with P(t) = Q + t * d
// the question becomes:
//            (C - (Q + t*d)) . (C - (Q + t*d)) = r²
//          (- t*d + (C - Q)) . (- t*d + (C - Q)) = r²                                 this: (a+b)(a+b)
//        t² * d.d + (C - Q) . (C - Q) - 2*t * d . (C - Q) = r²              distributes to this:  a²+b²+2ab
//       t² * d.d + (C - Q) . (C - Q) - 2*t * d . (C - Q) - r² = 0
// This is a quadratic equation in the form ax² + bx + c = 0 where x is t which solution is
//                      (-b ± √(b² - 4ac)) / 2a
// For the equation a, b and c are;
// a = d.d
// b = -2 * d . (C - Q)
// c = (C - Q) . (C - Q) - r²
// for these values the discriminant (b² - 4ac) can be either:
// negative: No solutions because √ is not solvable for negative numbers
// positive: Two solutions because of the ±.
//      - Solution 1: (-b + √(b² - 4ac)) / 2a
//      - Solution 2: (-b - √(b² - 4ac)) / 2a
// zero    : Exactly one solution: -b / 2a
// => The ray intersects with the sphere only if the discrimnant is positive or zero
fn hitSphere(center: Point, radius: f64, ray: Ray) bool {
    const oc = center - ray.origin;
    const a = dot(ray.direction, ray.direction);
    const b = -2.0 * dot(ray.direction, oc);
    const c = dot(oc, oc) - radius * radius;
    const discriminant = b * b - 4 * a * c;
    return discriminant >= 0;
}

fn rayColor(ray: Ray) Color {
    if (hitSphere(.{ 0, 0, -1 }, 0.5, ray)) {
        return .{ 1, 0, 0 };
    }

    const unit_direction = unit(ray.direction);
    const a: Vec3f = @splat(0.5 * (unit_direction[1] + 1.0));
    return (s(1.0) - a) * Color{ 1.0, 1.0, 1.0 } + a * Color{ 0.5, 0.7, 1.0 };
}

fn unit(vec: Vec3f) Vec3f {
    const len: Vec3f = @splat(@typeInfo(Vec3f).vector.len);
    return vec / len;
}

fn dot(u: Vec3f, v: Vec3f) f64 {
    return u[0] * v[0] + u[1] * v[1] + u[2] * v[2];
}

// Scalar
fn s(value: anytype) Vec3f {
    return as(Vec3f, value);
}

fn as(comptime to: type, value: anytype) to {
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
