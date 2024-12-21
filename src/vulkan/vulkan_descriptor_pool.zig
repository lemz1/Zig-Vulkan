const std = @import("std");
const vulkan = @import("../vulkan.zig");
const c = @cImport(@cInclude("vulkan/vulkan.h"));

const Allocator = std.mem.Allocator;
const VulkanContext = vulkan.VulkanContext;
const vkCheck = vulkan.vkCheck;

pub const VulkanDescriptorPool = struct {
    handle: c.VkDescriptorPool,

    pub fn new(context: *const VulkanContext, descriptorPoolSizes: []const c.VkDescriptorPoolSize) !VulkanDescriptorPool {
        var descriptorPool: c.VkDescriptorPool = undefined;
        {
            var maxSets: u32 = 0;
            for (descriptorPoolSizes) |*size| {
                maxSets += size.descriptorCount;
            }

            var createInfo = c.VkDescriptorPoolCreateInfo{};
            createInfo.sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO;
            createInfo.maxSets = maxSets;
            createInfo.poolSizeCount = @intCast(descriptorPoolSizes.len);
            createInfo.pPoolSizes = descriptorPoolSizes.ptr;

            switch (c.vkCreateDescriptorPool(context.device.handle, &createInfo, null, &descriptorPool)) {
                c.VK_SUCCESS => {},
                else => {
                    std.debug.print("[Vulkan] Could not Create Descriptor Pool\n", .{});
                    return error.CreateDescriptorPool;
                },
            }
        }

        return .{
            .handle = descriptorPool,
        };
    }

    pub fn destroy(self: *VulkanDescriptorPool, context: *const VulkanContext) void {
        c.vkDestroyDescriptorPool(context.device.handle, self.handle, null);
    }
};
