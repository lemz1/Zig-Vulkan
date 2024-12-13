const std = @import("std");
const base = @import("base.zig");
const vulkan = @import("../vulkan.zig");
const c = @cImport(@cInclude("vulkan/vulkan.h"));

const Allocator = std.mem.Allocator;
const VulkanDevice = vulkan.VulkanDevice;
const vkCheck = base.vkCheck;

const VulkanDescriptorPoolError = error{
    CreateDescriptorPool,
};

pub const VulkanDescriptorPool = struct {
    handle: c.VkDescriptorPool,

    pub fn new(device: *const VulkanDevice, descriptorPoolSizes: []const c.VkDescriptorPoolSize) !VulkanDescriptorPool {
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

            switch (c.vkCreateDescriptorPool(device.handle, &createInfo, null, &descriptorPool)) {
                c.VK_SUCCESS => {},
                else => {
                    std.debug.print("[Vulkan] Could not Create Descriptor Pool\n", .{});
                    return VulkanDescriptorPoolError.CreateDescriptorPool;
                },
            }
        }

        return .{
            .handle = descriptorPool,
        };
    }

    pub fn destroy(self: *VulkanDescriptorPool, device: *const VulkanDevice) void {
        c.vkDestroyDescriptorPool(device.handle, self.handle, null);
    }
};
