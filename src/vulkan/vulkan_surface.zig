const std = @import("std");
const base = @import("base.zig");
const core = @import("../core.zig");
const vulkan = @import("../vulkan.zig");
const c = @cImport(@cInclude("vulkan/vulkan.h"));

const Window = core.Window;
const VulkanContext = vulkan.VulkanContext;
const vkCheck = base.vkCheck;

pub const VulkanSurface = struct {
    handle: c.VkSurfaceKHR,

    pub fn new(context: *const VulkanContext, window: *const Window) !VulkanSurface {
        var surface: c.VkSurfaceKHR = undefined;
        switch (window.createSurface(&context.instance, @ptrCast(&surface))) {
            c.VK_SUCCESS => {
                return .{
                    .handle = surface,
                };
            },
            else => {
                std.debug.print("[Vulkan] Could not create Surface\n", .{});
                return error.CreateSurface;
            },
        }
    }

    pub fn destroy(self: *VulkanSurface, context: *const VulkanContext) void {
        c.vkDestroySurfaceKHR(context.instance.handle, self.handle, null);
    }
};
