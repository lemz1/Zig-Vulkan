const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

const util = @import("util.zig");

const c = @cImport(@cInclude("vulkan/vulkan.h"));

const vkCheck = util.vkCheck;

const memcpy = @cImport(@cInclude("memory.h")).memcpy;

const core = @import("../core.zig");
const vulkan = @import("../vulkan.zig");

const VulkanInstance = vulkan.VulkanInstance;
const VulkanDevice = vulkan.VulkanDevice;
const VulkanSurface = vulkan.VulkanSurface;
const VulkanRenderPass = vulkan.VulkanRenderPass;
const VulkanBuffer = vulkan.VulkanBuffer;
const VulkanCommandPool = vulkan.VulkanCommandPool;
const VulkanCommandBuffer = vulkan.VulkanCommandBuffer;

const Window = core.Window;

const VulkanImageError = error{
    CreateImage,
    AllocateMemory,
    CreateImageView,
};

pub const VulkanImage = struct {
    handle: c.VkImage,
    view: c.VkImageView,
    memory: c.VkDeviceMemory,

    uploadCmdPool: VulkanCommandPool,
    uploadCmdBuffer: VulkanCommandBuffer,

    pub fn new(device: *const VulkanDevice, width: u32, height: u32, format: c.VkFormat, usage: c.VkImageUsageFlags) !VulkanImage {
        var image: c.VkImage = undefined;
        {
            var createInfo = c.VkImageCreateInfo{};
            createInfo.sType = c.VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO;
            createInfo.imageType = c.VK_IMAGE_TYPE_2D;
            createInfo.extent.width = width;
            createInfo.extent.height = height;
            createInfo.extent.depth = 1;
            createInfo.mipLevels = 1;
            createInfo.arrayLayers = 1;
            createInfo.format = format;
            createInfo.tiling = c.VK_IMAGE_TILING_OPTIMAL;
            createInfo.initialLayout = c.VK_IMAGE_LAYOUT_UNDEFINED;
            createInfo.usage = usage;
            createInfo.samples = c.VK_SAMPLE_COUNT_1_BIT;
            createInfo.sharingMode = c.VK_SHARING_MODE_EXCLUSIVE;

            switch (c.vkCreateImage(device.handle, &createInfo, null, &image)) {
                c.VK_SUCCESS => {},
                else => {
                    std.debug.print("[Vulkan] Could not create Image\n", .{});
                    return VulkanImageError.CreateImage;
                },
            }
        }

        var memory: c.VkDeviceMemory = undefined;
        {
            var memoryRequirements: c.VkMemoryRequirements = undefined;
            c.vkGetImageMemoryRequirements(device.handle, image, &memoryRequirements);

            var allocateInfo = c.VkMemoryAllocateInfo{};
            allocateInfo.sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
            allocateInfo.allocationSize = memoryRequirements.size;
            allocateInfo.memoryTypeIndex = try util.findMemoryType(device, memoryRequirements.memoryTypeBits, c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
            switch (c.vkAllocateMemory(device.handle, &allocateInfo, null, &memory)) {
                c.VK_SUCCESS => {},
                else => {
                    std.debug.print("[Vulkan] Could not allocate Memory\n", .{});
                    return VulkanImageError.AllocateMemory;
                },
            }
        }

        vkCheck(c.vkBindImageMemory(device.handle, image, memory, 0));

        var view: c.VkImageView = undefined;
        {
            var createInfo = c.VkImageViewCreateInfo{};
            createInfo.sType = c.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
            createInfo.image = image;
            createInfo.viewType = c.VK_IMAGE_VIEW_TYPE_2D;
            createInfo.format = format;
            createInfo.subresourceRange.aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT;
            createInfo.subresourceRange.levelCount = 1;
            createInfo.subresourceRange.layerCount = 1;
            switch (c.vkCreateImageView(device.handle, &createInfo, null, &view)) {
                c.VK_SUCCESS => {},
                else => {
                    std.debug.print("[Vulkan] Could not create Image View\n", .{});
                    return VulkanImageError.CreateImageView;
                },
            }
        }

        const uploadCmdPool = try VulkanCommandPool.new(device, device.graphicsQueue.familyIndex);
        const uploadCmdBuffer = try VulkanCommandBuffer.new(device, &uploadCmdPool);

        return .{
            .handle = image,
            .view = view,
            .memory = memory,

            .uploadCmdPool = uploadCmdPool,
            .uploadCmdBuffer = uploadCmdBuffer,
        };
    }

    pub fn destroy(self: *VulkanImage, device: *const VulkanDevice) void {
        self.uploadCmdBuffer.destroy(device, &self.uploadCmdPool);
        self.uploadCmdPool.destroy(device);

        c.vkDestroyImageView(device.handle, self.view, null);
        c.vkDestroyImage(device.handle, self.handle, null);
        c.vkFreeMemory(device.handle, self.memory, null);
    }

    pub fn uploadData(
        self: *const VulkanImage,
        device: *const VulkanDevice,
        width: u32,
        height: u32,
        finalLayout: c.VkImageLayout,
        _: c.VkAccessFlags,
        data: anytype,
    ) !void {
        const typeInfo = @typeInfo(@TypeOf(data));

        comptime {
            if (typeInfo != .pointer or typeInfo.pointer.size != .Slice) {
                @compileError("Data is not a Slice\n");
            }
        }

        const size: c.VkDeviceSize = data.len * @sizeOf(typeInfo.pointer.child);

        var stagingBuffer = try VulkanBuffer.new(
            device,
            size,
            c.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
            c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        );
        defer stagingBuffer.destroy(device);

        var mapped: ?*anyopaque = undefined;
        vkCheck(c.vkMapMemory(device.handle, stagingBuffer.memory, 0, size, 0, &mapped));
        _ = memcpy(mapped, data.ptr, size);
        c.vkUnmapMemory(device.handle, stagingBuffer.memory);

        self.uploadCmdPool.reset(device);

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
                .width = width,
                .height = height,
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
        device.graphicsQueue.submit(&submitInfo, null);
        device.graphicsQueue.wait();
    }
};
