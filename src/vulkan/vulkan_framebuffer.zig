const std = @import("std");
const base = @import("base.zig");
const vulkan = @import("../vulkan.zig");
const c = @cImport(@cInclude("vulkan/vulkan.h"));

const Allocator = std.mem.Allocator;
const VulkanContext = vulkan.VulkanContext;
const VulkanRenderPass = vulkan.VulkanRenderPass;
const vkCheck = base.vkCheck;

pub const VulkanFramebuffer = struct {
    handle: c.VkFramebuffer,
    width: u32,
    height: u32,

    pub fn new(
        context: *const VulkanContext,
        renderPass: *const VulkanRenderPass,
        attachmentCount: u32,
        attachments: [*c]const c.VkImageView,
        width: u32,
        height: u32,
    ) !VulkanFramebuffer {
        var createInfo = c.VkFramebufferCreateInfo{};
        createInfo.sType = c.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO;
        createInfo.renderPass = renderPass.handle;
        createInfo.attachmentCount = attachmentCount;
        createInfo.pAttachments = attachments;
        createInfo.width = width;
        createInfo.height = height;
        createInfo.layers = 1;

        var framebuffer: c.VkFramebuffer = undefined;
        switch (c.vkCreateFramebuffer(context.device.handle, &createInfo, null, &framebuffer)) {
            c.VK_SUCCESS => {
                return .{
                    .handle = framebuffer,
                    .width = width,
                    .height = height,
                };
            },
            else => {
                std.debug.print("[Vulkan] Could not create Framebuffer\n", .{});
                return error.CreateFramebuffer;
            },
        }
    }

    pub fn destroy(self: *VulkanFramebuffer, context: *const VulkanContext) void {
        c.vkDestroyFramebuffer(context.device.handle, self.handle, null);
    }
};
