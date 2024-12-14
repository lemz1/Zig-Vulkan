const std = @import("std");
const base = @import("base.zig");
const vulkan = @import("../vulkan.zig");
const c = @cImport(@cInclude("vulkan/vulkan.h"));

const Allocator = std.mem.Allocator;
const VulkanContext = vulkan.VulkanContext;
const vkCheck = base.vkCheck;

const VulkanFenceError = error{
    CreateFence,
};

pub const VulkanFence = struct {
    handle: c.VkFence,

    pub fn new(context: *const VulkanContext, createSignaled: bool) !VulkanFence {
        var createInfo = c.VkFenceCreateInfo{};
        createInfo.sType = c.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;
        createInfo.flags = if (createSignaled) c.VK_FENCE_CREATE_SIGNALED_BIT else 0;

        var fence: c.VkFence = undefined;
        switch (c.vkCreateFence(context.device.handle, &createInfo, null, &fence)) {
            c.VK_SUCCESS => {
                return .{
                    .handle = fence,
                };
            },
            else => {
                std.debug.print("[Vulkan] Could not create Fence\n", .{});
                return VulkanFenceError.CreateFence;
            },
        }
    }

    pub fn destroy(self: *VulkanFence, context: *const VulkanContext) void {
        c.vkDestroyFence(context.device.handle, self.handle, null);
    }

    pub fn wait(self: *const VulkanFence, context: *const VulkanContext) void {
        vkCheck(c.vkWaitForFences(context.device.handle, 1, &self.handle, c.VK_TRUE, std.math.maxInt(u64)));
    }

    pub fn reset(self: *const VulkanFence, context: *const VulkanContext) void {
        vkCheck(c.vkResetFences(context.device.handle, 1, &self.handle));
    }
};
