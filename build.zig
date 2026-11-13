const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const link_libc = false;

    // font-zy
    const font_zy = b.dependency("font_zy", .{
        .target = target,
        .optimize = optimize,
    }).module("font-zy");

    // app
    const exe = b.addExecutable(.{
        .name = "yte_z",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = link_libc,
            .imports = &.{
                .{ .name = "font-zy", .module = font_zy },
            },
        }),
    });

    // libs
    exe.root_module.linkSystemLibrary("kernel32", .{});
    exe.root_module.linkSystemLibrary("user32", .{});
    exe.root_module.linkSystemLibrary("gdi32", .{});

    // xp fix
    if (target.result.os.version_range.windows.min == .xp) {
        const zigxp = b.addObject(.{
            .name = "zigxp",
            .root_module = b.createModule(.{
                .root_source_file = b.path("zigxp.zig"),
                .target = target,
                .optimize = optimize,
            }),
        });
        exe.root_module.addObject(zigxp);
    }

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
