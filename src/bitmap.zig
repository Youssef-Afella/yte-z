const std = @import("std");

pub const Bitmap = struct {
    allocator: std.mem.Allocator,
    width: u32,
    height: u32,
    pixels: []u32,

    pub fn init(allocator: std.mem.Allocator, width: u32, height: u32) !Bitmap {
        return .{
            .allocator = allocator,
            .width = width,
            .height = height,
            .pixels = try allocator.alloc(u32, width * height),
        };
    }

    pub fn deinit(b: *Bitmap) void {
        b.allocator.free(b.pixels);
    }

    pub fn getPixel(b: *Bitmap, x: u32, y: u32) u32 {
        if (x < 0 or x >= b.width or y < 0 or y >= b.height) return 0;
        return b.pixels[y * b.width + x];
    }

    pub fn setPixel(b: *Bitmap, x: u32, y: u32, color: u32) void {
        if (x < 0 or x >= b.width or y < 0 or y >= b.height) return;
        b.pixels[y * b.width + x] = color;
    }

    pub fn addPixel(b: *Bitmap, x: u32, y: u32, color: u32) void {
        if (x < 0 or x >= b.width or y < 0 or y >= b.height) return;
        b.pixels[y * b.width + x] = blendAdditiveArgb(color, b.pixels[y * b.width + x]);
    }

    pub fn blendAdditiveArgb(dst: u32, src: u32) u32 {
        // Extract alpha from destination
        const a = dst & 0xFF000000;

        // Extract color channels
        const r_dst: u32 = (dst >> 16) & 0xFF;
        const g_dst: u32 = (dst >> 8) & 0xFF;
        const b_dst: u32 = dst & 0xFF;

        const r_src: u32 = (src >> 16) & 0xFF;
        const g_src: u32 = (src >> 8) & 0xFF;
        const b_src: u32 = src & 0xFF;

        // Add and clamp to 255
        const r: u32 = @min(r_dst + r_src, 255);
        const g: u32 = @min(g_dst + g_src, 255);
        const b: u32 = @min(b_dst + b_src, 255);

        // Reconstruct ARGB
        return a | (r << 16) | (g << 8) | b;
    }

    pub fn blendPixel(b: *Bitmap, x: u32, y: u32, color: u32) void {
        if (x < 0 or x >= b.width or y < 0 or y >= b.height) return;
        b.pixels[y * b.width + x] |= color;
    }

    pub fn setMagPixel(b: *Bitmap, x: u32, y: u32, color: u32, zoom: u32) void {
        for (0..zoom) |zy| {
            for (0..zoom) |zx| {
                b.addPixel(@truncate(x * zoom + zx), @truncate(y * zoom + zy), color);
            }
        }
    }
};
