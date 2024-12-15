const std = @import("std");
const base = @import("base.zig");
const vulkan = @import("../vulkan.zig");
const c = @cImport(@cInclude("vulkan/vulkan.h"));

const Allocator = std.mem.Allocator;
const VulkanContext = vulkan.VulkanContext;
const vkCheck = base.vkCheck;

pub const VulkanRenderPass = struct {
    handle: c.VkRenderPass,

    pub fn new(context: *const VulkanContext, format: c.VkFormat) !VulkanRenderPass {
        var attachmentDescriptions = [2]c.VkAttachmentDescription{ undefined, undefined };
        attachmentDescriptions[0] = c.VkAttachmentDescription{};
        attachmentDescriptions[0].format = format;
        attachmentDescriptions[0].samples = c.VK_SAMPLE_COUNT_1_BIT;
        attachmentDescriptions[0].loadOp = c.VK_ATTACHMENT_LOAD_OP_CLEAR;
        attachmentDescriptions[0].storeOp = c.VK_ATTACHMENT_STORE_OP_STORE;
        attachmentDescriptions[0].initialLayout = c.VK_IMAGE_LAYOUT_UNDEFINED;
        attachmentDescriptions[0].finalLayout = c.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;

        attachmentDescriptions[1] = c.VkAttachmentDescription{};
        attachmentDescriptions[1].format = c.VK_FORMAT_D32_SFLOAT;
        attachmentDescriptions[1].samples = c.VK_SAMPLE_COUNT_1_BIT;
        attachmentDescriptions[1].loadOp = c.VK_ATTACHMENT_LOAD_OP_CLEAR;
        attachmentDescriptions[1].storeOp = c.VK_ATTACHMENT_STORE_OP_STORE;
        attachmentDescriptions[1].initialLayout = c.VK_IMAGE_LAYOUT_UNDEFINED;
        attachmentDescriptions[1].finalLayout = c.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL;

        var attachmentReference = c.VkAttachmentReference{};
        attachmentReference.attachment = 0;
        attachmentReference.layout = c.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

        var depthStencilReference = c.VkAttachmentReference{};
        depthStencilReference.attachment = 1;
        depthStencilReference.layout = c.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL;

        var subpass = c.VkSubpassDescription{};
        subpass.pipelineBindPoint = c.VK_PIPELINE_BIND_POINT_GRAPHICS;
        subpass.colorAttachmentCount = 1;
        subpass.pColorAttachments = &attachmentReference;
        subpass.pDepthStencilAttachment = &depthStencilReference;

        var createInfo = c.VkRenderPassCreateInfo{};
        createInfo.sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO;
        createInfo.attachmentCount = @intCast(attachmentDescriptions.len);
        createInfo.pAttachments = &attachmentDescriptions;
        createInfo.subpassCount = 1;
        createInfo.pSubpasses = &subpass;

        var renderPass: c.VkRenderPass = undefined;
        switch (c.vkCreateRenderPass(context.device.handle, &createInfo, null, &renderPass)) {
            c.VK_SUCCESS => {
                return .{
                    .handle = renderPass,
                };
            },
            else => {
                std.debug.print("[Vulkan] Could not create Render Pass\n", .{});
                return error.CreateRenderPass;
            },
        }
    }

    pub fn destroy(self: *VulkanRenderPass, context: *const VulkanContext) void {
        c.vkDestroyRenderPass(context.device.handle, self.handle, null);
    }
};
