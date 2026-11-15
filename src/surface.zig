const std = @import("std");

const Bitmap = @import("bitmap.zig").Bitmap;

const Rect = @import("font.zig").Rect;
const Vec2 = struct { x: u32, y: u32 };

pub const Surface = struct {
    width: u32,
    height: u32,
    pixels: []u32,

    pub inline fn init(width: u32, height: u32, pixels: []u32) Surface {
        return .{
            .width = width,
            .height = height,
            .pixels = pixels,
        };
    }

    pub inline fn deinit(s: *Surface) void {
        s.allocator.free(s.pixels);
        s.allocator.destroy(s);
    }

    pub inline fn setPixel(s: *Surface, x: u32, y: u32, color: u32) void {
        s.pixels[y * s.width + x] = color;
    }

    pub inline fn copyBlock(s: *Surface, bitmap: Bitmap, src_rect: Rect, dst_pos: Vec2) void {
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

    pub inline fn clear(s: *Surface, color: u32) void {
        @memset(s.pixels, color);
    }
};
