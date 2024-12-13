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
    addGLSLang(exe, b, target, optimize);
    addSPIRVCross(exe, b, target, optimize);

    var copyAssetsStep = b.addInstallDirectory(.{
        .source_dir = b.path("assets"),
        .install_dir = .{ .bin = {} },
        .install_subdir = "assets",
    });

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
}

fn addZMath(compile: *std.Build.Step.Compile, b: *std.Build, _: std.Build.ResolvedTarget, _: std.builtin.OptimizeMode) void {
    const zmath = b.dependency("zmath", .{});
    compile.root_module.addImport("zmath", zmath.module("root"));
}

fn addStb(compile: *std.Build.Step.Compile, b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) void {
    const stb = b.addStaticLibrary(.{
        .name = "stb",
        .target = target,
        .optimize = optimize,
    });
    stb.linkLibC();
    stb.addCSourceFile(.{ .file = b.path("src/vnd/stb/stb_image.c") });
    stb.addIncludePath(b.path("vnd/stb"));

    compile.linkLibrary(stb);
    compile.addIncludePath(b.path("vnd/stb"));
}

fn addGLSLang(compile: *std.Build.Step.Compile, b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) void {
    const glslang = b.addStaticLibrary(.{
        .name = "glslang",
        .target = target,
        .optimize = optimize,
    });
    glslang.linkLibCpp();
    glslang.addCSourceFiles(.{
        .root = b.path("vnd/glslang/glslang"),
        .flags = &.{},
        .files = &.{
            "stub.cpp",

            "OSDependent/Windows/ossource.cpp",

            "GenericCodeGen/CodeGen.cpp",
            "GenericCodeGen/Link.cpp",

            "MachineIndependent/glslang_tab.cpp",
            "MachineIndependent/attribute.cpp",
            "MachineIndependent/Constant.cpp",
            "MachineIndependent/iomapper.cpp",
            "MachineIndependent/InfoSink.cpp",
            "MachineIndependent/Initialize.cpp",
            "MachineIndependent/IntermTraverse.cpp",
            "MachineIndependent/Intermediate.cpp",
            "MachineIndependent/ParseContextBase.cpp",
            "MachineIndependent/ParseHelper.cpp",
            "MachineIndependent/PoolAlloc.cpp",
            "MachineIndependent/RemoveTree.cpp",
            "MachineIndependent/Scan.cpp",
            "MachineIndependent/ShaderLang.cpp",
            "MachineIndependent/SpirvIntrinsics.cpp",
            "MachineIndependent/SymbolTable.cpp",
            "MachineIndependent/Versions.cpp",
            "MachineIndependent/intermOut.cpp",
            "MachineIndependent/limits.cpp",
            "MachineIndependent/linkValidate.cpp",
            "MachineIndependent/parseConst.cpp",
            "MachineIndependent/reflection.cpp",
            "MachineIndependent/preprocessor/Pp.cpp",
            "MachineIndependent/preprocessor/PpAtom.cpp",
            "MachineIndependent/preprocessor/PpContext.cpp",
            "MachineIndependent/preprocessor/PpScanner.cpp",
            "MachineIndependent/preprocessor/PpTokens.cpp",
            "MachineIndependent/propagateNoContraction.cpp",

            "CInterface/glslang_c_interface.cpp",

            "ResourceLimits/ResourceLimits.cpp",
            "ResourceLimits/resource_limits_c.cpp",
        },
    });
    glslang.addCSourceFiles(.{
        .root = b.path("vnd/glslang/SPIRV"),
        .flags = &.{},
        .files = &.{
            "GlslangToSpv.cpp",
            "InReadableOrder.cpp",
            "Logger.cpp",
            "SpvBuilder.cpp",
            "SpvPostProcess.cpp",
            "doc.cpp",
            "SpvTools.cpp",
            "disassemble.cpp",
            "CInterface/spirv_c_interface.cpp",
            "SPVRemapper.cpp",
            "doc.cpp",
        },
    });
    glslang.addIncludePath(b.path("vnd/glslang/generated"));
    glslang.addIncludePath(b.path("vnd/glslang"));

    compile.linkLibrary(glslang);
    compile.addIncludePath(b.path("vnd/glslang"));
}

fn addSPIRVCross(compile: *std.Build.Step.Compile, b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) void {
    const spirvCross = b.addStaticLibrary(.{
        .name = "SPIRV-Cross",
        .target = target,
        .optimize = optimize,
    });
    spirvCross.linkLibCpp();
    spirvCross.addCSourceFiles(.{
        .root = b.path("vnd/SPIRV-Cross"),
        .flags = &.{},
        .files = &.{
            "spirv_cross.cpp",
            "spirv_parser.cpp",
            "spirv_cross_parsed_ir.cpp",
            "spirv_cfg.cpp",
            "spirv_cross_c.cpp",
            "spirv_glsl.cpp",
            "spirv_cpp.cpp",
            "spirv_msl.cpp",
            "spirv_hlsl.cpp",
            "spirv_reflect.cpp",
            "spirv_cross_util.cpp",
        },
    });

    compile.addIncludePath(b.path("vnd/SPIRV-Cross"));
    compile.linkLibrary(spirvCross);
}
