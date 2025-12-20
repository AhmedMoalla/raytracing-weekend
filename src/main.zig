const std = @import("std");
const h = @import("hittables.zig");
const Camera = @import("Camera.zig");
const rand = @import("random.zig");
const material = @import("materials.zig");
const vec = @import("vec3.zig");

const Color = vec.Color;

const Lambertian = material.Lambertian;
const Metal = material.Metal;
const Dielectric = material.Dielectric;

const Hittable = h.Hittable;
const HittableList = h.HittableList;
const Sphere = h.Sphere;

pub fn main() !void {
    rand.initGlobal();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();

    const material_ground = Lambertian.init(Color{ 0.8, 0.8, 0.0 });
    const material_center = Lambertian.init(Color{ 0.1, 0.2, 0.5 });
    const material_left = Dielectric.init(1.5);
    const material_bubble = Dielectric.init(1.0 / 1.5);
    const material_right = Metal.init(Color{ 0.8, 0.6, 0.2 }, 1.0);

    var world = try HittableList.init(allocator);
    try world.list.add(Sphere.init(.{ 0, -100.5, -1 }, 100, material_ground));
    try world.list.add(Sphere.init(.{ 0, 0, -1.2 }, 0.5, material_center));
    try world.list.add(Sphere.init(.{ -1, 0, -1 }, 0.5, material_left));
    try world.list.add(Sphere.init(.{ -1, 0, -1 }, 0.4, material_bubble));
    try world.list.add(Sphere.init(.{ 1, 0, -1 }, 0.5, material_right));

    var camera = Camera{
        .aspect_ratio = 16.0 / 9.0,
        .width = 400,
        .samples_per_pixel = 100,
        .max_depth = 50,
    };
    try camera.render(&world);
}
