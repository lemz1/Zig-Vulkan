const std = @import("std");
const base = @import("base.zig");
const vulkan = @import("../vulkan.zig");
const c = @cImport(@cInclude("vulkan/vulkan.h"));

const Allocator = std.mem.Allocator;
const VulkanContext = vulkan.VulkanContext;
const vkCheck = base.vkCheck;
const memcpy = @cImport(@cInclude("memory.h")).memcpy;

pub const VulkanBuffer = struct {
    handle: c.VkBuffer,

    properties: c.VkMemoryPropertyFlags,
    requirements: c.VkMemoryRequirements,

    pub fn new(
        context: *const VulkanContext,
        size: u64,
        usage: c.VkBufferUsageFlags,
        memoryProperties: c.VkMemoryPropertyFlags,
    ) !VulkanBuffer {
        var resizableUsage = usage;
        if (!context.device.hasResizableBAR) {
            resizableUsage |= c.VK_BUFFER_USAGE_TRANSFER_DST_BIT;
        }

        var createInfo = c.VkBufferCreateInfo{};
        createInfo.sType = c.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
        createInfo.size = size;
        createInfo.usage = resizableUsage;

        var buffer: c.VkBuffer = undefined;
        switch (c.vkCreateBuffer(context.device.handle, &createInfo, null, &buffer)) {
            c.VK_SUCCESS => {},
            else => {
                std.debug.print("[Vulkan] Could not create Buffer\n", .{});
                return error.CreateBuffer;
            },
        }

        var memoryRequirements: c.VkMemoryRequirements = undefined;
        c.vkGetBufferMemoryRequirements(context.device.handle, buffer, &memoryRequirements);

        return .{
            .handle = buffer,

            .properties = memoryProperties,
            .requirements = memoryRequirements,
        };
    }

    pub fn destroy(self: *VulkanBuffer, context: *const VulkanContext) void {
        c.vkDestroyBuffer(context.device.handle, self.handle, null);
    }
};
