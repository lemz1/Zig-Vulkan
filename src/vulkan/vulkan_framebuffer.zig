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
const VulkanSurface = vulkan.VulkanSurface;
const VulkanRenderPass = vulkan.VulkanRenderPass;

const Window = core.Window;

const VulkanFramebufferError = error{
    CreateFramebuffer,
};

pub const VulkanFramebuffer = struct {
    handle: c.VkFramebuffer,
    width: u32,
    height: u32,

    pub fn new(device: *const VulkanDevice, renderPass: *const VulkanRenderPass, attachmentCount: u32, attachments: [*c]const c.VkImageView, width: u32, height: u32) !VulkanFramebuffer {
        var createInfo = c.VkFramebufferCreateInfo{};
        createInfo.sType = c.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO;
        createInfo.renderPass = renderPass.handle;
        createInfo.attachmentCount = attachmentCount;
        createInfo.pAttachments = attachments;
        createInfo.width = width;
        createInfo.height = height;
        createInfo.layers = 1;

        var framebuffer: c.VkFramebuffer = undefined;
        switch (c.vkCreateFramebuffer(device.handle, &createInfo, null, &framebuffer)) {
            c.VK_SUCCESS => {
                return .{
                    .handle = framebuffer,
                    .width = width,
                    .height = height,
                };
            },
            else => {
                std.debug.print("[Vulkan] could not create framebuffer\n", .{});
                return VulkanFramebufferError.CreateFramebuffer;
            },
        }
    }

    pub fn destroy(self: *VulkanFramebuffer, device: *const VulkanDevice) void {
        c.vkDestroyFramebuffer(device.handle, self.handle, null);
    }
};
