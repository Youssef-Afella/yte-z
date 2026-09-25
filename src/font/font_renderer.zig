const std = @import("std");

const Bitmap = @import("../bitmap.zig").Bitmap;
const Glyf = @import("font_data.zig").Glyf;
const Rect = @import("font.zig").Rect;

pub const Vertex = struct {
    x: i16,
    y: i16,
};

pub fn renderGlyph(glyf: Glyf, scaling: f32, bitmap: []u8, dst: []f32, dst_width: i32) void {
    const vertices = glyf.vertices;
    const end_points = glyf.end_points;

    var current_contour: u32 = 0;
    var current_index: u32 = 0;

    while (current_index < vertices.len) : (current_index += 2) {
        const p0 = vertices[current_index];
        const p1 = vertices[current_index + 1];

        if (current_index == end_points[current_contour]) {
            const previous_target = if (current_contour == 0) 0 else (end_points[current_contour - 1] + 2);
            const p2 = vertices[previous_target];

            drawCurve(p0, p1, p2, glyf.bounds, scaling, dst, dst_width);

            current_contour += 1;
            continue;
        }

        const p2 = vertices[current_index + 2];
        drawCurve(p0, p1, p2, glyf.bounds, scaling, dst, dst_width);
    }

    accumulate(bitmap, dst);
}

fn accumulate(bitmap: []u8, dst: []f32) void {
    var acc: f32 = 0.0;
    for (bitmap, dst) |*b, v| {
        acc += v;
        b.* = @floor(@max(0.0, @min(acc * 255.0, 255.0)));
    }
}

fn drawCurve(p0: Vertex, p1: Vertex, p2: Vertex, bounds: Rect, scaling: f32, dst: []f32, dst_width: i32) void {
    const valid_x = p1.x >= @min(p0.x, p2.x) and p1.x <= @max(p0.x, p2.x);
    const valid_y = p1.y >= @min(p0.y, p2.y) and p1.y <= @max(p0.y, p2.y);
    const horizontal = p0.y == p1.y and p1.y == p2.y;

    //const ax = p0.x - 2 * p1.x + p2.x;
    //const ay = p0.y - 2 * p1.y + p2.y;

    if (!horizontal and valid_x and valid_y) {
        rasterCurve(p0, p1, p2, bounds, scaling, dst, dst_width);
    }
}

fn rasterCurve(p0: Vertex, p1: Vertex, p2: Vertex, bounds: Rect, scaling: f32, dst: []f32, dst_width: i32) void {
    const x0: f32 = @as(f32, @floatFromInt(p0.x - bounds.x)) * scaling;
    const y0: f32 = @as(f32, @floatFromInt(p0.y - bounds.y)) * scaling;
    const x1: f32 = @as(f32, @floatFromInt(p1.x - bounds.x)) * scaling;
    const y1: f32 = @as(f32, @floatFromInt(p1.y - bounds.y)) * scaling;
    const x2: f32 = @as(f32, @floatFromInt(p2.x - bounds.x)) * scaling;
    const y2: f32 = @as(f32, @floatFromInt(p2.y - bounds.y)) * scaling;

    const ax = x0 - 2 * x1 + x2;
    const bx = x1 - x0;
    const ay = y0 - 2 * y1 + y2;
    const by = y1 - y0;

    const sx: i32 = if (x2 < x0) -1 else 1;
    const sy: i32 = if (y2 < y0) -1 else 1;
    const sx_f: f32 = @floatFromInt(sx);
    const sy_f: f32 = @floatFromInt(sy);

    var plane_x: f32 = if (sx > 0) @floor(x0) + 1 else @ceil(x0) - 1;
    var plane_y: f32 = if (sy > 0) @floor(y0) + 1 else @ceil(y0) - 1;

    const mid_x: f32 = @floor((x0 + plane_x) * 0.5);
    const delay: f32 = plane_x - mid_x;
    var cell_x: i32 = @intFromFloat(mid_x);
    var cell_y: i32 = @intFromFloat((y0 + plane_y) * 0.5);

    var x = x0;
    var y = y0;

    while (true) {
        const tx = intersectCurve(ax, bx, x0 - plane_x, sx_f);
        const ty = intersectCurve(ay, by, y0 - plane_y, sy_f);
        const t = @min(tx, ty);

        var ix: f32 = undefined;
        var iy: f32 = undefined;

        if (t >= 1.0) {
            ix = x2;
            iy = y2;
        } else if (tx < ty) {
            ix = plane_x;
            iy = ay * tx * tx + 2.0 * by * tx + y0;
        } else {
            ix = ax * ty * ty + 2.0 * bx * ty + x0;
            iy = plane_y;
        }

        const signed_height = iy - y;
        const trapzoid_right = ((x + ix) * 0.5 - plane_x + delay) * signed_height;
        const trapzoid_left = signed_height - trapzoid_right;

        dst[@intCast(cell_y * dst_width + cell_x)] += trapzoid_left;
        dst[@intCast(cell_y * dst_width + cell_x + 1)] += trapzoid_right;

        if (t >= 1.0) break;

        x = ix;
        y = iy;

        if (tx < ty) {
            plane_x += sx_f;
            cell_x += sx;
        } else {
            plane_y += sy_f;
            cell_y += sy;
        }
    }
}

inline fn intersectCurve(a: f32, b: f32, c: f32, s: f32) f32 {
    if (a == 0.0) {
        if (b == 0.0) return std.math.floatMax(f32);
        const t = -c / (2.0 * b);
        return if (t < 0.0 or t > 1.0) std.math.floatMax(f32) else t;
    }

    const d = b * b - a * c;
    if (d < 0.0) return std.math.floatMax(f32);

    const h = @sqrt(d) * s;
    const r = (-b + h) / a;
    return if (r < 0.0 and r > 1.0) std.math.floatMax(f32) else r;
}
