const Text = @import("text.zig").Text;
const Surface = @import("surface.zig").Surface;
const Font = @import("font.zig").Font;

pub const TextRenderer = struct {
    text: *Text,
    font: *Font,
    target: *Surface,
    scale: f32,

    pub fn init(text: *Text, font: *Font, target: *Surface) TextRenderer {
        return .{
            .text = text,
            .font = font,
            .target = target,
            .scale = 0.02,
        };
    }

    pub fn redrawAll(r: *TextRenderer, time: i32, rtime: i32) !void {
        const scale = r.scale;
        const hmetrics = r.font.renderer.glyphHorizontalMetrics(0, scale);
        const vmetrics = r.font.renderer.verticalMetrics(scale);

        const width: i32 = hmetrics.advance_width;
        const height: i32 = @intCast(vmetrics.ascent - vmetrics.descent);

        var x: i32 = 0;
        var y: i32 = 0;

        for (r.text.lines.items) |line| {
            for (line.items) |ch| {
                const far = try r.font.getChar(ch, scale);
                const bitmap = far.bitmap;
                const ymin = far.ymin;
                const w = far.width;
                const h = far.height;
                //defer r.font.allocator.free(bitmap);

                const cy: i32 = vmetrics.ascent + @as(i16, @intCast(ymin));
                blit(bitmap, r.target.pixels, @intCast(x), @intCast(cy + y), @intCast(w), @intCast(h), r.target.width, r.target.height);

                x += width;
            }

            x = 0;
            y += height;
        }

        if ((time >> 9) & 1 != 0 or rtime < 400) {
            for (0..@as(u32, @intCast(height))) |j| {
                for (0..3) |i| {
                    const px = (r.text.cursor_x + 1) * width + @as(i32, @intCast(i));
                    const py = r.text.cursor_y * height + @as(i32, @intCast(j));
                    const w: i32 = @intCast(r.target.width);

                    if (px + py * w >= r.target.pixels.len) continue;

                    r.target.pixels[@intCast(px + py * w)] = 0xFFFF0000;
                }
            }
        }
    }

    fn blit(src: []u8, dst: []u32, x: u32, y: u32, w: u32, h: u32, width: u32, height: u32) void {
        if (x + w >= width or y + h >= height) return;

        for (0..h) |j| {
            for (0..w) |i| {
                const v: u32 = src[i + j * w];
                dst[x + i + (y + j) * width] = v | (v << 8) | (v << 16);
            }
        }
    }
};
