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
const ImageData = util.ImageData;
const vkCheck = vulkan.vkCheck;

pub const VulkanImage = struct {
    handle: c.VkImage,

    requirements: c.VkMemoryRequirements,

    pub fn new(context: *const VulkanContext, imageData: *const ImageData, usage: c.VkImageUsageFlags) !VulkanImage {
        var image: c.VkImage = undefined;
        {
            var createInfo = c.VkImageCreateInfo{};
            createInfo.sType = c.VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO;
            createInfo.imageType = c.VK_IMAGE_TYPE_2D;
            createInfo.extent.width = imageData.width;
            createInfo.extent.height = imageData.height;
            createInfo.extent.depth = 1;
            createInfo.mipLevels = 1;
            createInfo.arrayLayers = 1;
            createInfo.format = @intFromEnum(imageData.format);
            createInfo.tiling = c.VK_IMAGE_TILING_OPTIMAL;
            createInfo.initialLayout = c.VK_IMAGE_LAYOUT_UNDEFINED;
            createInfo.usage = usage;
            createInfo.samples = c.VK_SAMPLE_COUNT_1_BIT;
            createInfo.sharingMode = c.VK_SHARING_MODE_EXCLUSIVE;

            switch (c.vkCreateImage(context.device.handle, &createInfo, null, &image)) {
                c.VK_SUCCESS => {},
                else => {
                    std.debug.print("[Vulkan] Could not create Image\n", .{});
                    return error.CreateImage;
                },
            }
        }

        var memoryRequirements: c.VkMemoryRequirements = undefined;
        c.vkGetImageMemoryRequirements(context.device.handle, image, &memoryRequirements);

        return .{
            .handle = image,

            .requirements = memoryRequirements,
        };
    }

    pub fn destroy(self: *VulkanImage, context: *const VulkanContext) void {
        c.vkDestroyImage(context.device.handle, self.handle, null);
    }
};
