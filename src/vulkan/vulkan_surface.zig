const std = @import("std");
const base = @import("base.zig");
const core = @import("../core.zig");
const vulkan = @import("../vulkan.zig");
const c = @cImport(@cInclude("vulkan/vulkan.h"));

const Window = core.Window;
const VulkanInstance = vulkan.VulkanInstance;
const vkCheck = base.vkCheck;

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
                std.debug.print("[Vulkan] Could not create Surface\n", .{});
                return VulkanSurfaceError.CreateSurface;
            },
        }
    }

    pub fn destroy(self: *VulkanSurface, instance: *const VulkanInstance) void {
        c.vkDestroySurfaceKHR(instance.handle, self.handle, null);
    }
};
