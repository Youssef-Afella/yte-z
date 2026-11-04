const std = @import("std");
const Window = @import("window.zig").Window;
const Surface = @import("surface.zig").Surface;
const Font = @import("font/font.zig").Font;
const Text = @import("text.zig").Text;

pub fn main(init: std.process.Init) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const gpa = arena.allocator();

    var text = try Text.init(gpa, init.io, "mytext.txt");
    defer text.deinit();

    const window = try Window.init(gpa, .{
        .title = "YTE",
        .width = 1000,
        .height = 800,
        .resizable = true,
    });
    defer window.deinit();

    const surface = try Surface.init(gpa, window.config.width, window.config.height);
    defer surface.deinit();

    var font = try Font.init(init.io, gpa);
    defer font.deinit();

    surface.copyBlock(font.atlas, .{ .x = 0, .y = 0, .w = @intCast(font.atlas.width), .h = @intCast(font.atlas.height) }, .{ .x = 0, .y = 0 });

    while (!window.shouldClose()) {
        window.pollEvents();

        while (window.nextEvent()) |event| {
            switch (event) {
                .char => |key| {
                    if (key == 8) {
                        //font.eraseChar();
                    } else if (key == 13) {
                        //font.jumpLine();
                        try text.save();
                    } else {
                        try font.drawChar(key);
                        text.putChar(@truncate(key));
                    }
                },
                .key_down => |key| {
                    const key_right = 39;
                    switch (key) {
                        key_right => {
                            text.moveCursorX(1);
                        },
                        else => {},
                    }
                },
                .resize => |v| {
                    _ = v;
                    std.debug.print("Resizing\n", .{});
                },
                else => {},
            }
        }

        window.presentSurface(surface);
        try std.Io.sleep(init.io, .fromMilliseconds(100), .awake);
    }
}
