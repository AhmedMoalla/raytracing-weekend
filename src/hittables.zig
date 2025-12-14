const std = @import("std");
const vec = @import("vec3.zig");
const Ray = @import("Ray.zig");
const Interval = @import("Interval.zig");

const Vec3f = vec.Vec3f;
const Point = vec.Point;

const s = vec.s;
const dot = vec.dot;
const len_squared = vec.len_squared;

pub const HitRecord = struct {
    p: vec.Point = undefined,
    normal: vec.Vec3f = undefined,
    t: f64 = undefined,
    front_face: bool = undefined,

    pub fn set_face_normal(self: *@This(), ray: Ray, outward_normal: Vec3f) void {
        self.front_face = dot(ray.direction, outward_normal) < 0;
        self.normal = if (self.front_face) outward_normal else -outward_normal;
    }
};

pub const Hittable = union(enum) {
    list: HittableList,
    sphere: Sphere,

    pub fn hit(self: @This(), ray: Ray, ray_t: Interval) ?HitRecord {
        return switch (self) {
            inline else => |h| h.hit(ray, ray_t),
        };
    }
};

pub const HittableList = struct {
    allocator: std.mem.Allocator,
    objects: std.ArrayList(Hittable) = undefined,

    pub fn init(allocator: std.mem.Allocator) !HittableList {
        return .{
            .allocator = allocator,
            .objects = try std.ArrayList(Hittable).initCapacity(allocator, 10),
        };
    }

    pub fn clear(self: *@This()) void {
        self.objects.clearRetainingCapacity();
    }

    pub fn add(self: *@This(), object: Hittable) !void {
        try self.objects.append(self.allocator, object);
    }

    pub fn hit(self: @This(), ray: Ray, ray_t: Interval) ?HitRecord {
        var result: ?HitRecord = null;
        var closest_so_far = ray_t.max;

        for (self.objects.items) |obj| {
            if (obj.hit(ray, ray_t)) |rec| {
                result = rec;
                closest_so_far = rec.t;
            }
        }

        return result;
    }
};

pub const Sphere = struct {
    center: vec.Point,
    radius: f64,

    pub fn init(center: vec.Point, radius: f64) Hittable {
        return .{
            .sphere = .{
                .center = center,
                .radius = @max(0, radius),
            },
        };
    }

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
    //
    // Simplification:
    // Let's consider that b = -2h then the solution to the quadratic equation becomes:
    //                   (h ± √(h² - ac)) / a
    // With this:
    // a = d.d
    // h = b / -2 = d . (C - Q)
    // c = (C - Q) . (C - Q) - r²
    // discriminant = h² - ac
    pub fn hit(self: @This(), ray: Ray, ray_t: Interval) ?HitRecord {
        const oc = self.center - ray.origin;
        const a = len_squared(ray.direction);
        const h = dot(ray.direction, oc);
        const c = len_squared(oc) - self.radius * self.radius;

        const discriminant = h * h - a * c;
        if (discriminant < 0) return null;

        const sqrtd = @sqrt(discriminant);

        // Find the nearest root that lies in the acceptable range
        var root = (h - sqrtd) / a;
        if (!ray_t.surrounds(root)) {
            root = (h + sqrtd) / a;
            if (!ray_t.surrounds(root)) return null;
        }

        var record = HitRecord{};
        record.t = root;
        record.p = ray.at(record.t);
        const outward_normal = (record.p - self.center) / s(self.radius);
        HitRecord.set_face_normal(&record, ray, outward_normal);
        return record;
    }
};
