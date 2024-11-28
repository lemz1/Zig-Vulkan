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

const Window = core.Window;

const VulkanBufferError = error{
    CreateBuffer,
    CreateMemory,
    FindMemoryType,
};

pub const VulkanBuffer = struct {
    handle: c.VkBuffer,
    memory: c.VkDeviceMemory,

    pub fn new(device: *const VulkanDevice, size: u64, usage: c.VkBufferUsageFlags, memoryProperties: c.VkMemoryPropertyFlags) !VulkanBuffer {
        var createInfo = c.VkBufferCreateInfo{};
        createInfo.sType = c.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
        createInfo.size = size;
        createInfo.usage = usage;

        var buffer: c.VkBuffer = undefined;
        switch (c.vkCreateBuffer(device.handle, &createInfo, null, &buffer)) {
            c.VK_SUCCESS => {},
            else => {
                std.debug.print("[Vulkan] could not create command buffer\n", .{});
                return VulkanBufferError.CreateBuffer;
            },
        }

        var memoryRequirements: c.VkMemoryRequirements = undefined;
        c.vkGetBufferMemoryRequirements(device.handle, buffer, &memoryRequirements);

        const memoryIndex = try findMemoryType(device, memoryRequirements.memoryTypeBits, memoryProperties);

        var allocateInfo = c.VkMemoryAllocateInfo{};
        allocateInfo.sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
        allocateInfo.allocationSize = memoryRequirements.size;
        allocateInfo.memoryTypeIndex = memoryIndex;

        var memory: c.VkDeviceMemory = undefined;
        switch (c.vkAllocateMemory(device.handle, &allocateInfo, null, &memory)) {
            c.VK_SUCCESS => {},
            else => {
                std.debug.print("[Vulkan] could not create command buffer\n", .{});
                return VulkanBufferError.CreateBuffer;
            },
        }

        vkCheck(c.vkBindBufferMemory(device.handle, buffer, memory, 0));

        return .{
            .handle = buffer,
            .memory = memory,
        };
    }

    pub fn destroy(self: *VulkanBuffer, device: *const VulkanDevice) void {
        c.vkFreeMemory(device.handle, self.memory, null);
        c.vkDestroyBuffer(device.handle, self.handle, null);
    }

    fn findMemoryType(device: *const VulkanDevice, typeFilter: u32, memoryProperties: c.VkMemoryPropertyFlags) !u32 {
        var deviceMemoryProperties: c.VkPhysicalDeviceMemoryProperties = undefined;
        c.vkGetPhysicalDeviceMemoryProperties(device.physicalDevice, &deviceMemoryProperties);

        for (0..deviceMemoryProperties.memoryTypeCount) |i| {
            if ((typeFilter & (@as(u32, 1) << @intCast(i))) != 0) {
                if ((deviceMemoryProperties.memoryTypes[i].propertyFlags & memoryProperties) == memoryProperties) {
                    return @intCast(i);
                }
            }
        }

        return VulkanBufferError.FindMemoryType;
    }
};
