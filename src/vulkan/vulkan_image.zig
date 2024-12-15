const std = @import("std");
const base = @import("base.zig");
const vulkan = @import("../vulkan.zig");
const util = @import("../util.zig");
const c = @cImport(@cInclude("vulkan/vulkan.h"));

const Allocator = std.mem.Allocator;
const VulkanContext = vulkan.VulkanContext;
const VulkanCommandPool = vulkan.VulkanCommandPool;
const VulkanCommandBuffer = vulkan.VulkanCommandBuffer;
const VulkanBuffer = vulkan.VulkanBuffer;
const ImageData = util.ImageData;
const vkCheck = base.vkCheck;
const memcpy = @cImport(@cInclude("memory.h")).memcpy;

pub const VulkanImage = struct {
    handle: c.VkImage,
    view: c.VkImageView,
    memory: c.VkDeviceMemory,

    uploadCmdPool: VulkanCommandPool,
    uploadCmdBuffer: VulkanCommandBuffer,

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

        var memory: c.VkDeviceMemory = undefined;
        {
            var memoryRequirements: c.VkMemoryRequirements = undefined;
            c.vkGetImageMemoryRequirements(context.device.handle, image, &memoryRequirements);

            var allocateInfo = c.VkMemoryAllocateInfo{};
            allocateInfo.sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
            allocateInfo.allocationSize = memoryRequirements.size;
            allocateInfo.memoryTypeIndex = try base.findMemoryType(context, memoryRequirements.memoryTypeBits, c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
            switch (c.vkAllocateMemory(context.device.handle, &allocateInfo, null, &memory)) {
                c.VK_SUCCESS => {},
                else => {
                    std.debug.print("[Vulkan] Could not allocate Memory\n", .{});
                    return error.AllocateMemory;
                },
            }
        }

        vkCheck(c.vkBindImageMemory(context.device.handle, image, memory, 0));

        var view: c.VkImageView = undefined;
        {
            const aspect: u32 = switch (imageData.format) {
                .RGBA8, .RGBA32 => c.VK_IMAGE_ASPECT_COLOR_BIT,
                .Depth32 => c.VK_IMAGE_ASPECT_DEPTH_BIT,
            };

            var createInfo = c.VkImageViewCreateInfo{};
            createInfo.sType = c.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
            createInfo.image = image;
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

        const uploadCmdPool = try VulkanCommandPool.new(context, context.device.graphicsQueue.familyIndex);
        const uploadCmdBuffer = try VulkanCommandBuffer.new(context, &uploadCmdPool);

        return .{
            .handle = image,
            .view = view,
            .memory = memory,

            .uploadCmdPool = uploadCmdPool,
            .uploadCmdBuffer = uploadCmdBuffer,
        };
    }

    pub fn destroy(self: *VulkanImage, context: *const VulkanContext) void {
        self.uploadCmdPool.destroy(context);

        c.vkDestroyImageView(context.device.handle, self.view, null);
        c.vkDestroyImage(context.device.handle, self.handle, null);
        c.vkFreeMemory(context.device.handle, self.memory, null);
    }

    pub fn uploadData(
        self: *const VulkanImage,
        context: *const VulkanContext,
        imageData: *const ImageData,
        finalLayout: c.VkImageLayout,
        _: c.VkAccessFlags,
    ) !void {
        const pixels = if (imageData.pixels) |v| v else return;

        const size: c.VkDeviceSize = imageData.size;

        var stagingBuffer = try VulkanBuffer.new(
            context,
            size,
            c.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
            c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        );
        defer stagingBuffer.destroy(context);

        var mapped: ?*anyopaque = undefined;
        vkCheck(c.vkMapMemory(context.device.handle, stagingBuffer.memory, 0, size, 0, &mapped));
        _ = memcpy(mapped, pixels, size);
        c.vkUnmapMemory(context.device.handle, stagingBuffer.memory);

        self.uploadCmdPool.reset(context);

        self.uploadCmdBuffer.begin();
        {
            var imageBarrier = c.VkImageMemoryBarrier{};
            imageBarrier.sType = c.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
            imageBarrier.oldLayout = c.VK_IMAGE_LAYOUT_UNDEFINED;
            imageBarrier.newLayout = c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
            imageBarrier.srcQueueFamilyIndex = c.VK_QUEUE_FAMILY_IGNORED;
            imageBarrier.dstQueueFamilyIndex = c.VK_QUEUE_FAMILY_IGNORED;
            imageBarrier.image = self.handle;
            imageBarrier.subresourceRange.aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT;
            imageBarrier.subresourceRange.levelCount = 1;
            imageBarrier.subresourceRange.layerCount = 1;
            imageBarrier.srcAccessMask = 0;
            imageBarrier.dstAccessMask = c.VK_ACCESS_TRANSFER_WRITE_BIT;
            c.vkCmdPipelineBarrier(
                self.uploadCmdBuffer.handle,
                c.VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
                c.VK_PIPELINE_STAGE_TRANSFER_BIT,
                0,
                0,
                0,
                0,
                0,
                1,
                &imageBarrier,
            );
        }
        {
            var region = c.VkBufferImageCopy{};
            region.imageSubresource.aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT;
            region.imageSubresource.layerCount = 1;
            region.imageExtent = .{
                .width = imageData.width,
                .height = imageData.height,
                .depth = 1,
            };

            self.uploadCmdBuffer.copyBufferToImage(&stagingBuffer, self, region);
        }
        {
            var imageBarrier = c.VkImageMemoryBarrier{};
            imageBarrier.sType = c.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
            imageBarrier.oldLayout = c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
            imageBarrier.newLayout = finalLayout;
            imageBarrier.srcQueueFamilyIndex = c.VK_QUEUE_FAMILY_IGNORED;
            imageBarrier.dstQueueFamilyIndex = c.VK_QUEUE_FAMILY_IGNORED;
            imageBarrier.image = self.handle;
            imageBarrier.subresourceRange.aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT;
            imageBarrier.subresourceRange.levelCount = 1;
            imageBarrier.subresourceRange.layerCount = 1;
            imageBarrier.srcAccessMask = c.VK_ACCESS_TRANSFER_WRITE_BIT;
            imageBarrier.dstAccessMask = c.VK_ACCESS_NONE;
            c.vkCmdPipelineBarrier(
                self.uploadCmdBuffer.handle,
                c.VK_PIPELINE_STAGE_TRANSFER_BIT,
                c.VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT,
                0,
                0,
                0,
                0,
                0,
                1,
                &imageBarrier,
            );
        }
        self.uploadCmdBuffer.end();

        var submitInfo = c.VkSubmitInfo{};
        submitInfo.sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO;
        submitInfo.commandBufferCount = 1;
        submitInfo.pCommandBuffers = &self.uploadCmdBuffer.handle;
        context.device.graphicsQueue.submit(&submitInfo, null);
        context.device.graphicsQueue.wait();
    }
};
