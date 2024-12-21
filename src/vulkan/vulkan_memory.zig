const std = @import("std");
const vulkan = @import("../vulkan.zig");
const c = @cImport(@cInclude("vulkan/vulkan.h"));

const VulkanContext = vulkan.VulkanContext;
const VulkanBuffer = vulkan.VulkanBuffer;
const VulkanImage = vulkan.VulkanImage;
const vkCheck = vulkan.vkCheck;
const findMemoryType = vulkan.findMemoryType;

pub const VulkanMemory = struct {
    handle: c.VkDeviceMemory,
    size: c.VkDeviceSize,
    typeFilter: u32,
    memoryProperties: c.VkMemoryPropertyFlags,

    pub fn new(context: *const VulkanContext, size: c.VkDeviceSize, typeFilter: u32, memoryProperties: c.VkMemoryPropertyFlags) !VulkanMemory {
        const memoryIndex = try findMemoryType(context, typeFilter, memoryProperties);

        var allocateInfo = c.VkMemoryAllocateInfo{};
        allocateInfo.sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
        allocateInfo.allocationSize = size;
        allocateInfo.memoryTypeIndex = memoryIndex;

        var memory: c.VkDeviceMemory = undefined;
        switch (c.vkAllocateMemory(context.device.handle, &allocateInfo, null, &memory)) {
            c.VK_SUCCESS => {},
            else => {
                std.debug.print("[Vulkan] Could not allocate Memory\n", .{});
                return error.AllocateMemory;
            },
        }

        return .{
            .handle = memory,
            .size = size,
            .typeFilter = typeFilter,
            .memoryProperties = memoryProperties,
        };
    }

    pub fn destroy(self: *VulkanMemory, context: *const VulkanContext) void {
        c.vkFreeMemory(context.device.handle, self.handle, null);
    }

    pub fn bindBuffer(self: *const VulkanMemory, context: *const VulkanContext, buffer: *const VulkanBuffer, offset: c.VkDeviceSize) void {
        vkCheck(c.vkBindBufferMemory(context.device.handle, buffer.handle, self.handle, offset));
    }

    pub fn bindImage(self: *const VulkanMemory, context: *const VulkanContext, image: *const VulkanImage, offset: c.VkDeviceSize) void {
        vkCheck(c.vkBindImageMemory(context.device.handle, image.handle, self.handle, offset));
    }
};
