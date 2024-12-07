const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    switch (target.result.os.tag) {
        .windows, .macos, .linux => {},
        else => {
            const message = std.fmt.allocPrint(b.allocator, "unsupported operating system: {}\n", .{target.result.os}) catch {
                @panic("could not create error message");
            };
            @panic(message);
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
    addVulkan(exe, b, target, optimize);
    addZMath(exe, b, target, optimize);
    addStb(exe, b, target, optimize);

    const compileShadersStep = compileShaders(b);

    var copyAssetsStep = b.addInstallDirectory(.{
        .source_dir = b.path("assets"),
        .install_dir = .{ .bin = {} },
        .install_subdir = "assets",
    });
    copyAssetsStep.step.dependOn(compileShadersStep);

    b.getInstallStep().dependOn(&copyAssetsStep.step);

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

fn addVulkan(compile: *std.Build.Step.Compile, b: *std.Build, target: std.Build.ResolvedTarget, _: std.builtin.OptimizeMode) void {
    const vulkanSDKPath = std.process.getEnvVarOwned(b.allocator, "VULKAN_SDK") catch {
        @panic("could not find VULKAN_SDK environment variable\n");
    };

    const vulkanInclude = std.fmt.allocPrint(b.allocator, "{s}/Include", .{vulkanSDKPath}) catch {
        @panic("could not create vulkan include path");
    };

    const vulkanLib = std.fmt.allocPrint(b.allocator, "{s}/Lib", .{vulkanSDKPath}) catch {
        @panic("could not create vulkan lib path");
    };

    compile.addIncludePath(.{ .cwd_relative = vulkanInclude });

    compile.addLibraryPath(.{ .cwd_relative = vulkanLib });
    compile.linkSystemLibrary(if (target.result.os.tag == .windows) "vulkan-1" else "vulkan");

    compile.addLibraryPath(b.path("vnd/glslang"));
    compile.linkSystemLibrary("glslang");
    compile.linkSystemLibrary("glslang-default-resource-limits");
}

fn addZMath(compile: *std.Build.Step.Compile, b: *std.Build, _: std.Build.ResolvedTarget, _: std.builtin.OptimizeMode) void {
    const zmath = b.dependency("zmath", .{});
    compile.root_module.addImport("zmath", zmath.module("root"));
}

fn addStb(compile: *std.Build.Step.Compile, b: *std.Build, _: std.Build.ResolvedTarget, _: std.builtin.OptimizeMode) void {
    compile.addCSourceFile(.{ .file = b.path("src/vnd/stb/stb_image.c") });
    compile.addIncludePath(b.path("vnd/stb"));
}

fn compileShaders(b: *std.Build) *std.Build.Step {
    const step = b.step("compile-shaders", "Compile GLSL shaders to SPIR-V");

    const fs = std.fs.cwd();
    const handle = fs.openDir("assets/shaders", .{ .iterate = true }) catch {
        @panic("Could not open shader source directory");
    };

    var iter = handle.iterate();
    while (iter.next() catch {
        return step;
    }) |entry| {
        const ext = std.fs.path.extension(entry.name);
        if (std.mem.eql(u8, ext, ".frag") or std.mem.eql(u8, ext, ".vert")) {
            const inputPath = std.fmt.allocPrint(b.allocator, "assets/shaders/{s}", .{entry.name}) catch {
                @panic("Could not allocate shader input path");
            };

            const outputPath = std.fmt.allocPrint(b.allocator, "assets/shaders/{s}.spv", .{entry.name}) catch {
                @panic("Could not allocate shader output path");
            };

            const cmd = b.addSystemCommand(&.{ "glslangValidator", "-V", inputPath, "-o", outputPath });

            step.dependOn(&cmd.step);
        }
    }

    return step;
}
