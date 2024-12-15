const std = @import("std");
const base = @import("base.zig");
const vulkan = @import("../vulkan.zig");
const c = @cImport(@cInclude("vulkan/vulkan.h"));

const Allocator = std.mem.Allocator;
const VulkanContext = vulkan.VulkanContext;
const VulkanDescriptorPool = vulkan.VulkanDescriptorPool;
const VulkanSampler = vulkan.VulkanSampler;
const VulkanImage = vulkan.VulkanImage;
const VulkanBuffer = vulkan.VulkanBuffer;
const vkCheck = base.vkCheck;

pub const VulkanDescriptorSetLayout = struct {
    handle: c.VkDescriptorSetLayout,

    pub fn new(
        context: *const VulkanContext,
        bindings: []const c.VkDescriptorSetLayoutBinding,
    ) !VulkanDescriptorSetLayout {
        var desciptorSetLayout: c.VkDescriptorSetLayout = undefined;
        {
            var createInfo = c.VkDescriptorSetLayoutCreateInfo{};
            createInfo.sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO;
            createInfo.bindingCount = @intCast(bindings.len);
            createInfo.pBindings = bindings.ptr;

            switch (c.vkCreateDescriptorSetLayout(context.device.handle, &createInfo, null, &desciptorSetLayout)) {
                c.VK_SUCCESS => {},
                else => {
                    std.debug.print("[Vulkan] Could not Create Descriptor Set Layout\n", .{});
                    return error.CreateDescriptorSetLayout;
                },
            }
        }
        return .{
            .handle = desciptorSetLayout,
        };
    }

    pub fn destroy(self: *VulkanDescriptorSetLayout, context: *const VulkanContext) void {
        c.vkDestroyDescriptorSetLayout(context.device.handle, self.handle, null);
    }
};
