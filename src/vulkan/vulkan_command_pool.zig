const std = @import("std");
const vulkan = @import("../vulkan.zig");
const c = @cImport(@cInclude("vulkan/vulkan.h"));

const Allocator = std.mem.Allocator;
const VulkanContext = vulkan.VulkanContext;
const vkCheck = vulkan.vkCheck;

pub const VulkanCommandPool = struct {
    handle: c.VkCommandPool,

    pub fn new(context: *const VulkanContext, queueFamilyIndex: u32) !VulkanCommandPool {
        var createInfo = c.VkCommandPoolCreateInfo{};
        createInfo.sType = c.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
        createInfo.flags = c.VK_COMMAND_POOL_CREATE_TRANSIENT_BIT;
        createInfo.queueFamilyIndex = queueFamilyIndex;

        var commandPool: c.VkCommandPool = undefined;
        switch (c.vkCreateCommandPool(context.device.handle, &createInfo, null, &commandPool)) {
            c.VK_SUCCESS => {
                return .{
                    .handle = commandPool,
                };
            },
            else => {
                std.debug.print("[Vulkan] Could not create Command Pool\n", .{});
                return error.CreateCommandPool;
            },
        }
    }

    pub fn destroy(self: *VulkanCommandPool, context: *const VulkanContext) void {
        c.vkDestroyCommandPool(context.device.handle, self.handle, null);
    }

    pub fn reset(self: *const VulkanCommandPool, context: *const VulkanContext) void {
        vkCheck(c.vkResetCommandPool(context.device.handle, self.handle, 0));
    }
};
