const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

const util = @import("util.zig");

const c = @cImport(@cInclude("vulkan/vulkan.h"));

const vkCheck = util.vkCheck;

const core = @import("../core.zig");
const vulkan = @import("../vulkan.zig");

const VulkanInstance = vulkan.VulkanInstance;
const VulkanDevice = vulkan.VulkanDevice;
const VulkanSurface = vulkan.VulkanSurface;
const VulkanRenderPass = vulkan.VulkanRenderPass;

const Window = core.Window;

const VulkanFenceError = error{
    CreateFence,
};

pub const VulkanFence = struct {
    handle: c.VkFence,

    pub fn new(device: *const VulkanDevice) !VulkanFence {
        var createInfo = c.VkFenceCreateInfo{};
        createInfo.sType = c.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;

        var fence: c.VkFence = undefined;
        switch (c.vkCreateFence(device.handle, &createInfo, null, &fence)) {
            c.VK_SUCCESS => {
                return .{
                    .handle = fence,
                };
            },
            else => {
                std.debug.print("[Vulkan] could not create fence\n", .{});
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