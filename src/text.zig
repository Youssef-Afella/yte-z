const std = @import("std");

pub const Text = struct {
    lines: std.ArrayList(std.ArrayList(u8)),
    cursor_x: usize,
    cursor_y: usize,
    gpa: std.mem.Allocator,
    io: std.Io,
    file: std.Io.File,

    pub fn init(gpa: std.mem.Allocator, io: std.Io, path: []const u8) !Text {
        const file = try std.Io.Dir.cwd().openFile(io, path, .{ .mode = .read_write });

        // Convert file to lines
        var lines = std.ArrayList(std.ArrayList(u8)).empty;

        const len = try file.length(io);
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
            .cursor_x = 0,
            .cursor_y = 0,
            .lines = lines,
        };
    }

    pub fn moveCursorX(t: *Text, i: usize) void {
        t.cursor_x += i;
        if (t.cursor_x >= t.lines.items[t.cursor_y].items.len) {
            t.cursor_x = t.lines.items[t.cursor_y].items.len - 1;
        }
    }

    pub fn putChar(t: *Text, ch: u8) void {
        t.lines.items[t.cursor_y].items[t.cursor_x] = ch;
    }

    //pub fn write(t: *Text, text: []const u8) !void {}

    pub fn save(t: *Text) !void {
        var buf: [4096]u8 = undefined;
        var fw = t.file.writer(t.io, &buf);
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
