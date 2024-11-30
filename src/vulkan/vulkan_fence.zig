const std = @import("std");
const base = @import("base.zig");
const vulkan = @import("../vulkan.zig");
const c = @cImport(@cInclude("vulkan/vulkan.h"));

const Allocator = std.mem.Allocator;
const VulkanDevice = vulkan.VulkanDevice;
const vkCheck = base.vkCheck;

const VulkanShaderModuleError = error{
    CreateShaderModule,
};

const VulkanFenceError = error{
    CreateFence,
};

pub const VulkanFence = struct {
    handle: c.VkFence,

    pub fn new(device: *const VulkanDevice, createSignaled: bool) !VulkanFence {
        var createInfo = c.VkFenceCreateInfo{};
        createInfo.sType = c.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;
        createInfo.flags = if (createSignaled) c.VK_FENCE_CREATE_SIGNALED_BIT else 0;

        var fence: c.VkFence = undefined;
        switch (c.vkCreateFence(device.handle, &createInfo, null, &fence)) {
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

    pub fn destroy(self: *VulkanFence, device: *const VulkanDevice) void {
        c.vkDestroyFence(device.handle, self.handle, null);
    }

    pub fn wait(self: *const VulkanFence, device: *const VulkanDevice) void {
        vkCheck(c.vkWaitForFences(device.handle, 1, &self.handle, c.VK_TRUE, std.math.maxInt(u64)));
    }

    pub fn reset(self: *const VulkanFence, device: *const VulkanDevice) void {
        vkCheck(c.vkResetFences(device.handle, 1, &self.handle));
    }
};
