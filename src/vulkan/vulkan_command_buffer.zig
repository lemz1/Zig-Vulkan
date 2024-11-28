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
const VulkanPipeline = vulkan.VulkanPipeline;
const VulkanBuffer = vulkan.VulkanBuffer;

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

    pub fn bindGraphicsPipeline(self: *const VulkanCommandBuffer, pipeline: *const VulkanPipeline) void {
        c.vkCmdBindPipeline(self.handle, c.VK_PIPELINE_BIND_POINT_GRAPHICS, pipeline.handle);
    }

    pub fn bindVertexBuffer(self: *const VulkanCommandBuffer, vertexBuffer: *const VulkanBuffer, offset: c.VkDeviceSize) void {
        c.vkCmdBindVertexBuffers(self.handle, 0, 1, &vertexBuffer.handle, &offset);
    }

    pub fn bindIndexBuffer(self: *const VulkanCommandBuffer, indexBuffer: *const VulkanBuffer, offset: c.VkDeviceSize) void {
        c.vkCmdBindIndexBuffer(self.handle, indexBuffer.handle, offset, c.VK_INDEX_TYPE_UINT32);
    }

    pub fn draw(self: *const VulkanCommandBuffer, vertexCount: u32) void {
        c.vkCmdDraw(self.handle, vertexCount, 1, 0, 0);
    }

    pub fn drawIndexed(self: *const VulkanCommandBuffer, indexCount: u32) void {
        c.vkCmdDrawIndexed(self.handle, indexCount, 1, 0, 0, 0);
    }

    pub fn setViewport(self: *const VulkanCommandBuffer, width: f32, height: f32) void {
        const viewport = c.VkViewport{
            .x = 0.0,
            .y = 0.0,
            .width = width,
            .height = height,
        };
        c.vkCmdSetViewport(self.handle, 0, 1, &viewport);
    }

    pub fn setScissor(self: *const VulkanCommandBuffer, width: u32, height: u32) void {
        const scissor = c.VkRect2D{
            .offset = .{ .x = 0, .y = 0 },
            .extent = .{ .width = width, .height = height },
        };
        c.vkCmdSetScissor(self.handle, 0, 1, &scissor);
    }

    pub fn copyBuffer(self: *const VulkanCommandBuffer, srcBuffer: *const VulkanBuffer, dstBuffer: *const VulkanBuffer, region: c.VkBufferCopy) void {
        c.vkCmdCopyBuffer(self.handle, srcBuffer.handle, dstBuffer.handle, 1, &region);
    }
};
