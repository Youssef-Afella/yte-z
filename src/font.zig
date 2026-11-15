const std = @import("std");

pub const RenderInfo = struct {
    char: u8,
    scale: f32,

    pub const Context = struct {
        pub fn hash(_: Context, k: RenderInfo) u64 {
            var h = std.hash.Wyhash.init(0);
            std.hash.autoHash(&h, k.char);
            std.hash.autoHash(&h, @as(u32, @bitCast(k.scale)));
            return h.final();
        }

        pub fn eql(_: Context, a: RenderInfo, b: RenderInfo) bool {
            return a.char == b.char and a.scale == b.scale;
        }
    };
};

pub const CharBitmap = struct {
    bitmap: []u8,
    ymin: i32,
    width: i32,
    height: i32,
};

const FontZy = @import("font-zy").Font;

pub const Font = struct {
    io: std.Io,
    arena: std.mem.Allocator,
    renderer: FontZy,
    map: std.HashMap(RenderInfo, CharBitmap, RenderInfo.Context, std.hash_map.default_max_load_percentage),

    pub fn init(io: std.Io, arena: std.mem.Allocator) !Font {
        const font_bytes = try std.Io.Dir.cwd().readFileAlloc(
            io,
            "fonts/JetBrainsMono/JetBrainsMono-Medium.ttf",
            arena,
            .limited(10 * 1024 * 1024),
        );
        const font = try FontZy.load(font_bytes);

        return .{
            .io = io,
            .arena = arena,
            .renderer = font,
            .map = std.HashMap(RenderInfo, CharBitmap, RenderInfo.Context, std.hash_map.default_max_load_percentage).init(arena),
        };
    }

    pub fn deinit(f: *Font) void {
        f.arena.free(f.renderer.font_bytes);
        f.map.clearRetainingCapacity();
    }

    pub fn getChar(f: *Font, char: u32, scale: f32) !CharBitmap {
        const key: RenderInfo = .{
            .char = @truncate(char),
            .scale = scale,
        };

        if (f.map.get(key)) |value| {
            return value;
        }

        const font = f.renderer;
        const glyph = font.characterToGlyphIndex(@truncate(char));

        const char_bitmap, const metrics = try font.rasterize(f.arena, glyph, scale);
        const result: CharBitmap = .{
            .bitmap = char_bitmap,
            .ymin = metrics.ymin,
            .width = @intCast(metrics.width),
            .height = @intCast(metrics.height),
        };

        try f.map.put(key, result);

        return result;
    }
};
