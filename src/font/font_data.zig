const std = @import("std");

const Rect = @import("font.zig").Rect;

const Vertex = @import("font_renderer.zig").Vertex;
const FontReader = @import("font_reader.zig").FontReader;

pub const Glyf = struct {
    offset: u32,
    bounds: Rect,
    vertices: []Vertex,
    end_points: []u16,
};

pub const FontData = struct {
    io: std.Io,
    allocator: std.mem.Allocator,
    reader: FontReader,
    unit_per_em: u16,

    tables: [@typeInfo(TableTag).@"enum".fields.len]TableInfo,
    glyfs: []Glyf,
    cmap: [1000]u32,

    pub fn init(io: std.Io, allocator: std.mem.Allocator, comptime path: []const u8) !FontData {

        //TODO: Support files above 10mb
        const font_bytes = try std.Io.Dir.cwd().readFileAlloc(
            io,
            path,
            allocator,
            .limited(10 * 1024 * 1024),
        );

        var reader = FontReader.init(font_bytes);

        const tables = getTables(&reader);
        const glyfs = try getGlyfs(allocator, &reader, &tables);
        const cmap = getCmap(&reader, &tables);

        //Goto Head
        reader.setPosition(tables[@intFromEnum(TableTag.head)].offset);
        reader.skipBytes(18);
        const unit_per_em = reader.readInt(u16);

        return .{
            .io = io,
            .allocator = allocator,
            .reader = reader,

            .unit_per_em = unit_per_em,
            .tables = tables,
            .glyfs = glyfs,
            .cmap = cmap,
        };
    }

    fn getGlyfs(allocator: std.mem.Allocator, r: *FontReader, tables: []const TableInfo) ![]Glyf {
        //Goto Maxp
        r.setPosition(tables[@intFromEnum(TableTag.maxp)].offset + 4);
        const num_glyf = r.readInt(u16);

        //Goto Head
        r.setPosition(tables[@intFromEnum(TableTag.head)].offset);
        r.skipBytes(50);
        const is_two_byte = r.readInt(i16) == 0;

        //Goto Loca
        const loca_table_start = tables[@intFromEnum(TableTag.loca)].offset;
        const glyf_table_start = tables[@intFromEnum(TableTag.glyf)].offset;

        const glyfs = try allocator.alloc(Glyf, num_glyf);

        for (0..num_glyf) |i| {
            const p = loca_table_start + i * (if (is_two_byte) @as(u32, 2) else @as(u32, 4));
            r.setPosition(@truncate(p));

            const glyf_data_offset = if (is_two_byte) @as(u32, @intCast(r.readInt(u16))) * 2 else r.readInt(u32);
            const offset = glyf_table_start + glyf_data_offset;

            const o_vertices, const o_end_points, const on_curve, const bounds = parseShape(allocator, r, offset) catch .{ undefined, undefined, undefined, undefined };
            var vertices: std.ArrayList(Vertex) = .empty;
            const end_points = try allocator.alloc(u16, o_end_points.len);

            for (0..o_end_points.len) |contour_index| {
                const contour_start = if (contour_index == 0) 0 else o_end_points[contour_index - 1] + 1;

                const contour_len = o_end_points[contour_index] - contour_start + 1;
                var last_on_curve_point_index: u16 = 0;

                for (0..contour_len) |j| {
                    const current_index = j + contour_start;
                    const next_index = ((j + 1) % contour_len) + contour_start;

                    const current = o_vertices[current_index];
                    const next = o_vertices[next_index];

                    try vertices.append(allocator, current);

                    if (on_curve[current_index]) {
                        last_on_curve_point_index = @truncate(vertices.items.len - 1);
                    }

                    if (on_curve[current_index] == on_curve[next_index]) {
                        try vertices.append(allocator, .{ .x = (current.x + next.x) >> 1, .y = (current.y + next.y) >> 1 });

                        if (!on_curve[current_index]) {
                            last_on_curve_point_index = @truncate(vertices.items.len - 1);
                        }
                    }
                }

                end_points[contour_index] = last_on_curve_point_index;
            }

            glyfs[i] = .{
                .offset = offset,
                .bounds = bounds,
                .vertices = vertices.items,
                .end_points = end_points,
            };
        }

        return glyfs;
    }

    fn parseShape(allocator: std.mem.Allocator, r: *FontReader, glyph_offset: u32) !struct { []Vertex, []u16, []bool, Rect } {
        r.setPosition(glyph_offset);
        const num_of_countours = r.readInt(i16);

        if (num_of_countours <= 0) {
            return error.ZeroContours;
        }

        //r.skipBytes(8);

        const xmin = r.readInt(i16);
        const ymin = r.readInt(i16);
        const xmax = r.readInt(i16);
        const ymax = r.readInt(i16);
        const bounds = Rect{ .x = xmin, .y = ymin, .w = xmax, .h = ymax };

        const end_points = try allocator.alloc(u16, @intCast(num_of_countours));

        for (0..@intCast(num_of_countours)) |i| {
            const end = r.readInt(u16);
            end_points[i] = end;
        }

        const intruction_length = r.readInt(u16);
        r.skipBytes(intruction_length);

        const num_points = end_points[@intCast(num_of_countours - 1)] + 1;
        const all_flags = try allocator.alloc(u8, num_points);
        const on_curve_flags = try allocator.alloc(bool, num_points);

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

        const vertices = try allocator.alloc(Vertex, num_points);

        var previous_x: i16 = 0;

        for (0..num_points) |i| {
            const offset_size_flag_bit = 1;
            const offset_sign_or_skip_bit = 4;

            vertices[i].x = previous_x;

            const flag = all_flags[i];
            on_curve_flags[i] = readBitFlag(flag, 0);

            //if (i == 0 and !readBitFlag(flag, 0)) {
            //    std.debug.print("First point is not on curve", .{});
            //}
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

            if (readBitFlag(flag, offset_size_flag_bit)) {
                const offset = r.readInt(u8);
                const sign: i16 = if (readBitFlag(flag, offset_sign_or_skip_bit)) 1 else -1;
                vertices[i].y += offset * sign;
            } else if (!readBitFlag(flag, offset_sign_or_skip_bit)) {
                vertices[i].y += r.readInt(i16);
            }

            previous_y = vertices[i].y;
        }

        return .{ vertices, end_points, on_curve_flags, bounds };
    }

    fn getCmap(r: *FontReader, tables: []const TableInfo) [1000]u32 {
        r.setPosition(tables[@intFromEnum(TableTag.cmap)].offset + 2);
        const num_cmap = r.readInt(u16);

        var cmap_subtable_offset: ?u32 = null;
        var best_score: i32 = -1;

        for (0..num_cmap) |i| {
            _ = i;
            const platform_id = r.readInt(u16);
            const platform_specific_id = r.readInt(u16);
            const platform_offset = r.readInt(u32);

            const score: i32 = switch (platform_id) {
                3 => switch (platform_specific_id) {
                    10 => 5,
                    1 => 4,
                    0 => 1,
                    else => -1,
                },
                0 => 3,
                1 => 2,
                else => -1,
            };

            if (score > best_score) {
                best_score = score;
                cmap_subtable_offset = platform_offset;
            }
        }

        if (cmap_subtable_offset == null) {
            std.debug.print("No usable cmap subtable found\n", .{});
            return undefined;
        }

        r.setPosition(tables[@intFromEnum(TableTag.cmap)].offset + cmap_subtable_offset.?);
        const format = r.readInt(u16);

        var mapping_buffer: [1000]u32 = undefined; //TODO: Full character mapping

        if (format == 4) {
            const length = r.readInt(u16);
            const language = r.readInt(u16);
            _ = length;
            _ = language;

            const seg_count_x2 = r.readInt(u16);
            const seg_count = seg_count_x2 / 2;

            r.skipBytes(6);

            var end_code_buf: [4000]u16 = undefined;
            var start_code_buf: [4000]u16 = undefined;
            var id_delta_buf: [4000]i16 = undefined;
            var id_range_offset_buf: [4000]u16 = undefined;

            for (0..seg_count) |i| {
                end_code_buf[i] = r.readInt(u16);
            }
            r.skipBytes(2);

            for (0..seg_count) |i| {
                start_code_buf[i] = r.readInt(u16);
            }
            for (0..seg_count) |i| {
                id_delta_buf[i] = @bitCast(r.readInt(u16));
            }

            const id_range_offset_array_pos = r.getPosition();
            for (0..seg_count) |i| {
                id_range_offset_buf[i] = r.readInt(u16);
            }

            const glyph_id_array_pos = r.getPosition();
            _ = glyph_id_array_pos;

            for (0..seg_count) |i| {
                const end_char_code = end_code_buf[i];
                const start_char_code = start_code_buf[i];
                const id_delta = id_delta_buf[i];
                const id_range_offset = id_range_offset_buf[i];

                if (start_char_code == 0xFFFF and end_char_code == 0xFFFF) break;

                var char_code = start_char_code;
                while (char_code <= end_char_code) : (char_code += 1) {
                    var glyph_index: u16 = 0;

                    if (id_range_offset == 0) {
                        glyph_index = @bitCast(@as(i16, @bitCast(char_code)) +% id_delta);
                    } else {
                        const seg_offset_in_array: u32 = @truncate(i * 2);
                        const target_byte_pos = id_range_offset_array_pos + seg_offset_in_array + id_range_offset + 2 * (char_code - start_char_code);

                        r.setPosition(target_byte_pos);
                        const raw_glyph = r.readInt(u16);

                        if (raw_glyph != 0) {
                            glyph_index = @bitCast(@as(i16, @bitCast(raw_glyph)) +% id_delta);
                        }
                    }

                    if (char_code < mapping_buffer.len) {
                        mapping_buffer[char_code] = glyph_index;
                    }

                    if (char_code == 0xFFFF) break;
                }
            }
        } else if (format == 0) {
            const length = r.readInt(u16);
            const language = r.readInt(u16);
            _ = length;
            _ = language;

            for (0..256) |char_code| {
                const glyph_index = r.readInt(u8);

                if (char_code < mapping_buffer.len) {
                    mapping_buffer[char_code] = glyph_index;
                }
            }
        } else if (format == 12) {
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

                    if (char_code < mapping_buffer.len) {
                        mapping_buffer[char_code] = @truncate(glyph_index);
                    }
                }
            }
        } else {
            std.debug.print("Can't use soemthing but format 12 or 0, you format is : {}", .{format});
        }

        return mapping_buffer;
    }

    fn getTables(r: *FontReader) [@typeInfo(TableTag).@"enum".fields.len]TableInfo {
        r.skipBytes(4);

        const num_tables = r.readInt(u16);
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

        return tables;
    }

    fn readBitFlag(value: u8, bit_index: u3) bool {
        return ((value >> bit_index) & 1) != 0;
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
};
