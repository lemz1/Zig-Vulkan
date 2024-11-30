const std = @import("std");
const vulkan = @import("../vulkan.zig");
const c = @cImport({
    @cInclude("vulkan/vulkan.h");
    @cDefine("GLFW_INCLUDE_NONE", {});
    @cInclude("GLFW/glfw3.h");
});

const VulkanInstance = vulkan.VulkanInstance;

const WindowError = error{
    CreateWindow,
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

    pub fn createSurface(self: *const Window, instance: *const VulkanInstance, surface: *c.VkSurfaceKHR) c.VkResult {
        return c.glfwCreateWindowSurface(@ptrCast(instance.handle), self.handle, null, surface);
    }
};

pub const GLFW = struct {
    pub fn init() !void {
        if (c.glfwInit() == 0) {
            return WindowError.GLFWInit;
        }

        c.glfwWindowHint(c.GLFW_CLIENT_API, c.GLFW_NO_API);
    }

    pub fn deinit() void {
        c.glfwTerminate();
    }

    pub fn pollEvents() void {
        c.glfwPollEvents();
    }

    pub fn instanceExtensions(count: *u32) [*c][*c]const u8 {
        return c.glfwGetRequiredInstanceExtensions(count);
    }
};
