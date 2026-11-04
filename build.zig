const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = std.builtin.OptimizeMode.debug;

    // font-zy
    const font_zy = b.dependency("font_zy", .{}).module("font-zy");

    // win32
    const win32 = b.addTranslateC(.{
        .root_source_file = b.path("c/win32.h"),
        .target = target,
        .optimize = optimize,
    });

    // app
    const exe = b.addExecutable(.{
        .name = "yte_z",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "font-zy", .module = font_zy },
                .{ .name = "win32", .module = win32.createModule() },
            },
        }),
    });

    // libs
    exe.root_module.linkSystemLibrary("kernel32", .{});
    exe.root_module.linkSystemLibrary("user32", .{});
    exe.root_module.linkSystemLibrary("gdi32", .{});

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
