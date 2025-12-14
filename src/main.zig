const std = @import("std");
const vec = @import("vec3.zig");
const utils = @import("utils.zig");
const Ray = @import("Ray.zig");
const Interval = @import("Interval.zig");
const h = @import("hittables.zig");

const Hittable = h.Hittable;
const HittableList = h.HittableList;
const Sphere = h.Sphere;

const as = utils.as;
const Vec3f = vec.Vec3f;
const Point = vec.Point;
const Color = vec.Color;

const s = vec.s;
const dot = vec.dot;
const unit = vec.unit;
const len = vec.len;
const len_squared = vec.len_squared;

const aspect_ratio: f64 = 16.0 / 9.0;
const width: usize = 400;

const height: usize = @max(1, as(usize, as(f64, width) / aspect_ratio));

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();

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

    var world_list = try HittableList.init(allocator);
    try world_list.add(Sphere.init(.{ 0, -100.5, -1 }, 100));
    try world_list.add(Sphere.init(.{ 0, 0, -1 }, 0.5));
    var world: Hittable = .{ .list = world_list };

    try stdout.print("P3\n{d} {d}\n255\n", .{ width, height });

    var progress = std.Progress.start(.{ .root_name = "raycasting" });
    defer progress.end();
    const render_progress = progress.start("render scanlines", height);
    for (0..height) |y| {
        for (0..width) |x| {
            const pixel_location = pixel00_location + (s(x) * pixel_delta_u) + (s(y) * pixel_delta_v);
            const direction = pixel_location - camera_center;
            const ray = Ray.init(camera_center, direction);
            const pixel_color = rayColor(ray, &world);
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

fn rayColor(ray: Ray, world: *Hittable) Color {
    if (world.hit(ray, .{ .min = 0, .max = std.math.inf(f64) })) |rec| {
        return s(0.5) * (rec.normal + Color{ 1, 1, 1 });
    }

    const unit_direction = unit(ray.direction);
    const a: Vec3f = @splat(0.5 * (unit_direction[1] + 1.0));
    return (s(1.0) - a) * Color{ 1.0, 1.0, 1.0 } + a * Color{ 0.5, 0.7, 1.0 };
}
