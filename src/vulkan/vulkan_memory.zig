const std = @import("std");
const base = @import("base.zig");
const vulkan = @import("../vulkan.zig");
const c = @cImport(@cInclude("vulkan/vulkan.h"));

const VulkanContext = vulkan.VulkanContext;

pub const VulkanMemory = struct {
    handle: c.VkDeviceMemory,
    size: c.VkDeviceSize,
    typeFilter: u32,
    memoryProperties: c.VkMemoryPropertyFlags,

    pub fn new(context: *const VulkanContext, size: c.VkDeviceSize, typeFilter: u32, memoryProperties: c.VkMemoryPropertyFlags) !VulkanMemory {
        const memoryIndex = try base.findMemoryType(context, typeFilter, memoryProperties);

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
};
