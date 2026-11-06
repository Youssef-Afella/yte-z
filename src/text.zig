const std = @import("std");

pub const Text = struct {
    lines: std.ArrayList(std.ArrayList(u8)),
    cursor_x: i32,
    cursor_y: i32,
    cursor_target_x: i32,
    gpa: std.mem.Allocator,
    io: std.Io,
    file: std.Io.File,

    pub fn init(gpa: std.mem.Allocator, io: std.Io, path: []const u8) !Text {
        const file = try std.Io.Dir.cwd().openFile(io, path, .{ .mode = .read_write });

        // Convert file to lines
        var lines = std.ArrayList(std.ArrayList(u8)).empty;

        const len: usize = @intCast(try file.length(io));
        const bytes = try gpa.alloc(u8, std.math.cast(usize, len).?);
        defer gpa.free(bytes);

        _ = try file.readPositionalAll(io, bytes, 0);
        var i: usize = 0;
        var last: usize = 0;

        while (i < len) : (i += 1) {
            if (bytes[i] == '\n') {
                var line = std.ArrayList(u8).empty;
                try line.appendSlice(gpa, bytes[last..i]);
                last = i + 1;
                try lines.append(gpa, line);
            }
        }

        // NOTE: This forces our line count to never be 0
        var line = std.ArrayList(u8).empty;
        try line.appendSlice(gpa, bytes[last..len]);
        try lines.append(gpa, line);

        return .{
            .io = io,
            .gpa = gpa,
            .file = file,
            .cursor_x = -1,
            .cursor_y = 0,
            .cursor_target_x = -1,
            .lines = lines,
        };
    }

    pub fn setCursorX(t: *Text, p: i32) void {
        const len: i32 = @intCast(t.lines.items[@intCast(t.cursor_y)].items.len);
        t.cursor_x = std.math.clamp(p, -1, len - 1);
    }

    pub fn moveCursorX(t: *Text, i: i32) void {
        t.cursor_target_x = t.cursor_x + i;
        t.setCursorX(t.cursor_target_x);
    }

    pub fn moveCursorY(t: *Text, i: i32) void {
        const max: i32 = @intCast(t.lines.items.len - 1);
        t.cursor_y = std.math.clamp(t.cursor_y + i, 0, max);
        t.setCursorX(t.cursor_target_x);
    }

    pub fn char(t: *Text, ch: u8) !void {
        try t.lines.items[@intCast(t.cursor_y)].insert(t.gpa, @intCast(t.cursor_x + 1), ch);
        t.setCursorX(t.cursor_x + 1);
    }

    pub fn tab(t: *Text) !void {
        const space_count = 4;
        const space: [space_count]u8 = @splat(' ');
        try t.lines.items[@intCast(t.cursor_y)].insertSlice(t.gpa, @intCast(t.cursor_x + 1), &space);
        t.setCursorX(t.cursor_x + space_count);
    }

    pub fn newLine(t: *Text) !void {
        const right = t.lines.items[@intCast(t.cursor_y)].items[@intCast(t.cursor_x + 1)..];
        var r = std.ArrayList(u8).empty;
        try r.appendSlice(t.gpa, right);
        try t.lines.items[@intCast(t.cursor_y)].resize(t.gpa, @intCast(t.cursor_x + 1));
        try t.lines.insert(t.gpa, @intCast(t.cursor_y + 1), r);

        t.moveCursorY(1);
        t.cursor_x = -1;
    }

    pub fn erase(t: *Text) !void {
        if (t.cursor_x < 0) {
            const line = t.lines.items[@intCast(t.cursor_y)].items;
            _ = t.lines.orderedRemove(@intCast(t.cursor_y));
            moveCursorY(t, -1);

            t.cursor_x = @as(i32, @intCast(t.lines.items[@intCast(t.cursor_y)].items.len)) - 1;
            try t.lines.items[@intCast(t.cursor_y)].appendSlice(t.gpa, line);
        } else {
            _ = t.lines.items[@intCast(t.cursor_y)].orderedRemove(@intCast(t.cursor_x));
            t.setCursorX(t.cursor_x - 1);
        }
    }

    pub fn save(t: *Text) !void {
        var buf: [4096]u8 = undefined;
        var fw = t.file.writer(t.io, &buf);
        try t.file.setLength(t.io, 0);

        const w = &fw.interface;

        var i: usize = 0;
        while (i < t.lines.items.len) : (i += 1) {
            try w.writeAll(t.lines.items[i].items);
            if (i != t.lines.items.len - 1) try w.writeByte('\n');
        }

        try w.flush();
    }

    pub fn deinit(t: *Text) void {
        t.file.close(t.io);
    }
};
