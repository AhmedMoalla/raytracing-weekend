const std = @import("std");
const utils = @import("utils.zig");
const vec = @import("vec3.zig");
const h = @import("hittables.zig");
const Ray = @import("Ray.zig");
const Interval = @import("Interval.zig");
const rand = @import("random.zig");

const as = utils.as;
const Vec3f = vec.Vec3f;
const Point = vec.Point;
const Color = vec.Color;

const s = vec.s;
const unit = vec.unit;

aspect_ratio: f64 = 1.0, // Ratio of image width over height
width: usize = 100, // Rendered image width in pixel count
height: usize = undefined, // Rendered image height

samples_per_pixel: usize = 10, // Count of random samples for each pixel
pixel_samples_scale: f64 = undefined, // Color scale factor for a sum of pixel samples
max_depth: usize = 10, //Maximum number of ray bounces into scene

center: Point = undefined, // Camera center
pixel00_location: Point = undefined, // Location of pixel 0, 0
pixel_delta_u: Vec3f = undefined, // Offset to pixel to the right
pixel_delta_v: Vec3f = undefined, // Offset to pixel below

pub fn render(self: *@This(), world: *const h.Hittable) !void {
    self.initialize();

    var stdout_buffer: [1024]u8 = std.mem.zeroes([1024]u8);
    var stdout_file = std.fs.File.stdout();
    var stdout_writer = stdout_file.writer(&stdout_buffer);
    var stdout = &stdout_writer.interface;

    try stdout.print("P3\n{d} {d}\n255\n", .{ self.width, self.height });

    var progress = std.Progress.start(.{ .root_name = "raycasting" });
    defer progress.end();
    const render_progress = progress.start("render scanlines", self.height);
    for (0..self.height) |y| {
        for (0..self.width) |x| {
            var pixel_color = Color{ 0, 0, 0 };
            for (0..self.samples_per_pixel) |_| {
                const ray = self.getRay(x, y);
                pixel_color += rayColor(ray, self.max_depth, world);
            }
            try writeColor(stdout, s(self.pixel_samples_scale) * pixel_color);
        }
        render_progress.completeOne();
    }
    render_progress.end();

    try stdout.flush();
}

fn initialize(self: *@This()) void {
    self.height = @max(1, as(usize, as(f64, self.width) / self.aspect_ratio));

    self.pixel_samples_scale = @as(f64, 1.0) / as(f64, self.samples_per_pixel);
    self.center = Point{ 0, 0, 0 };

    const focal_length: Vec3f = Vec3f{ 0.0, 0.0, 1.0 };
    const viewport_height: Vec3f = s(2.0);
    const viewport_width: Vec3f = @splat(viewport_height[0] * (as(f64, self.width) / as(f64, self.height)));

    const viewport_u = Vec3f{ viewport_width[0], 0, 0 };
    const viewport_v = Vec3f{ 0, -viewport_height[0], 0 };
    self.pixel_delta_u = viewport_u / s(self.width);
    self.pixel_delta_v = viewport_v / s(self.height);

    const viewport_top_left = self.center - focal_length - s(0.5) * (viewport_u + viewport_v);
    self.pixel00_location = viewport_top_left + s(0.5) * (self.pixel_delta_u + self.pixel_delta_v);
}

fn getRay(self: @This(), x: usize, y: usize) Ray {
    const xf64 = as(f64, x);
    const yf64 = as(f64, y);
    const x_offset, const y_offset, _ = rand.square(0.5);
    const pixel_sample = self.pixel00_location + //
        ((s(xf64 + x_offset) * self.pixel_delta_u) + //
            (s(yf64 + y_offset) * self.pixel_delta_v));
    const origin = self.center;
    const direction = pixel_sample - origin;
    return .init(origin, direction);
}

const @"[0.001,inf)": Interval = .{ .min = 0.001, .max = std.math.inf(f64) };

fn rayColor(ray: Ray, max_depth: usize, world: *const h.Hittable) vec.Color {
    // If we've exceeded the ray bounce limit, no more light is gathered.
    if (max_depth == 0) {
        return Color{ 0, 0, 0 };
    }

    if (world.hit(ray, @"[0.001,inf)")) |rec| {
        const direction = rec.normal + rand.unit();
        return s(0.5) * rayColor(
            Ray.init(rec.p, direction),
            max_depth - 1,
            world,
        );
    }

    const unit_direction = unit(ray.direction);
    const a: Vec3f = @splat(0.5 * (unit_direction[1] + 1.0));
    return (s(1.0) - a) * Color{ 1.0, 1.0, 1.0 } + a * Color{ 0.5, 0.7, 1.0 };
}

fn writeColor(writer: *std.io.Writer, color: Color) !void {
    var r, var g, var b = color;
    const intensity = Interval{ .min = 0, .max = 0.999 };

    // Apply a linear to gamma transform for gamma 2
    r = linearToGamma(r);
    g = linearToGamma(g);
    b = linearToGamma(b);

    // Translate the [0,1] component values to the byte range [0,255].
    const rbyte: i32 = @intFromFloat(256 * intensity.clamp(r));
    const gbyte: i32 = @intFromFloat(256 * intensity.clamp(g));
    const bbyte: i32 = @intFromFloat(256 * intensity.clamp(b));

    try writer.print("{d} {d} {d}\n", .{ rbyte, gbyte, bbyte });
}

fn linearToGamma(linear_component: f64) f64 {
    if (linear_component > 0) {
        return @sqrt(linear_component);
    }
    return 0;
}
