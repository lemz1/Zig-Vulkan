const std = @import("std");
const base = @import("base.zig");
const vulkan = @import("../vulkan.zig");
const c = @cImport(@cInclude("vulkan/vulkan.h"));

const Allocator = std.mem.Allocator;
const VulkanDevice = vulkan.VulkanDevice;
const vkCheck = base.vkCheck;

const VulkanCommandPoolError = error{
    CreateCommandPool,
};

pub const VulkanCommandPool = struct {
    handle: c.VkCommandPool,

    pub fn new(device: *const VulkanDevice, queueFamilyIndex: u32) !VulkanCommandPool {
        var createInfo = c.VkCommandPoolCreateInfo{};
        createInfo.sType = c.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
        createInfo.flags = c.VK_COMMAND_POOL_CREATE_TRANSIENT_BIT;
        createInfo.queueFamilyIndex = queueFamilyIndex;

        var commandPool: c.VkCommandPool = undefined;
        switch (c.vkCreateCommandPool(device.handle, &createInfo, null, &commandPool)) {
            c.VK_SUCCESS => {
                return .{
                    .handle = commandPool,
                };
            },
            else => {
                std.debug.print("[Vulkan] Could not create Command Pool\n", .{});
                return VulkanCommandPoolError.CreateCommandPool;
            },
        }
    }

    pub fn destroy(self: *VulkanCommandPool, device: *const VulkanDevice) void {
        c.vkDestroyCommandPool(device.handle, self.handle, null);
    }

    pub fn reset(self: *const VulkanCommandPool, device: *const VulkanDevice) void {
        vkCheck(c.vkResetCommandPool(device.handle, self.handle, 0));
    }
};
