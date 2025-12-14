const std = @import("std");

const Vec3f = @Vector(3, f64);
const Color = Vec3f;
const Point = Vec3f;

const aspect_ratio: f64 = 16.0 / 9.0;
const width: usize = 400;

const height: usize = @max(1, as(usize, as(f64, width) / aspect_ratio));

const half = @as(Vec3f, @splat(0.5));
const one = as(Vec3f, 1.0);

pub fn main() !void {
    var stdout_buffer: [1024]u8 = std.mem.zeroes([1024]u8);
    var stdout_file = std.fs.File.stdout();
    var stdout_writer = stdout_file.writer(&stdout_buffer);
    var stdout = &stdout_writer.interface;

    const focal_length: Vec3f = Vec3f{ 0.0, 0.0, 1.0 };
    const viewport_height: Vec3f = @splat(2.0);
    const viewport_width: Vec3f = @splat(viewport_height[0] * (as(f64, width) / height));
    const camera_center = Point{ 0, 0, 0 };

    const viewport_u = Vec3f{ viewport_width[0], 0, 0 };
    const viewport_v = Vec3f{ 0, -viewport_height[0], 0 };
    const pixel_delta_u = viewport_u / @as(Vec3f, @splat(width));
    const pixel_delta_v = viewport_v / @as(Vec3f, @splat(height));

    const viewport_top_left = camera_center - focal_length - half * (viewport_u + viewport_v);
    const pixel00_location = viewport_top_left + half * (pixel_delta_u + pixel_delta_v);

    try stdout.print("P3\n{d} {d}\n255\n", .{ width, height });

    var progress = std.Progress.start(.{ .root_name = "raycasting" });
    defer progress.end();
    const render_progress = progress.start("render scanlines", height);
    for (0..height) |y| {
        for (0..width) |x| {
            const pixel_location = pixel00_location + (as(Vec3f, x) * pixel_delta_u) + (as(Vec3f, y) * pixel_delta_v);
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

fn rayColor(ray: Ray) Color {
    const unit_direction = unit(ray.direction);
    const a: Vec3f = @splat(0.5 * (unit_direction[1] + 1.0));
    return (one - a) * Color{ 1.0, 1.0, 1.0 } + a * Color{ 0.5, 0.7, 1.0 };
}

fn unit(vec: Vec3f) Vec3f {
    const len: Vec3f = @splat(@typeInfo(Vec3f).vector.len);
    return vec / len;
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
