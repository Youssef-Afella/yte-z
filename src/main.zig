const std = @import("std");
const Allocator = std.mem.Allocator;
const FontReader = @import("font_reader.zig").FontReader;

fn printn(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt, args);
    std.debug.print("\n", .{});
}

fn print(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt, args);
}

fn readBitFlag(value: u8, bit_index: u3) bool {
    return ((value >> bit_index) & 1) != 0;
}

pub fn drawLine(x0: i32, y0: i32, x1: i32, y1: i32, bitmap: []u8, res: i32) void {
    const hx0: i32 = @max(x0, 0);
    const hx1: i32 = @max(x1, 0);
    const hy0: i32 = @max(y0, 0);
    const hy1: i32 = @max(y1, 0);

    var x = hx0;
    var y = hy0;

    const dx: i32 = @intCast(@abs(hx1 - x));
    const dy: i32 = @intCast(@abs(hy1 - y));

    const sx: i32 = if (x < hx1) 1 else -1;
    const sy: i32 = if (y < hy1) 1 else -1;

    var err: i32 = dx - dy;

    while (true) {
        if (x + y * res < bitmap.len)
            bitmap[@intCast(x + y * res)] = 1;

        if (x == hx1 and y == hy1)
            break;

        const e2 = err * 2;

        if (e2 > -dy) {
            err -= dy;
            x += sx;
        }

        if (e2 < dx) {
            err += dx;
            y += sy;
        }
    }
}

pub const TableTag = enum {
    cmap,
    glyf,
    head,
    hhea,
    hmtx,
    loca,
    maxp,
    name,
    post,

    fn asInt(tag: TableTag) u32 {
        const a: [4]u8 = @tagName(tag).*;
        return @byteSwap(@as(u32, @bitCast(a)));
    }
};

pub const TableInfo = struct {
    checksum: u32,
    offset: u32,
    length: u32,
};

pub const Vertex = struct {
    x: i16,
    y: i16,
};

fn parseVertices(r: *FontReader, allocator: Allocator) struct { []u16, []Vertex, i32 } {
    const num_of_countours = r.readInt(i16);
    printn("Num of Contoures : {}", .{num_of_countours});

    if (num_of_countours <= 0) {
        return .{ undefined, undefined, -1 };
    }

    r.skipBytes(8);

    const end_points = allocator.alloc(u16, @intCast(num_of_countours)) catch return .{ undefined, undefined, -1 };

    for (0..@intCast(num_of_countours)) |i| {
        const end = r.readInt(u16);
        end_points[i] = end;
    }

    const intruction_length = r.readInt(u16);
    r.skipBytes(intruction_length);

    const num_points = end_points[@intCast(num_of_countours - 1)] + 1;
    const all_flags = allocator.alloc(u8, num_points) catch return .{ undefined, undefined, -1 };

    var k: u32 = 0;
    while (k < num_points) : (k += 1) {
        const flag = r.readInt(u8);
        all_flags[k] = flag;

        if (readBitFlag(flag, 3)) {
            for (0..r.readInt(u8)) |j| {
                _ = j;
                k += 1;
                all_flags[k] = flag;
            }
        }
    }

    const vertices = allocator.alloc(Vertex, num_points) catch return .{ undefined, undefined, -1 };

    var previous_x: i16 = 0;

    for (0..num_points) |i| {
        const offset_size_flag_bit = 1;
        const offset_sign_or_skip_bit = 4;

        vertices[i].x = previous_x;

        const flag = all_flags[i];
        //onCurve bit

        if (readBitFlag(flag, offset_size_flag_bit)) {
            const offset = r.readInt(u8);
            const sign: i16 = if (readBitFlag(flag, offset_sign_or_skip_bit)) 1 else -1;
            vertices[i].x += offset * sign;
        } else if (!readBitFlag(flag, offset_sign_or_skip_bit)) {
            vertices[i].x += r.readInt(i16);
        }

        previous_x = vertices[i].x;
    }

    var previous_y: i16 = 0;

    for (0..num_points) |i| {
        const offset_size_flag_bit = 2;
        const offset_sign_or_skip_bit = 5;

        vertices[i].y = previous_y;

        const flag = all_flags[i];
        //onCurve bit

        if (readBitFlag(flag, offset_size_flag_bit)) {
            const offset = r.readInt(u8);
            const sign: i16 = if (readBitFlag(flag, offset_sign_or_skip_bit)) 1 else -1;
            vertices[i].y += offset * sign;
        } else if (!readBitFlag(flag, offset_sign_or_skip_bit)) {
            vertices[i].y += r.readInt(i16);
        }

        previous_y = vertices[i].y;
    }

    return .{ end_points, vertices, 10 };
}

