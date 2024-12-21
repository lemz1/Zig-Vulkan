const std = @import("std");
const vulkan = @import("../vulkan.zig");
const util = @import("../util.zig");
const c = @cImport(@cInclude("vulkan/vulkan.h"));

const VulkanContext = vulkan.VulkanContext;
const vkCheck = vulkan.vkCheck;
const memcpy = @cImport(@cInclude("memory.h")).memcpy;

pub const VulkanSamplerFilter = enum(c.VkFilter) {
    Linear = c.VK_FILTER_LINEAR,
    Nearest = c.VK_FILTER_NEAREST,
};

pub const VulkanSamplerAddressMode = enum(c.VkSamplerAddressMode) {
    Clamped = c.VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
    Repeated = c.VK_SAMPLER_ADDRESS_MODE_REPEAT,
    Mirrored = c.VK_SAMPLER_ADDRESS_MODE_MIRRORED_REPEAT,
};

pub const VulkanSampler = struct {
    handle: c.VkSampler,

    pub fn new(context: *const VulkanContext, filter: VulkanSamplerFilter, addressMode: VulkanSamplerAddressMode) !VulkanSampler {
        var sampler: c.VkSampler = undefined;
        {
            var createInfo = c.VkSamplerCreateInfo{};
            createInfo.sType = c.VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO;
            createInfo.magFilter = @intFromEnum(filter);
            createInfo.minFilter = @intFromEnum(filter);
            createInfo.mipmapMode = c.VK_SAMPLER_MIPMAP_MODE_LINEAR;
            createInfo.addressModeU = @intFromEnum(addressMode);
            createInfo.addressModeV = @intFromEnum(addressMode);
            createInfo.addressModeW = @intFromEnum(addressMode);
            createInfo.mipLodBias = 0.0;
            createInfo.maxAnisotropy = 1.0;
            createInfo.minLod = 0.0;
            createInfo.maxLod = 1.0;
            switch (c.vkCreateSampler(context.device.handle, &createInfo, null, &sampler)) {
                c.VK_SUCCESS => {},
                else => {
                    std.debug.print("[Vulkan] Could not create Samper\n", .{});
                    return error.CreateSampler;
                },
            }
        }

        return .{
            .handle = sampler,
        };
    }

    pub fn destroy(self: *VulkanSampler, context: *const VulkanContext) void {
        c.vkDestroySampler(context.device.handle, self.handle, null);
    }
};
