const std = @import("std");
const vulkan = @import("../vulkan.zig");
const c = @cImport(@cInclude("vulkan/vulkan.h"));

const Allocator = std.mem.Allocator;
const vkCheck = vulkan.vkCheck;

const VulkanFence = vulkan.VulkanFence;

pub const VulkanQueue = struct {
    handle: c.VkQueue,
    familyIndex: u32,

    pub fn new(queue: c.VkQueue, familyIndex: u32) VulkanQueue {
        return .{
            .handle = queue,
            .familyIndex = familyIndex,
        };
    }

    pub fn submit(self: *const VulkanQueue, submitInfo: *const c.VkSubmitInfo, fence: ?*const VulkanFence) void {
        const fenceHandle: c.VkFence = if (fence) |v| v.handle else null;

        vkCheck(c.vkQueueSubmit(self.handle, 1, submitInfo, fenceHandle));
    }

    pub fn present(self: *const VulkanQueue, presentInfo: *const c.VkPresentInfoKHR) c.VkResult {
        return c.vkQueuePresentKHR(self.handle, presentInfo);
    }

    pub fn wait(self: *const VulkanQueue) void {
        vkCheck(c.vkQueueWaitIdle(self.handle));
    }
};
