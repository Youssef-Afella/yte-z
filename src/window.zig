const std = @import("std");
const builtin = @import("builtin");

const Platform = switch (builtin.os.tag) {
    .windows => @import("platform/win32.zig").Win32,
    else => @compileError("Unsupported operating system!"),
};

const Surface = @import("surface.zig").Surface;
const Event = @import("event.zig").Event;
const EventQueue = @import("event.zig").EventQueue;

pub const WindowConfig = struct {
    title: []const u8,
    width: u32,
    height: u32,
    resizable: bool,
};

pub const Window = struct {
    allocator: std.mem.Allocator,
    platform: Platform,
    config: WindowConfig,
    event_queue: EventQueue,
    should_close: bool,

    pub fn init(allocator: std.mem.Allocator, comptime config: WindowConfig) !*Window {
        const window = try allocator.create(@This());

        const platform = try Platform.init(window, config);

        const event_queue = try EventQueue.init(allocator, 256);

        window.* = .{
            .allocator = allocator,
            .platform = platform,
            .config = config,
            .event_queue = event_queue,
            .should_close = false,
        };

        return window;
    }

    pub fn deinit(w: *Window) void {
        w.event_queue.deinit();
    }

    pub fn nextEvent(w: *Window) ?Event {
        return w.event_queue.pop();
    }

    pub fn pollEvents(w: *Window) void {
        w.event_queue.reset();
        w.platform.pollEvents();
    }

    pub fn presentSurface(w: *Window, surface: *Surface) void {
        w.platform.blit(surface);
    }

    pub fn shouldClose(w: *Window) bool {
        return w.should_close;
    }
};
