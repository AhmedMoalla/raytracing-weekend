const std = @import("std");
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
    dielectric: Dielectric,

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
                .fuzz = @min(fuzz, 1),
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

pub const Dielectric = struct {
    // Refractive index in vacuum or air, or the ratio of the material's refractive index over
    // the refractive index of the enclosing media
    refraction_index: f64,

    pub fn init(refraction_index: f64) Material {
        return .{
            .dielectric = .{
                .refraction_index = refraction_index,
            },
        };
    }

    pub fn scatter(self: @This(), ray: Ray, rec: HitRecord) ?ScatterRecord {
        const refraction_index = if (rec.front_face)
            1.0 / self.refraction_index
        else
            self.refraction_index;

        const unit_direction = vec.unit(ray.direction);
        const cos_theta = @min(vec.dot(-unit_direction, rec.normal), 1.0);
        const sin_theta = @sqrt(1.0 - cos_theta * cos_theta);

        const cannot_refract = refraction_index * sin_theta > 1.0;
        const direction = if (cannot_refract)
            vec.reflect(unit_direction, rec.normal)
        else
            vec.refract(unit_direction, rec.normal, refraction_index);

        return .{
            .scattered = Ray.init(rec.p, direction),
            .attenuation = Color{ 1, 1, 1 },
        };
    }

    fn reflectance(cosine: f64, refraction_index: f64) f64 {
        // Use Schlick's approximation for reflectance.
        var r0 = (1 - refraction_index) / (1 + refraction_index);
        r0 = r0 * r0;
        return r0 + (1 - r0) * std.math.pow(f64, (1 - cosine), 5);
    }
};
