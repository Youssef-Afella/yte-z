const std = @import("std");

const Bitmap = @import("../bitmap.zig").Bitmap;

pub const Rect = struct { x: i16, y: i16, w: i16, h: i16 };

const FontZy = @import("font-zy").Font;

pub const Font = struct {
    io: std.Io,
    allocator: std.mem.Allocator,
    renderer: FontZy,
    atlas: Bitmap,
    rects: []Rect,
    x: i32,
    y: i32,
    max: i32,

    pub fn init(io: std.Io, allocator: std.mem.Allocator) !Font {
        const font_bytes = try std.Io.Dir.cwd().readFileAlloc(
            io,
            "assets/JetBrainsMono-Bold.ttf",
            allocator,
            .limited(10 * 1024 * 1024),
        );

        const font = try FontZy.load(font_bytes);

        const atlas = try Bitmap.init(allocator, 1000, 800);
        @memset(atlas.pixels, 0);

        return .{
            .io = io,
            .allocator = allocator,
            .renderer = font,
            .atlas = atlas,
            .rects = try allocator.alloc(Rect, 300),
            .x = 0,
            .y = 0,
            .max = 0,
        };
    }

    pub fn deinit(f: *Font) void {
        f.atlas.deinit();
        f.allocator.free(f.rects);
    }

    pub fn eraseChar(f: *Font) void {
        const font = f.renderer;
        const scale = font.scaleForPixelHeight(50);
        const vmetrics = font.verticalMetrics(scale);
        const hmetrics = font.glyphHorizontalMetrics(0, scale);

        const h: usize = @intCast(vmetrics.ascent - vmetrics.descent);

        f.x -= hmetrics.advance_width;
        if (f.x < 0) {
            f.y -= (vmetrics.ascent - vmetrics.descent);
            f.x += f.max;
        }

        for (0..h) |j| {
            for (0..@intCast(hmetrics.advance_width)) |i| {
                const ii: i32 = @intCast(i);
                const jj: i32 = @intCast(j);
                f.atlas.setPixel(@intCast(f.x + ii), @intCast(f.y + jj), 0);
            }
        }
    }

    pub fn jumpLine(f: *Font) void {
        const font = f.renderer;
        const scale = font.scaleForPixelHeight(50);
        const vmetrics = font.verticalMetrics(scale);

        f.y += (vmetrics.ascent - vmetrics.descent);
        f.max = f.x;
        f.x = 0;
    }

    pub fn drawChar(f: *Font, char: u32) !void {
        const font = f.renderer;
        const scale = font.scaleForPixelHeight(50);
        const vmetrics = font.verticalMetrics(scale);

        const glyph = font.characterToGlyphIndex(@truncate(char));

        const char_bitmap, const metrics = try font.rasterize(f.allocator, glyph, scale);
        if (metrics.advance_width + f.x > f.atlas.width) {
            f.y += vmetrics.ascent - vmetrics.descent;
            f.max = f.x;
            f.x = 0;
        }

        const cy: i32 = vmetrics.ascent + @as(i16, @intCast(metrics.ymin));
        blit(char_bitmap, f.atlas.pixels, @intCast(f.x), @intCast(cy + f.y), metrics.width, metrics.height, f.atlas.width);

        f.allocator.free(char_bitmap);

        f.x += metrics.advance_width;
    }

    fn blit(src: []u8, dst: []u32, x: u32, y: u32, w: u32, h: u32, width: u32) void {
        for (0..h) |j| {
            for (0..w) |i| {
                const v: u32 = src[i + j * w];
                dst[x + i + (y + j) * width] = v | (v << 8) | (v << 16);
            }
        }
    }
};
