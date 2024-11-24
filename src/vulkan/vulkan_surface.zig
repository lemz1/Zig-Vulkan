const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

const util = @import("util.zig");

const c = @cImport(@cInclude("vulkan/vulkan.h"));

const vkCheck = util.vkCheck;

const core = @import("../core.zig");

const vulkan = @import("../vulkan.zig");

const VulkanInstance = vulkan.VulkanInstance;

const Window = core.Window;

const VulkanSurfaceError = error{
    CreateSurface,
};

pub const VulkanSurface = struct {
    handle: c.VkSurfaceKHR,

    pub fn new(instance: *const VulkanInstance, window: *const Window) !VulkanSurface {
        var surface: c.VkSurfaceKHR = undefined;
        switch (window.createSurface(instance, @ptrCast(&surface))) {
            c.VK_SUCCESS => {
                return .{
                    .handle = surface,
                };
            },
            else => {
                std.debug.print("[Vulkan] could not create surface\n", .{});
                return VulkanSurfaceError.CreateSurface;
            },
        }
    }

    pub fn destroy(self: *VulkanSurface, instance: *const VulkanInstance) void {
        c.vkDestroySurfaceKHR(instance.handle, self.handle, null);
    }
};
