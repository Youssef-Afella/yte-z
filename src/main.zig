const std = @import("std");
const Window = @import("window.zig").Window;
const Surface = @import("surface.zig").Surface;

fn printn(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt, args);
    std.debug.print("\n", .{});
}

fn print(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt, args);
}

pub fn main(init: std.process.Init) !void {
    _ = init;

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var window = try Window.init(allocator, .{
        .title = "YTE",
        .width = 1000,
        .height = 700,
        .resizable = true,
    });
    defer window.deinit();

    var surface = try Surface.init(allocator, 1000, 700);
    defer surface.deinit();

    const pixels = surface.pixels;
    for (0..100) |y| {
        for (0..100) |x| {
            pixels[y * 1000 + x] = 0xFFFFFF00;
        }
    }

    window.presentSurface(surface);

    while (!window.shouldClose()) {
        window.pollEvents();

        while (window.nextEvent()) |event| {
            switch (event) {
                .key_down => |key| printn("Key Down: {}", .{key}),
                .key_up => |key| printn("Key Up: {}", .{key}),
                else => {},
            }
        }
    }
}
