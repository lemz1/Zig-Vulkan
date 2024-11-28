const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

const c = @cImport(@cInclude("vulkan/vulkan.h"));

const util = @import("util.zig");

const vkCheck = util.vkCheck;

const core = @import("../core.zig");
const vulkan = @import("../vulkan.zig");

const VulkanFence = vulkan.VulkanFence;

pub const VulkanQueue = struct {
    queue: c.VkQueue,
    familyIndex: u32,

    pub fn new(queue: c.VkQueue, familyIndex: u32) VulkanQueue {
        return .{
            .queue = queue,
            .familyIndex = familyIndex,
        };
    }

    pub fn submit(self: *const VulkanQueue, submitInfo: *const c.VkSubmitInfo, fence: ?*const VulkanFence) void {
        const fenceHandle: c.VkFence = if (fence) |v| v.handle else null;

        vkCheck(c.vkQueueSubmit(self.queue, 1, submitInfo, fenceHandle));
    }

    pub fn present(self: *const VulkanQueue, presentInfo: *const c.VkPresentInfoKHR) c.VkResult {
        return c.vkQueuePresentKHR(self.queue, presentInfo);
    }

    pub fn wait(self: *const VulkanQueue) void {
        vkCheck(c.vkQueueWaitIdle(self.queue));
    }
};
