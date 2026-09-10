const std = @import("std");

pub const Event = union(enum) {
    resize: struct { width: u32, height: u32 },
    key_down: u32,
    key_up: u32,
};

pub const EventQueue = struct {
    allocator: std.mem.Allocator,
    events: []Event,
    count: usize = 0,

    pub fn init(allocator: std.mem.Allocator, capacity: usize) !EventQueue {
        return .{
            .allocator = allocator,
            .events = try allocator.alloc(Event, capacity),
        };
    }

    pub fn deinit(e: *EventQueue) void {
        e.allocator.free(e.events);
    }

    pub fn push(e: *EventQueue, event: Event) void {
        e.events[e.count] = event;
        e.count += 1;
    }

    pub fn pop(e: *EventQueue) ?Event {
        if (e.count == 0) return null;
        e.count -= 1;
        return e.events[e.count];
    }

    pub fn reset(e: *EventQueue) void {
        e.count = 0;
    }
};
