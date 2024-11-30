const std = @import("std");
const base = @import("base.zig");
const vulkan = @import("../vulkan.zig");
const c = @cImport(@cInclude("vulkan/vulkan.h"));

const Allocator = std.mem.Allocator;
const VulkanDevice = vulkan.VulkanDevice;
const vkCheck = base.vkCheck;

const VulkanSemaphoreError = error{
    CreateSemaphore,
};

pub const VulkanSemaphore = struct {
    handle: c.VkSemaphore,

    pub fn new(device: *const VulkanDevice) !VulkanSemaphore {
        var createInfo = c.VkSemaphoreCreateInfo{};
        createInfo.sType = c.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO;

        var semaphore: c.VkSemaphore = undefined;
        switch (c.vkCreateSemaphore(device.handle, &createInfo, null, &semaphore)) {
            c.VK_SUCCESS => {
                return .{
                    .handle = semaphore,
                };
            },
            else => {
                std.debug.print("[Vulkan] Could not create Semaphore\n", .{});
                return VulkanSemaphoreError.CreateSemaphore;
            },
        }
    }

    pub fn destroy(self: *VulkanSemaphore, device: *const VulkanDevice) void {
        c.vkDestroySemaphore(device.handle, self.handle, null);
    }
};
