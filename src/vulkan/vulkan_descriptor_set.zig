const std = @import("std");
const base = @import("base.zig");
const vulkan = @import("../vulkan.zig");
const c = @cImport(@cInclude("vulkan/vulkan.h"));

const Allocator = std.mem.Allocator;
const VulkanContext = vulkan.VulkanContext;
const VulkanDescriptorPool = vulkan.VulkanDescriptorPool;
const VulkanDescriptorSetLayout = vulkan.VulkanDescriptorSetLayout;
const VulkanSampler = vulkan.VulkanSampler;
const VulkanImage = vulkan.VulkanImage;
const VulkanBuffer = vulkan.VulkanBuffer;
const vkCheck = base.vkCheck;

const VulkanDescriptorSetError = error{
    AllocateDescriptorSet,
};

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
                    return VulkanDescriptorSetError.AllocateDescriptorSet;
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
        image: *const VulkanImage,
        binding: u32,
    ) void {
        var imageInfo = c.VkDescriptorImageInfo{};
        imageInfo.sampler = sampler.handle;
        imageInfo.imageView = image.view;
        imageInfo.imageLayout = c.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;

        var descriptorWrites = [1]c.VkWriteDescriptorSet{undefined};
        descriptorWrites[0].sType = c.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        descriptorWrites[0].dstSet = self.handle;
        descriptorWrites[0].dstBinding = binding;
        descriptorWrites[0].descriptorCount = 1;
        descriptorWrites[0].descriptorType = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
        descriptorWrites[0].pImageInfo = &imageInfo;

        c.vkUpdateDescriptorSets(context.device.handle, @intCast(descriptorWrites.len), &descriptorWrites, 0, null);
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

        var descriptorWrites = [1]c.VkWriteDescriptorSet{undefined};
        descriptorWrites[0].sType = c.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        descriptorWrites[0].dstSet = self.handle;
        descriptorWrites[0].dstBinding = binding;
        descriptorWrites[0].descriptorCount = 1;
        descriptorWrites[0].descriptorType = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
        descriptorWrites[0].pBufferInfo = &bufferInfo;

        c.vkUpdateDescriptorSets(context.device.handle, @intCast(descriptorWrites.len), &descriptorWrites, 0, null);
    }
};
