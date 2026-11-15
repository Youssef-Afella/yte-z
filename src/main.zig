const std = @import("std");
const Window = @import("window.zig").Window;
const Surface = @import("surface.zig").Surface;
const Font = @import("font.zig").Font;
const Text = @import("text.zig").Text;
const TextRenderer = @import("renderer.zig").TextRenderer;

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const gpa = init.gpa;

    const args = try init.minimal.args.toSlice(arena);
    if (args.len == 1) {
        std.debug.print("Usage: yte {{path to file}}", .{});
        return;
    }

    var text = try Text.init(gpa, init.io, args[1]);
    defer text.deinit();

    var window = try Window.init(gpa, "YTE", 1000, 800);
    defer window.deinit(gpa);

    const surface = window.getSurface();

    var font = try Font.init(init.io, arena);
    defer font.deinit();

    var renderer = TextRenderer.init(&text, &font, surface);

    var modifier_state: u8 = 0;
    const ctrl_modifier: u8 = 1 << 0;

    var rtime: i32 = @truncate(std.Io.Clock.real.now(init.io).toMilliseconds());

    while (!window.shouldClose()) {
        window.pollEvents();

        if (window.events.count != 0) rtime = @truncate(std.Io.Clock.real.now(init.io).toMilliseconds());
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
                        .i, .k => {
                            if (modifier_state & ctrl_modifier != 0) {
                                renderer.move(0, if (key == .k) 1 else -1);
                            }
                        },
                        .j, .l => {
                            if (modifier_state & ctrl_modifier != 0) {
                                renderer.move(if (key == .l) 1 else -1, 0);
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

        surface.clear(0);
        const time: i32 = @truncate(std.Io.Clock.real.now(init.io).toMilliseconds());
        try renderer.redrawAll(time, time - rtime);

        window.updateSurface();
        try std.Io.sleep(init.io, .fromMilliseconds(10), .awake);
    }
}
