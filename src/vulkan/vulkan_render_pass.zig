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

const VulkanRenderPassError = error{
    CreateRenderPass,
};

pub const VulkanRenderPass = struct {
    handle: c.VkRenderPass,

    pub fn new(device: *const VulkanDevice, format: c.VkFormat) !VulkanRenderPass {
        var attachmentDescription = c.VkAttachmentDescription{};
        attachmentDescription.format = format;
        attachmentDescription.samples = c.VK_SAMPLE_COUNT_1_BIT;
        attachmentDescription.loadOp = c.VK_ATTACHMENT_LOAD_OP_CLEAR;
        attachmentDescription.storeOp = c.VK_ATTACHMENT_STORE_OP_STORE;
        attachmentDescription.initialLayout = c.VK_IMAGE_LAYOUT_UNDEFINED;
        attachmentDescription.finalLayout = c.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;

        var attachmentReference = c.VkAttachmentReference{};
        attachmentReference.attachment = 0;
        attachmentReference.layout = c.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

        var subpass = c.VkSubpassDescription{};
        subpass.pipelineBindPoint = c.VK_PIPELINE_BIND_POINT_GRAPHICS;
        subpass.colorAttachmentCount = 1;
        subpass.pColorAttachments = &attachmentReference;

        var createInfo = c.VkRenderPassCreateInfo{};
        createInfo.sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO;
        createInfo.attachmentCount = 1;
        createInfo.pAttachments = &attachmentDescription;
        createInfo.subpassCount = 1;
        createInfo.pSubpasses = &subpass;

        var renderPass: c.VkRenderPass = undefined;
        switch (c.vkCreateRenderPass(device.handle, &createInfo, null, &renderPass)) {
            c.VK_SUCCESS => {
                return .{
                    .handle = renderPass,
                };
            },
            else => {
                std.debug.print("[Vulkan] could not create render pass\n", .{});
                return VulkanRenderPassError.CreateRenderPass;
            },
        }
    }

    pub fn destroy(self: *VulkanRenderPass, device: *const VulkanDevice) void {
        c.vkDestroyRenderPass(device.handle, self.handle, null);
    }
};
