const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

const util = @import("util.zig");

const c = @cImport(@cInclude("vulkan/vulkan.h"));

const vkCheck = util.vkCheck;

const core = @import("../core.zig");

const VulkanInstance = @import("vulkan_instance.zig").VulkanInstance;

const Window = core.Window;

const VulkanSurfaceError = error{
    CreateSurface,
};

pub const VulkanSurface = struct {
    handle: c.VkSurfaceKHR,

    pub fn new(instance: *const VulkanInstance, window: *const Window) !VulkanSurface {
        const handle: c.VkSurfaceKHR = @ptrCast(try window.createSurface(instance));
        return .{
            .handle = handle,
        };
    }

    pub fn destroy(self: *VulkanSurface, instance: *const VulkanInstance) void {
        c.vkDestroySurfaceKHR(instance.handle, self.handle, null);
    }
};
