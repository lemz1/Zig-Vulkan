const std = @import("std");
const vulkan = @import("../vulkan.zig");
const c = @cImport(@cInclude("vulkan/vulkan.h"));

const Allocator = std.mem.Allocator;
const VulkanContext = vulkan.VulkanContext;
const VulkanDescriptorPool = vulkan.VulkanDescriptorPool;
const VulkanDescriptorSetLayout = vulkan.VulkanDescriptorSetLayout;
const VulkanSampler = vulkan.VulkanSampler;
const VulkanImageView = vulkan.VulkanImageView;
const VulkanBuffer = vulkan.VulkanBuffer;
const vkCheck = vulkan.vkCheck;

pub const VulkanDescriptorSet = struct {
    handle: c.VkDescriptorSet,

    pub fn new(
        context: *const VulkanContext,
        descriptorPool: *const VulkanDescriptorPool,
        descriptorSetLayout: *const VulkanDescriptorSetLayout,
    ) !VulkanDescriptorSet {
        var descriptorSet: c.VkDescriptorSet = undefined;
        {
            var allocateInfo = c.VkDescriptorSetAllocateInfo{};
            allocateInfo.sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO;
            allocateInfo.descriptorPool = descriptorPool.handle;
            allocateInfo.descriptorSetCount = 1;
            allocateInfo.pSetLayouts = &descriptorSetLayout.handle;
            switch (c.vkAllocateDescriptorSets(context.device.handle, &allocateInfo, &descriptorSet)) {
                c.VK_SUCCESS => {},
                else => {
                    std.debug.print("[Vulkan] Could not Allocate Descriptor Set\n", .{});
                    return error.AllocateDescriptorSet;
                },
            }
        }

        return .{
            .handle = descriptorSet,
        };
    }

    pub fn updateSampler(
        self: *const VulkanDescriptorSet,
        context: *const VulkanContext,
        sampler: *const VulkanSampler,
        view: *const VulkanImageView,
        binding: u32,
    ) void {
        var imageInfo = c.VkDescriptorImageInfo{};
        imageInfo.sampler = sampler.handle;
        imageInfo.imageView = view.handle;
        imageInfo.imageLayout = c.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;

        var descriptorWrite = c.VkWriteDescriptorSet{};
        descriptorWrite.sType = c.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        descriptorWrite.dstSet = self.handle;
        descriptorWrite.dstBinding = binding;
        descriptorWrite.descriptorCount = 1;
        descriptorWrite.descriptorType = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
        descriptorWrite.pImageInfo = &imageInfo;

        c.vkUpdateDescriptorSets(context.device.handle, 1, &descriptorWrite, 0, null);
    }

    pub fn updateBuffer(
        self: *const VulkanDescriptorSet,
        context: *const VulkanContext,
        buffer: *const VulkanBuffer,
        size: c.VkDeviceSize,
        binding: u32,
    ) void {
        var bufferInfo = c.VkDescriptorBufferInfo{};
        bufferInfo.buffer = buffer.handle;
        bufferInfo.offset = 0;
        bufferInfo.range = size;

        var descriptorWrite = c.VkWriteDescriptorSet{};
        descriptorWrite.sType = c.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        descriptorWrite.dstSet = self.handle;
        descriptorWrite.dstBinding = binding;
        descriptorWrite.descriptorCount = 1;
        descriptorWrite.descriptorType = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
        descriptorWrite.pBufferInfo = &bufferInfo;

        c.vkUpdateDescriptorSets(context.device.handle, 1, &descriptorWrite, 0, null);
    }
};
