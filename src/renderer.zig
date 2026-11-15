const Text = @import("text.zig").Text;
const Surface = @import("surface.zig").Surface;
const Font = @import("font.zig").Font;

pub const TextRenderer = struct {
    text: *Text,
    font: *Font,
    target: *Surface,
    scale: f32,
    view_x: i32,
    view_y: i32,

    pub fn init(text: *Text, font: *Font, target: *Surface) TextRenderer {
        return .{
            .text = text,
            .font = font,
            .target = target,
            .scale = 0.02,
            .view_x = 0,
            .view_y = 0,
        };
    }

    pub const Color = struct {
        r: u8,
        g: u8,
        b: u8,
        a: u8,
    };

    pub fn move(r: *TextRenderer, x: i32, y: i32) void {
        r.view_x += x * 50;
        if (r.view_x < 0) r.view_x = 0;

        r.view_y += y * 50;
        if (r.view_y < 0) r.view_y = 0;
    }

    pub fn redrawAll(r: *TextRenderer, time: i32, rtime: i32) !void {
        const scale = r.scale;
        const hmetrics = r.font.renderer.glyphHorizontalMetrics(0, scale);
        const vmetrics = r.font.renderer.verticalMetrics(scale);

        const width: i32 = hmetrics.advance_width;
        const height: i32 = @intCast(vmetrics.ascent - vmetrics.descent);

        var x: i32 = -r.view_x;
        var y: i32 = -r.view_y - height;

        for (r.text.lines.items) |line| {
            x = -r.view_x - width;
            y += height;

            if (y < 0) continue;

            var words: [20]usize = undefined;

            var word_count: usize = 0;
            var i: usize = 0;
            var is_empty = false;
            while (i < line.items.len and word_count < words.len - 1) : (i += 1) {
                const c = line.items[i];
                if ((c == ' ' or c == '.' or c == '(' or c == ')' or c == '{') and !is_empty) {
                    words[word_count] = i;
                    word_count += 1;
                }

                if (c == ' ') {
                    is_empty = true;
                } else {
                    is_empty = false;
                }
            }
            words[word_count] = line.items.len;

            var current_word: usize = 0;
            for (line.items, 0..) |ch, index| {
                if (index >= words[current_word]) {
                    current_word += 1;
                }

                x += width;
                if (x < 0) continue;

                const far = try r.font.getChar(ch, scale);
                const bitmap = far.bitmap;
                const ymin = far.ymin;
                const w = far.width;
                const h = far.height;
                //defer r.font.allocator.free(bitmap);

                const cy: i32 = vmetrics.ascent + @as(i16, @intCast(ymin));
                const color: Color = if (current_word % 2 == 0) .{ .r = 255, .g = 200, .b = 0, .a = 255 } else .{ .r = 255, .g = 255, .b = 255, .a = 255 };
                blit(bitmap, r.target.pixels, @intCast(x), @intCast(cy + y), @intCast(w), @intCast(h), r.target.width, r.target.height, color);
            }
        }

        if ((time >> 9) & 1 != 0 or rtime < 400) {
            for (0..@as(u32, @intCast(height))) |j| {
                for (0..3) |i| {
                    const px = (r.text.cursor_x + 1) * width + @as(i32, @intCast(i)) - r.view_x;
                    const py = r.text.cursor_y * height + @as(i32, @intCast(j)) - r.view_y;
                    const w: i32 = @intCast(r.target.width);

                    const p = px + py * w;

                    if (p >= r.target.pixels.len or p < 0) continue;

                    r.target.pixels[@intCast(p)] = 0xFFFF0000;
                }
            }
        }
    }

    fn blit(src: []u8, dst: []u32, x: u32, y: u32, w: u32, h: u32, width: u32, height: u32, color: Color) void {
        if (x + w >= width or y + h >= height) return;

        for (0..h) |j| {
            for (0..w) |i| {
                const v: u32 = src[i + j * w];

                const r = (v * @as(u32, color.r)) >> 8;
                const g = (v * @as(u32, color.g)) >> 8;
                const b = (v * @as(u32, color.b)) >> 8;

                dst[x + i + (y + j) * width] = b | (g << 8) | (r << 16);
            }
        }
    }
};
