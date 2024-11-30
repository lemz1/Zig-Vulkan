const std = @import("std");
const base = @import("base.zig");
const vulkan = @import("../vulkan.zig");
const util = @import("../util.zig");
const c = @cImport(@cInclude("vulkan/vulkan.h"));

const VulkanDevice = vulkan.VulkanDevice;
const vkCheck = base.vkCheck;
const memcpy = @cImport(@cInclude("memory.h")).memcpy;

const VulkanSamplerError = error{
    CreateSampler,
};

pub const VulkanSampler = struct {
    handle: c.VkSampler,

    pub fn new(device: *const VulkanDevice) !VulkanSampler {
        var sampler: c.VkSampler = undefined;
        {
            var createInfo = c.VkSamplerCreateInfo{};
            createInfo.sType = c.VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO;
            createInfo.magFilter = c.VK_FILTER_LINEAR;
            createInfo.minFilter = c.VK_FILTER_LINEAR;
            createInfo.mipmapMode = c.VK_SAMPLER_MIPMAP_MODE_LINEAR;
            createInfo.addressModeU = c.VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
            createInfo.addressModeV = createInfo.addressModeU;
            createInfo.addressModeW = createInfo.addressModeU;
            createInfo.mipLodBias = 0.0;
            createInfo.maxAnisotropy = 1.0;
            createInfo.minLod = 0.0;
            createInfo.maxLod = 1.0;
            switch (c.vkCreateSampler(device.handle, &createInfo, null, &sampler)) {
                c.VK_SUCCESS => {},
                else => {
                    std.debug.print("[Vulkan] Could not create Samper\n", .{});
                    return VulkanSamplerError.CreateSampler;
                },
            }
        }

        return .{
            .handle = sampler,
        };
    }

    pub fn destroy(self: *VulkanSampler, device: *const VulkanDevice) void {
        c.vkDestroySampler(device.handle, self.handle, null);
    }
};
