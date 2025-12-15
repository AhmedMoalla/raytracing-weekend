const std = @import("std");
const h = @import("hittables.zig");
const Camera = @import("Camera.zig");

const Hittable = h.Hittable;
const HittableList = h.HittableList;
const Sphere = h.Sphere;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();

    var world_list = try HittableList.init(allocator);
    try world_list.add(Sphere.init(.{ 0, -100.5, -1 }, 100));
    try world_list.add(Sphere.init(.{ 0, 0, -1 }, 0.5));
    const world: Hittable = .{ .list = world_list };

    var camera = Camera{
        .aspect_ratio = 16.0 / 9.0,
        .width = 400,
        .samples_per_pixel = 100,
    };
    try camera.render(&world);
}
