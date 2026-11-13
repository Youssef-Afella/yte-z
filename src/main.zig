const std = @import("std");
const Window = @import("window.zig").Window;
const Surface = @import("surface.zig").Surface;
const Font = @import("font.zig").Font;
const Text = @import("text.zig").Text;
const TextRenderer = @import("renderer.zig").TextRenderer;

pub fn main(init: std.process.Init) !void {
    var debug = std.heap.DebugAllocator(.{}){};
    const gpa = debug.allocator();

    var text = try Text.init(gpa, init.io, "src/main.zig");
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

    var renderer = TextRenderer.init(&text, &font, surface);
    //defer renderer.deinit();

    var modifier_state: u8 = 0;
    const ctrl_modifier: u8 = 1 << 0;

    var rtime: i32 = @truncate(std.Io.Clock.real.now(init.io).toMilliseconds());

    while (!window.shouldClose()) {
        window.pollEvents();

        if (window.event_queue.count != 0) rtime = @truncate(std.Io.Clock.real.now(init.io).toMilliseconds());
        while (window.nextEvent()) |event| {
            switch (event) {
                .char => |key| {
                    if (modifier_state == 0) {
                        switch (key) {
                            8 => try text.erase(),
                            9 => try text.tab(),
                            13 => try text.newLine(),
                            else => try text.char(@truncate(key)),
                        }
                    }
                },
                .key_down => |key| {
                    switch (key) {
                        .right => text.moveCursorX(1),
                        .left => text.moveCursorX(-1),
                        .up => text.moveCursorY(-1),
                        .down => text.moveCursorY(1),
                        .ctrl => modifier_state |= ctrl_modifier,
                        .s => {
                            if (modifier_state & ctrl_modifier != 0) {
                                try text.save();
                            }
                        },
                        .plus, .minus => {
                            if (modifier_state & ctrl_modifier != 0) {
                                renderer.scale += @as(f32, if (key == .plus) 1.0 else -1.0) * 0.01;
                            }
                        },
                        else => {},
                    }
                },
                .key_up => |key| {
                    switch (key) {
                        .ctrl => modifier_state &= ~ctrl_modifier,
                        else => {},
                    }
                },
                .resize => |v| {
                    _ = v;
                    std.debug.print("Resizing\n", .{});
                },
            }
        }

        @memset(surface.pixels, 0);
        const time: i32 = @truncate(std.Io.Clock.real.now(init.io).toMilliseconds());
        try renderer.redrawAll(time, time - rtime);

        window.presentSurface(surface);
        try std.Io.sleep(init.io, .fromMilliseconds(10), .awake);
    }
}
