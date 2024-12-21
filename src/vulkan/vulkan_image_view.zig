const std = @import("std");
const vulkan = @import("../vulkan.zig");
const util = @import("../util.zig");
const c = @cImport(@cInclude("vulkan/vulkan.h"));

const Allocator = std.mem.Allocator;
const VulkanContext = vulkan.VulkanContext;
const VulkanCommandPool = vulkan.VulkanCommandPool;
const VulkanCommandBuffer = vulkan.VulkanCommandBuffer;
const VulkanBuffer = vulkan.VulkanBuffer;
const VulkanMemory = vulkan.VulkanMemory;
const VulkanImage = vulkan.VulkanImage;
const ImageData = util.ImageData;
const vkCheck = vulkan.vkCheck;

pub const VulkanImageView = struct {
    handle: c.VkImageView,

    pub fn new(context: *const VulkanContext, image: *const VulkanImage, imageData: *const ImageData) !VulkanImageView {
        var view: c.VkImageView = undefined;
        {
            const aspect: u32 = switch (imageData.format) {
                .RGBA8, .RGBA32 => c.VK_IMAGE_ASPECT_COLOR_BIT,
                .Depth32 => c.VK_IMAGE_ASPECT_DEPTH_BIT,
            };

            var createInfo = c.VkImageViewCreateInfo{};
            createInfo.sType = c.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
            createInfo.image = image.handle;
            createInfo.viewType = c.VK_IMAGE_VIEW_TYPE_2D;
            createInfo.format = @intFromEnum(imageData.format);
            createInfo.subresourceRange.aspectMask = aspect;
            createInfo.subresourceRange.levelCount = 1;
            createInfo.subresourceRange.layerCount = 1;
            switch (c.vkCreateImageView(context.device.handle, &createInfo, null, &view)) {
                c.VK_SUCCESS => {},
                else => {
                    std.debug.print("[Vulkan] Could not create Image View\n", .{});
                    return error.CreateImageView;
                },
            }
        }

        return .{
            .handle = view,
        };
    }

    pub fn destroy(self: *VulkanImageView, context: *const VulkanContext) void {
        c.vkDestroyImageView(context.device.handle, self.handle, null);
    }
};
