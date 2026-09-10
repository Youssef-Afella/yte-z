const std = @import("std");

pub const Surface = struct {
    allocator: std.mem.Allocator,
    width: u32,
    height: u32,
    pixels: []u32,

    pub fn init(allocator: std.mem.Allocator, width: u32, height: u32) !*Surface {
        const surface = try allocator.create(@This());
        surface.* = .{
            .allocator = allocator,
            .width = width,
            .height = height,
            .pixels = try allocator.alloc(u32, width * height),
        };

        return surface;
    }

    pub fn deinit(s: *Surface) void {
        s.allocator.free(s.pixels);
        s.allocator.destroy(s);
    }
};
