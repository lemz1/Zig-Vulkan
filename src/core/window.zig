const std = @import("std");

const c = @cImport({
    @cDefine("GLFW_INCLUDE_VULKAN", {});
    @cInclude("GLFW/glfw3.h");
});

const vulkan = @import("../vulkan.zig");

const VulkanInstance = vulkan.VulkanInstance;

const WindowError = error{
    CreateWindow,
    CreateSurface,
    GLFWInit,
};

pub const Window = struct {
    handle: *c.GLFWwindow,
    width: u32,
    height: u32,
    title: []const u8,

    pub fn create(width: u32, height: u32, title: []const u8) !Window {
        const handle = c.glfwCreateWindow(@intCast(width), @intCast(height), title.ptr, null, null);
        if (handle == null) {
            return WindowError.CreateWindow;
        }

        return .{
            .handle = handle.?,
            .width = width,
            .height = height,
            .title = title,
        };
    }

    pub fn destroy(self: *const Window) void {
        c.glfwDestroyWindow(self.handle);
    }

    pub fn shouldClose(self: *const Window) bool {
        return c.glfwWindowShouldClose(self.handle) == 1;
    }

    pub fn createSurface(self: *const Window, instance: *const VulkanInstance) !c.VkSurfaceKHR {
        var surface: c.VkSurfaceKHR = undefined;
        switch (c.glfwCreateWindowSurface(@ptrCast(instance.handle), self.handle, null, &surface)) {
            c.VK_SUCCESS => {
                return surface;
            },
            else => {
                std.debug.print("[Vulkan] could not create surface\n", .{});
                return WindowError.CreateSurface;
            },
        }
    }
};

pub const GLFW = struct {
    pub fn init() !void {
        if (c.glfwInit() == 0) {
            return WindowError.GLFWInit;
        }
    }

    pub fn deinit() void {
        c.glfwTerminate();
    }

    pub fn pollEvents() void {
        c.glfwPollEvents();
    }
};
