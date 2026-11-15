const std = @import("std");
const builtin = @import("builtin");

const Platform = switch (builtin.os.tag) {
    .windows => @import("platform/win32.zig").Win32,
    .linux => @import("platform/x11.zig").X11,
    else => @compileError("Unsupported operating system!"),
};

const Surface = @import("surface.zig").Surface;

const EventQueue = @import("event.zig").EventQueue;

pub const Event = union(enum) {
    resize: struct { width: u32, height: u32 },
    key_down: Key,
    key_up: Key,
    char: u32,
};

pub const Key = enum {
    right,
    left,
    up,
    down,
    ctrl,
    plus,
    minus,
    s,
    i,
    k,
    j,
    l,
    unknown,
};

pub const WindowConfig = struct {
    title: []const u8,
    width: u32,
    height: u32,
    resizable: bool,
};

pub const Window = struct {
    gpa: std.mem.Allocator,
    platform: Platform,
    surface: Surface,
    config: WindowConfig,
    events: EventQueue,
    should_close: bool,

    pub fn init(gpa: std.mem.Allocator, comptime config: WindowConfig) !*Window {
        const window = try gpa.create(Window);

        const pixels = try gpa.alloc(u32, config.width * config.height);
        const platform = try Platform.init(window, config);
        const events = try EventQueue.init(gpa, 256);

        window.* = .{
            .gpa = gpa,
            .platform = platform,
            .surface = .{ .width = config.width, .height = config.height, .pixels = pixels },
            .config = config,
            .events = events,
            .should_close = false,
        };

        return window;
    }

    pub fn deinit(w: *Window) void {
        w.events.deinit();
        w.platform.deinit();
        w.gpa.destroy(w);
    }

    pub fn getSurface(w: *Window) *Surface {
        return &w.surface;
    }

    pub fn nextEvent(w: *Window) ?Event {
        return w.events.pop();
    }

    pub fn pollEvents(w: *Window) void {
        w.events.reset();
        w.platform.pollEvents();
    }

    pub fn updateSurface(w: *Window) void {
        w.platform.blit();
    }

    pub fn shouldClose(w: *Window) bool {
        return w.should_close;
    }
};
