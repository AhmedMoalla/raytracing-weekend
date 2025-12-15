const std = @import("std");
const utils = @import("utils.zig");
const vec = @import("vec3.zig");
const h = @import("hittables.zig");
const Ray = @import("Ray.zig");
const Interval = @import("Interval.zig");

const as = utils.as;
const Vec3f = vec.Vec3f;
const Point = vec.Point;
const Color = vec.Color;

const s = vec.s;
const unit = vec.unit;
prng: std.Random = undefined,

aspect_ratio: f64 = 1.0, // Ratio of image width over height
width: usize = 100, // Rendered image width in pixel count
height: usize = undefined, // Rendered image height

samples_per_pixel: usize = 10, // Count of random samples for each pixel
pixel_samples_scale: f64 = undefined, // Color scale factor for a sum of pixel samples

center: Point = undefined, // Camera center
pixel00_location: Point = undefined, // Location of pixel 0, 0
pixel_delta_u: Vec3f = undefined, // Offset to pixel to the right
pixel_delta_v: Vec3f = undefined, // Offset to pixel below

pub fn render(self: *@This(), world: *const h.Hittable) !void {
    self.initialize();

    var seed: u64 = undefined;
    std.posix.getrandom(std.mem.asBytes(&seed)) catch unreachable;
    var p = std.Random.DefaultPrng.init(seed);
    self.prng = p.random();

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
                pixel_color += rayColor(ray, world);
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
    const x_offset, const y_offset, _ = randomSquare(self.prng);
    const pixel_sample = self.pixel00_location + //
        ((s(xf64 + x_offset) * self.pixel_delta_u) + //
            (s(yf64 + y_offset) * self.pixel_delta_v));
    const origin = self.center;
    const direction = pixel_sample - origin;
    return .init(origin, direction);
}

fn randomSquare(prng: std.Random) Vec3f {
    return .{
        prng.float(f64) - 0.5,
        prng.float(f64) - 0.5,
        0,
    };
}

fn rayColor(ray: Ray, world: *const h.Hittable) vec.Color {
    if (world.hit(ray, .{ .min = 0, .max = std.math.inf(f64) })) |rec| {
        return s(0.5) * (rec.normal + vec.Color{ 1, 1, 1 });
    }

    const unit_direction = unit(ray.direction);
    const a: Vec3f = @splat(0.5 * (unit_direction[1] + 1.0));
    return (s(1.0) - a) * Color{ 1.0, 1.0, 1.0 } + a * Color{ 0.5, 0.7, 1.0 };
}

fn writeColor(writer: *std.io.Writer, color: Color) !void {
    const r, const g, const b = color;
    const intensity = Interval{ .min = 0, .max = 0.999 };
    const rbyte: i32 = @intFromFloat(256 * intensity.clamp(r));
    const gbyte: i32 = @intFromFloat(256 * intensity.clamp(g));
    const bbyte: i32 = @intFromFloat(256 * intensity.clamp(b));

    try writer.print("{d} {d} {d}\n", .{ rbyte, gbyte, bbyte });
}
