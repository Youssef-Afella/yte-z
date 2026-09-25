const std = @import("std");

const Bitmap = @import("../bitmap.zig").Bitmap;

const FontData = @import("font_data.zig").FontData;
const renderer = @import("font_renderer.zig");

pub const Rect = struct { x: i16, y: i16, w: i16, h: i16 };

pub const Font = struct {
    io: std.Io,
    allocator: std.mem.Allocator,
    data: FontData,
    atlas: Bitmap,
    rects: []Rect,

    pub fn init(io: std.Io, allocator: std.mem.Allocator) !Font {
        const atlas = try Bitmap.init(allocator, 800, 800);
        @memset(atlas.pixels, 0);

        //const data = try FontData.init(io, allocator, "assets/JetBrainsMono-Bold.ttf");
        const data = try FontData.init(io, allocator, "assets/Roboto-Regular.ttf");

        return .{
            .io = io,
            .allocator = allocator,
            .data = data,
            .atlas = atlas,
            .rects = try allocator.alloc(Rect, 300),
        };
    }

    pub fn deinit(f: *Font) void {
        f.atlas.deinit();
        f.allocator.free(f.rects);
    }

    fn renderGlyph(f: *Font, c: u8, size: f32) struct { u32, u32, []u8 } {
        const glyf = f.data.glyfs[f.data.cmap[c]];

        const scaling: f32 = size / @as(f32, @floatFromInt(f.data.unit_per_em));

        const w: f32 = @floatFromInt(glyf.bounds.w - glyf.bounds.x);
        const h: f32 = @floatFromInt(glyf.bounds.h - glyf.bounds.y);

        const width: u32 = @ceil(w * scaling + 1);
        const height: u32 = @ceil(h * scaling);

        const bitmap = f.allocator.alloc(u8, width * height) catch unreachable;
        const buffer = f.allocator.alloc(f32, width * height) catch unreachable;
        @memset(buffer, 0);

        renderer.renderGlyph(glyf, scaling, bitmap, buffer, @intCast(width));

        f.allocator.free(buffer);

        return .{ width, height, bitmap };
    }

    pub fn bakeAtlas(f: *Font) !void {
        const char = 'g';
        const size = 200;
        const iterations = 1000;

        const start = std.Io.Clock.now(.awake, f.io);
        for (0..iterations) |i| {
            const width, const height, const buffer = renderGlyph(f, char, size);
            f.allocator.free(buffer);
            _ = width;
            _ = height;
            _ = i;
        }
        const end = std.Io.Clock.now(.awake, f.io);

        const duration = start.durationTo(end);
        const fd: f32 = @floatFromInt(duration.toMicroseconds());
        std.debug.print("\nglyph '{c}', size {}px/em, {} iterations \navg {:.3} us\n", .{ char, size, iterations, fd / iterations });

        const width, const height, const buffer = renderGlyph(f, char, size);
        std.debug.print("bitmap: {}x{} px\n", .{ width, height });

        ///////////////////////////////////////////////////////

        for (0..height) |y| {
            for (0..width) |x| {
                const value = buffer[x + y * width];
                const c: u32 = value;
                const color = c | (c << 8) | (c << 16);

                f.atlas.setMagPixel(@intCast(x), @intCast(height - y - 1), color, 3);
            }
        }
    }
};
