const vec = @import("vec3.zig");
const Color = vec.Color;
const Ray = @import("Ray.zig");
const h = @import("hittables.zig");
const HitRecord = h.HitRecord;
const rand = @import("random.zig");

pub const ScatterRecord = struct {
    attenuation: Color,
    scattered: Ray,
};

pub const Material = union(enum) {
    lambertian: Lambertian,
    metal: Metal,

    pub fn scatter(self: @This(), ray: Ray, rec: HitRecord) ?ScatterRecord {
        return switch (self) {
            inline else => |m| m.scatter(ray, rec),
        };
    }
};

pub const Lambertian = struct {
    albedo: Color,

    pub fn init(albedo: Color) Material {
        return .{
            .lambertian = .{
                .albedo = albedo,
            },
        };
    }

    pub fn scatter(self: @This(), _: Ray, rec: HitRecord) ?ScatterRecord {
        var scatter_direction = rec.normal + rand.unit();

        // Catch degenerate scatter direction
        // If rand.unit() generates the exact opposite of rec.normal the scatter direction will be zero
        // This is bad as it lead to infinities and NaNs
        // So we check if the scatter direction is near zero and reset it to rec.normal
        if (vec.nearZero(scatter_direction)) {
            scatter_direction = rec.normal;
        }

        return .{
            .scattered = Ray.init(rec.p, scatter_direction),
            .attenuation = self.albedo,
        };
    }
};

pub const Metal = struct {
    albedo: Color,
    fuzz: f64,

    pub fn init(albedo: Color, fuzz: f64) Material {
        return .{
            .metal = .{
                .albedo = albedo,
                .fuzz = fuzz,
            },
        };
    }

    pub fn scatter(self: @This(), ray: Ray, rec: HitRecord) ?ScatterRecord {
        var reflected = vec.reflect(ray.direction, rec.normal);
        reflected = vec.unit(reflected) + (vec.s(self.fuzz) * rand.unit());
        const scattered = Ray.init(rec.p, reflected);

        if (vec.dot(scattered.direction, rec.normal) <= 0) return null;
        return .{
            .scattered = scattered,
            .attenuation = self.albedo,
        };
    }
};
