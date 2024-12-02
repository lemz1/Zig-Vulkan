const std = @import("std");
const base = @import("base.zig");
const vulkan = @import("../vulkan.zig");
const c = @cImport(@cInclude("vulkan/vulkan.h"));

const VulkanDevice = vulkan.VulkanDevice;
const VulkanDescriptorPool = vulkan.VulkanDescriptorPool;
const VulkanSampler = vulkan.VulkanSampler;
const VulkanImage = vulkan.VulkanImage;
const vkCheck = base.vkCheck;

const VulkanDescriptorSetError = error{
    CreateDescriptorPool,
    CreateDescriptorSetLayout,
    AllocateDescriptorSets,
};

pub const VulkanDescriptorSet = struct {
    handle: c.VkDescriptorSet,
    layout: c.VkDescriptorSetLayout,

    pub fn new(device: *const VulkanDevice, descriptorPool: *const VulkanDescriptorPool) !VulkanDescriptorSet {
        var desciptorSetLayout: c.VkDescriptorSetLayout = undefined;
        {
            var bindings = [1]c.VkDescriptorSetLayoutBinding{undefined};
            bindings[0].binding = 0;
            bindings[0].descriptorCount = 1;
            bindings[0].descriptorType = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
            bindings[0].stageFlags = c.VK_SHADER_STAGE_FRAGMENT_BIT;
            bindings[0].pImmutableSamplers = null;

            var createInfo = c.VkDescriptorSetLayoutCreateInfo{};
            createInfo.sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO;
            createInfo.bindingCount = @intCast(bindings.len);
            createInfo.pBindings = &bindings;

            switch (c.vkCreateDescriptorSetLayout(device.handle, &createInfo, null, &desciptorSetLayout)) {
                c.VK_SUCCESS => {},
                else => {
                    std.debug.print("[Vulkan] Could not Create Descriptor Set Layout\n", .{});
                    return VulkanDescriptorSetError.CreateDescriptorSetLayout;
                },
            }
        }

        var descriptorSet: c.VkDescriptorSet = undefined;
        {
            var allocateInfo = c.VkDescriptorSetAllocateInfo{};
            allocateInfo.sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO;
            allocateInfo.descriptorPool = descriptorPool.handle;
            allocateInfo.descriptorSetCount = 1;
            allocateInfo.pSetLayouts = &desciptorSetLayout;
            switch (c.vkAllocateDescriptorSets(device.handle, &allocateInfo, &descriptorSet)) {
                c.VK_SUCCESS => {},
                else => {
                    std.debug.print("[Vulkan] Could not Allocate Descriptor Set\n", .{});
                    return VulkanDescriptorSetError.AllocateDescriptorSets;
                },
            }
        }

        return .{
            .handle = descriptorSet,
            .layout = desciptorSetLayout,
        };
    }

    pub fn destroy(self: *VulkanDescriptorSet, device: *const VulkanDevice) void {
        c.vkDestroyDescriptorSetLayout(device.handle, self.layout, null);
    }

    pub fn updateSampler(
        self: *const VulkanDescriptorSet,
        device: *const VulkanDevice,
        sampler: *const VulkanSampler,
        image: *const VulkanImage,
        binding: u32,
        descriptorCount: u32,
    ) void {
        var imageInfo = c.VkDescriptorImageInfo{};
        imageInfo.sampler = sampler.handle;
        imageInfo.imageView = image.view;
        imageInfo.imageLayout = c.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;

        var descriptorWrites = [1]c.VkWriteDescriptorSet{undefined};
        descriptorWrites[0].sType = c.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        descriptorWrites[0].dstSet = self.handle;
        descriptorWrites[0].dstBinding = binding;
        descriptorWrites[0].descriptorCount = descriptorCount;
        descriptorWrites[0].descriptorType = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
        descriptorWrites[0].pImageInfo = &imageInfo;

        c.vkUpdateDescriptorSets(device.handle, @intCast(descriptorWrites.len), &descriptorWrites, 0, null);
    }
};
