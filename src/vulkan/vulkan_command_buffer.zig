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
const VulkanCommandPool = vulkan.VulkanCommandPool;

const Window = core.Window;

const VulkanCommandBufferError = error{
    CreateCommandBuffer,
};

pub const VulkanCommandBuffer = struct {
    handle: c.VkCommandBuffer,

    pub fn new(device: *const VulkanDevice, commandPool: *const VulkanCommandPool) !VulkanCommandBuffer {
        var allocateInfo = c.VkCommandBufferAllocateInfo{};
        allocateInfo.sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
        allocateInfo.commandPool = commandPool.handle;
        allocateInfo.level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY;
        allocateInfo.commandBufferCount = 1;

        var commandBuffer: c.VkCommandBuffer = undefined;
        switch (c.vkAllocateCommandBuffers(device.handle, &allocateInfo, &commandBuffer)) {
            c.VK_SUCCESS => {
                return .{
                    .handle = commandBuffer,
                };
            },
            else => {
                std.debug.print("[Vulkan] could not create command buffer\n", .{});
                return VulkanCommandBufferError.CreateCommandBuffer;
            },
        }
    }

    pub fn destroy(self: *VulkanCommandBuffer, device: *const VulkanDevice, commandPool: *const VulkanCommandPool) void {
        c.vkFreeCommandBuffers(device.handle, commandPool.handle, 1, &self.handle);
    }

    pub fn begin(self: *const VulkanCommandBuffer) void {
        var beginInfo = c.VkCommandBufferBeginInfo{};
        beginInfo.sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
        beginInfo.flags = c.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
        vkCheck(c.vkBeginCommandBuffer(self.handle, &beginInfo));
    }

    pub fn end(self: *const VulkanCommandBuffer) void {
        vkCheck(c.vkEndCommandBuffer(self.handle));
    }

    pub fn beginRenderPass(self: *const VulkanCommandBuffer, beginInfo: *const c.VkRenderPassBeginInfo) void {
        c.vkCmdBeginRenderPass(self.handle, beginInfo, c.VK_SUBPASS_CONTENTS_INLINE);
    }

    pub fn endRenderPass(self: *const VulkanCommandBuffer) void {
        c.vkCmdEndRenderPass(self.handle);
    }
};