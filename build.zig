const std = @import("std");

pub fn build(b: *std.Build) void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const target = b.standardTargetOptions(.{});

    switch (target.result.os.tag) {
        .windows, .macos, .linux => {},
        else => {
            std.debug.print("unsupported operating system: {}\n", .{target.result.os});
            return;
        },
    }

    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "Vulkan",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.linkLibC();

    addPlatformLibs(exe, target);

    addGlfw(exe, b, target, optimize);
    addVulkan(exe, b, target, optimize, allocator);

    b.installDirectory(.{
        .source_dir = b.path("assets"),
        .install_dir = .{ .bin = {} },
        .install_subdir = "assets",
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}

fn addPlatformLibs(compile: *std.Build.Step.Compile, target: std.Build.ResolvedTarget) void {
    switch (target.result.os.tag) {
        .windows => {
            compile.linkSystemLibrary("user32");
            compile.linkSystemLibrary("kernel32");
            compile.linkSystemLibrary("gdi32");
            compile.linkSystemLibrary("shell32");
            compile.linkSystemLibrary("ole32");
            compile.linkSystemLibrary("uuid");
        },
        .macos => {},
        .linux => {},
        else => unreachable,
    }
}

fn addGlfw(compile: *std.Build.Step.Compile, b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) void {
    const glfw = b.addStaticLibrary(.{
        .name = "glfw",
        .target = target,
        .optimize = optimize,
    });

    glfw.addIncludePath(b.path("vnd/glfw/include/GLFW"));
    glfw.linkLibC();
    addPlatformLibs(glfw, target);

    const flags = switch (target.result.os.tag) {
        .windows => &[_][]const u8{"-D_GLFW_WIN32"},
        .macos => &[_][]const u8{"-D_GLFW_COCOA"},
        .linux => &[_][]const u8{"-D_GLFW_X11"},
        else => unreachable,
    };

    glfw.addCSourceFiles(.{
        .files = &.{
            "context.c",
            "init.c",
            "input.c",
            "monitor.c",
            "vulkan.c",
            "window.c",
            "platform.c",
            "null_init.c",
            "null_joystick.c",
            "null_monitor.c",
            "null_window.c",
        },
        .flags = flags,
        .root = b.path("vnd/glfw/src"),
    });

    switch (target.result.os.tag) {
        .windows => {
            glfw.addCSourceFiles(.{
                .files = &.{
                    "win32_init.c",
                    "win32_joystick.c",
                    "win32_module.c",
                    "win32_monitor.c",
                    "win32_time.c",
                    "win32_thread.c",
                    "win32_window.c",
                    "wgl_context.c",
                    "egl_context.c",
                    "osmesa_context.c",
                },
                .flags = flags,
                .root = b.path("vnd/glfw/src"),
            });
        },
        .macos => {
            glfw.addCSourceFiles(.{
                .files = &.{
                    "cocoa_init.m",
                    "cocoa_monitor.m",
                    "cocoa_window.m",
                    "cocoa_joystick.m",
                    "cocoa_time.c",
                    "nsgl_context.m",
                    "posix_thread.c",
                    "posix_module.c",
                    "osmesa_context.c",
                    "egl_context.c",
                },
                .flags = flags,
                .root = b.path("vnd/glfw/src"),
            });
        },
        .linux => {
            glfw.addCSourceFiles(.{
                .files = &.{
                    "x11_init.c",
                    "x11_monitor.c",
                    "x11_window.c",
                    "xkb_unicode.c",
                    "posix_module.c",
                    "posix_time.c",
                    "posix_thread.c",
                    "posix_module.c",
                    "glx_context.c",
                    "egl_context.c",
                    "osmesa_context.c",
                    "linux_joystick.c",
                },
                .flags = flags,
                .root = b.path("vnd/glfw/src"),
            });
        },
        else => unreachable,
    }

    compile.addIncludePath(b.path("vnd/glfw/include"));
    compile.linkLibrary(glfw);
}

fn addVulkan(compile: *std.Build.Step.Compile, _: *std.Build, _: std.Build.ResolvedTarget, _: std.builtin.OptimizeMode, allocator: std.mem.Allocator) void {
    const vulkanSDKPath = std.process.getEnvVarOwned(allocator, "VULKAN_SDK") catch {
        @panic("could not find VULKAN_SDK environment variable\n");
    };
    defer allocator.free(vulkanSDKPath);

    const vulkanInclude = std.fs.path.join(allocator, &[_][]const u8{ vulkanSDKPath, "Include" }) catch {
        @panic("could not create vulkan include path");
    };
    defer allocator.free(vulkanInclude);

    const vulkanLib = std.fs.path.join(allocator, &[_][]const u8{ vulkanSDKPath, "Lib" }) catch {
        @panic("could not create vulkan lib path");
    };
    defer allocator.free(vulkanLib);

    compile.addIncludePath(.{ .cwd_relative = vulkanInclude });

    compile.addLibraryPath(.{ .cwd_relative = vulkanLib });
    compile.linkSystemLibrary("vulkan-1");
}
