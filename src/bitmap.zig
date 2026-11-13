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
};
