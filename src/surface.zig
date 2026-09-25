const std = @import("std");

const Bitmap = @import("bitmap.zig").Bitmap;

const Rect = @import("font/font.zig").Rect;
const Vec2 = struct { x: u32, y: u32 };

pub const Surface = struct {
    allocator: std.mem.Allocator,
    width: u32,
    height: u32,
    pixels: []u32,

    pub fn init(allocator: std.mem.Allocator, width: u32, height: u32) !*Surface {
        const surface = try allocator.create(@This());
        surface.* = .{
            .allocator = allocator,
            .width = width,
            .height = height,
            .pixels = try allocator.alloc(u32, width * height),
        };

        clear(surface, 0);
        return surface;
    }

    pub fn deinit(s: *Surface) void {
        s.allocator.free(s.pixels);
        s.allocator.destroy(s);
    }

    pub fn setPixel(s: *Surface, x: u32, y: u32, color: u32) void {
        s.pixels[y * s.width + x] = color;
    }

    pub fn copyBlock(s: *Surface, bitmap: Bitmap, src_rect: Rect, dst_pos: Vec2) void {
        const x: u32 = @intCast(src_rect.x);
        const y: u32 = @intCast(src_rect.y);
        const width: u32 = @intCast(src_rect.w);
        const height: u32 = @intCast(src_rect.h);
        for (0..height) |r| {
            const src_row = (y + r) * bitmap.width + x;
            const dst_row = (dst_pos.y + r) * s.width + dst_pos.x;
            @memcpy(s.pixels[dst_row .. dst_row + width], bitmap.pixels[src_row .. src_row + width]);
        }
    }

    pub fn clear(s: *Surface, color: u32) void {
        @memset(s.pixels, color);
    }
};
