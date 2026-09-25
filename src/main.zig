const std = @import("std");
const Window = @import("window.zig").Window;
const Surface = @import("surface.zig").Surface;
const Font = @import("font/font.zig").Font;

fn printn(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt, args);
    std.debug.print("\n", .{});
}

fn print(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt, args);
}

pub fn main(init: std.process.Init) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const window = try Window.init(allocator, .{
        .title = "YTE",
        .width = 1000,
        .height = 800,
        .resizable = true,
    });
    defer window.deinit();

    const surface = try Surface.init(allocator, window.config.width, window.config.height);
    defer surface.deinit();

    var font = try Font.init(init.io, allocator);
    defer font.deinit();

    try font.bakeAtlas();

    surface.copyBlock(font.atlas, .{ .x = 0, .y = 0, .w = @intCast(font.atlas.width), .h = @intCast(font.atlas.height) }, .{ .x = 0, .y = 0 });
    while (!window.shouldClose()) {
        window.pollEvents();

        while (window.nextEvent()) |event| {
            switch (event) {
                .key_press => |key| {
                    _ = key;
                },
                else => {},
            }
        }

        window.presentSurface(surface);
        try std.Io.sleep(init.io, .fromMilliseconds(100), .awake);
    }
}
