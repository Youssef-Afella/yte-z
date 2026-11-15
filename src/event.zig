const std = @import("std");
const Event = @import("window.zig").Event;

pub const EventQueue = struct {
    events: []Event,
    count: usize = 0,
    head: usize = 0,

    pub fn init(gpa: std.mem.Allocator, capacity: usize) !EventQueue {
        return .{
            .events = try gpa.alloc(Event, capacity),
        };
    }

    pub fn deinit(e: *EventQueue, gpa: std.mem.Allocator) void {
        gpa.free(e.events);
    }

    pub fn push(e: *EventQueue, event: Event) void {
        e.events[e.count] = event;
        e.count += 1;
    }

    pub fn pop(e: *EventQueue) ?Event {
        if (e.count == 0 or e.head >= e.count) return null;
        const event = e.events[e.head];
        e.head += 1;
        return event;
    }

    pub fn reset(e: *EventQueue) void {
        e.count = 0;
        e.head = 0;
    }
};
