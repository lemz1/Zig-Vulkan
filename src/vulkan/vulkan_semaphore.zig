const std = @import("std");
const base = @import("base.zig");
const vulkan = @import("../vulkan.zig");
const c = @cImport(@cInclude("vulkan/vulkan.h"));

const Allocator = std.mem.Allocator;
const VulkanContext = vulkan.VulkanContext;
const vkCheck = base.vkCheck;

pub const VulkanSemaphore = struct {
    handle: c.VkSemaphore,

    pub fn new(context: *const VulkanContext) !VulkanSemaphore {
        var createInfo = c.VkSemaphoreCreateInfo{};
        createInfo.sType = c.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO;

        var semaphore: c.VkSemaphore = undefined;
        switch (c.vkCreateSemaphore(context.device.handle, &createInfo, null, &semaphore)) {
            c.VK_SUCCESS => {
                return .{
                    .handle = semaphore,
                };
            },
            else => {
                std.debug.print("[Vulkan] Could not create Semaphore\n", .{});
                return error.CreateSemaphore;
            },
        }
    }

    pub fn destroy(self: *VulkanSemaphore, context: *const VulkanContext) void {
        c.vkDestroySemaphore(context.device.handle, self.handle, null);
    }
};