fn rasterize(comptime resolution: u32, end_points: []u16, vertices: []Vertex) void {
    var bitmap: [resolution * resolution]u8 = .{0} ** (resolution * resolution);

    var current_contour: u32 = 0;
    var current_index: u32 = 0;

    while (current_index < vertices.len) : (current_index += 1) {
        var fx: f32 = @floatFromInt(vertices[current_index].x);
        fx /= 1000;
        var fy: f32 = @floatFromInt(vertices[current_index].y);
        fy /= 1000;

        const ix: i32 = @intFromFloat(fx * resolution);
        const iy: i32 = @intFromFloat(fy * resolution);

        if (current_index == end_points[current_contour]) {
            const previous_target = if (current_contour == 0) 0 else (end_points[current_contour - 1] + 1);

            current_contour += 1;

            var fx2: f32 = @floatFromInt(vertices[previous_target].x);
            fx2 /= 1000;
            var fy2: f32 = @floatFromInt(vertices[previous_target].y);
            fy2 /= 1000;

            const ix2: i32 = @intFromFloat(fx2 * resolution);
            const iy2: i32 = @intFromFloat(fy2 * resolution);

            drawLine(ix, iy, ix2, iy2, &bitmap, @intCast(resolution));

            continue;
        }

        var fx2: f32 = @floatFromInt(vertices[current_index + 1].x);
        fx2 /= 1000;
        var fy2: f32 = @floatFromInt(vertices[current_index + 1].y);
        fy2 /= 1000;

        const ix2: i32 = @intFromFloat(fx2 * resolution);
        const iy2: i32 = @intFromFloat(fy2 * resolution);

        //bitmap[ix + iy * resolution] = 1;
        drawLine(ix, iy, ix2, iy2, &bitmap, @intCast(resolution));
    }

    for (0..resolution) |y| {
        const ty = resolution - y - 1;
        for (0..resolution) |x| {
            if (bitmap[ty * resolution + x] == 0) {
                print(". ", .{});
            } else {
                print("# ", .{});
            }
        }
        print("\n", .{});
    }
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const font_bytes = try std.Io.Dir.cwd().readFileAlloc(
        io,
        "src/font.ttf",
        allocator,
        .limited(10 * 1024 * 1024),
    );

    var r: FontReader = .{ .buffer = font_bytes };

    r.skipBytes(4);

    const num_tables = r.readInt(u16);
    printn("Number of Tables: {}", .{num_tables});

    r.skipBytes(6);

    var tables: [@typeInfo(TableTag).@"enum".fields.len]TableInfo = undefined;

    for (0..num_tables) |i| {
        _ = i;

        const current_tag = r.readInt(u32);
        const current_checksum = r.readInt(u32);
        const current_offset = r.readInt(u32);
        const current_length = r.readInt(u32);

        const tag: TableTag = switch (current_tag) {
            TableTag.cmap.asInt() => .cmap,
            TableTag.glyf.asInt() => .glyf,
            TableTag.head.asInt() => .head,
            TableTag.hhea.asInt() => .hhea,
            TableTag.hmtx.asInt() => .hmtx,
            TableTag.loca.asInt() => .loca,
            TableTag.maxp.asInt() => .maxp,
            TableTag.name.asInt() => .name,
            TableTag.post.asInt() => .post,
            else => continue,
        };

        tables[@intFromEnum(tag)] = .{
            .checksum = current_checksum,
            .offset = current_offset,
            .length = current_length,
        };
    }

    //Goto Maxp
    r.setPosition(tables[@intFromEnum(TableTag.maxp)].offset + 4);
    const num_glyf = r.readInt(u16);
    printn("Num of Glyfs : {}", .{num_glyf});

    //Goto Head
    r.setPosition(tables[@intFromEnum(TableTag.head)].offset);
    r.skipBytes(50);
    const is_two_byte = r.readInt(i16) == 0;

    //Goto Loca
    const loca_table_start = tables[@intFromEnum(TableTag.loca)].offset;
    const glyf_table_start = tables[@intFromEnum(TableTag.glyf)].offset;
    const glyf_positions = try allocator.alloc(u32, num_glyf);

    for (0..num_glyf) |i| {
        const p = loca_table_start + i * (if (is_two_byte) @as(u32, 2) else @as(u32, 4));
        r.setPosition(@truncate(p));

        const glyph_data_offset = if (is_two_byte) r.readInt(u16) * 2 else r.readInt(u32);
        glyf_positions[i] = glyf_table_start + glyph_data_offset;
    }

    r.setPosition(tables[@intFromEnum(TableTag.cmap)].offset + 2);
    const num_cmap = r.readInt(u16);

    var cmap_subtable_offset: u32 = 0;

    for (0..num_cmap) |i| {
        _ = i;
        const platform_id = r.readInt(u16);
        const platform_sepecific_id = r.readInt(u16);
        const platform_offset = r.readInt(u32);

        if (platform_id == 0) {
            if (platform_sepecific_id == 4) {
                cmap_subtable_offset = platform_offset;
            }
        }
    }

    r.setPosition(tables[@intFromEnum(TableTag.cmap)].offset + cmap_subtable_offset);
    const format = r.readInt(u16);

    var mapping_buffer: [1000]usize = undefined;

    if (format == 12) {
        r.skipBytes(10);
        const num_groups = r.readInt(u32);

        for (0..num_groups) |i| {
            _ = i;
            const start_char_code = r.readInt(u32);
            const end_char_code = r.readInt(u32);
            const start_glyph_index = r.readInt(u32);

            const num_characters = end_char_code - start_char_code + 1;

            for (0..num_characters) |j| {
                const char_code = start_char_code + j;
                const glyph_index = start_glyph_index + j;

                if (char_code < mapping_buffer.len)
                    mapping_buffer[char_code] = glyph_index;
            }
        }
    } else {
        printn("Can't use soemthing but format 12, you format is : {}", .{format});
    }

    const resolution = 30;

    r.setPosition(glyf_positions[mapping_buffer['z']]);
    const end_points, const vertices, const f = parseVertices(&r, allocator);
    if (f > 0)
        rasterize(resolution, end_points, vertices);
}
