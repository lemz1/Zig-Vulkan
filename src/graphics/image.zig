const vulkan = @import("../vulkan.zig");
const util = @import("../util.zig");
const gpu = @import("../gpu.zig");
const c = @cImport(@cInclude("vulkan/vulkan.h"));

const VulkanContext = vulkan.VulkanContext;
const VulkanImage = vulkan.VulkanImage;
const VulkanImageView = vulkan.VulkanImageView;
const VulkanBuffer = vulkan.VulkanBuffer;
const VulkanCommandPool = vulkan.VulkanCommandPool;
const VulkanCommandBuffer = vulkan.VulkanCommandBuffer;
const ImageData = util.ImageData;
const ImageFormat = util.ImageFormat;
const GPUAllocator = gpu.GPUAllocator;
const MemoryBlock = gpu.MemoryBlock;
const vkCheck = vulkan.vkCheck;
const memcpy = @cImport(@cInclude("memory.h")).memcpy;

pub const Image = struct {
    image: VulkanImage,
    view: VulkanImageView,
    memory: MemoryBlock,

    pub fn new(gpuAllocator: *GPUAllocator, data: *const ImageData, usage: c.VkImageUsageFlags) !Image {
        const image = try VulkanImage.new(
            gpuAllocator.context,
            data,
            usage,
        );

        const memory = try gpuAllocator.alloc(
            data.size,
            c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
            image.requirements,
        );
        memory.memory.bindImage(gpuAllocator.context, &image, memory.range.offset);

        const view = try VulkanImageView.new(
            gpuAllocator.context,
            &image,
            data,
        );

        return .{
            .image = image,
            .view = view,
            .memory = memory,
        };
    }

    pub fn destroy(self: *Image, gpuAllocator: *GPUAllocator) void {
        self.view.destroy(gpuAllocator.context);
        gpuAllocator.free(&self.memory);
        self.image.destroy(gpuAllocator.context);
    }

    pub fn uploadData(
        self: *const Image,
        gpuAllocator: *GPUAllocator,
        imageData: *const ImageData,
        finalLayout: c.VkImageLayout,
        _: c.VkAccessFlags,
    ) !void {
        const pixels = if (imageData.pixels) |v| v else return;

        const size: c.VkDeviceSize = imageData.size;

        var uploadPool = try VulkanCommandPool.new(gpuAllocator.context, gpuAllocator.context.device.graphicsQueue.familyIndex);
        defer uploadPool.destroy(gpuAllocator.context);

        const uploadCmd = try VulkanCommandBuffer.new(gpuAllocator.context, &uploadPool);

        var stagingBuffer = try VulkanBuffer.new(
            gpuAllocator.context,
            size,
            c.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
        );
        defer stagingBuffer.destroy(gpuAllocator.context);

        var memory = try gpuAllocator.alloc(
            size,
            c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
            stagingBuffer.requirements,
        );
        defer gpuAllocator.free(&memory);

        memory.memory.bindBuffer(gpuAllocator.context, &stagingBuffer, memory.range.offset);

        var mapped: ?*anyopaque = undefined;
        vkCheck(c.vkMapMemory(gpuAllocator.context.device.handle, memory.memory.handle, memory.range.offset, size, 0, &mapped));
        _ = memcpy(mapped, pixels, size);
        c.vkUnmapMemory(gpuAllocator.context.device.handle, memory.memory.handle);

        uploadCmd.begin();
        {
            var imageBarrier = c.VkImageMemoryBarrier{};
            imageBarrier.sType = c.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
            imageBarrier.oldLayout = c.VK_IMAGE_LAYOUT_UNDEFINED;
            imageBarrier.newLayout = c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
            imageBarrier.srcQueueFamilyIndex = c.VK_QUEUE_FAMILY_IGNORED;
            imageBarrier.dstQueueFamilyIndex = c.VK_QUEUE_FAMILY_IGNORED;
            imageBarrier.image = self.image.handle;
            imageBarrier.subresourceRange.aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT;
            imageBarrier.subresourceRange.levelCount = 1;
            imageBarrier.subresourceRange.layerCount = 1;
            imageBarrier.srcAccessMask = 0;
            imageBarrier.dstAccessMask = c.VK_ACCESS_TRANSFER_WRITE_BIT;
            c.vkCmdPipelineBarrier(
                uploadCmd.handle,
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

            uploadCmd.copyBufferToImage(&stagingBuffer, &self.image, region);
        }
        {
            var imageBarrier = c.VkImageMemoryBarrier{};
            imageBarrier.sType = c.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
            imageBarrier.oldLayout = c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
            imageBarrier.newLayout = finalLayout;
            imageBarrier.srcQueueFamilyIndex = c.VK_QUEUE_FAMILY_IGNORED;
            imageBarrier.dstQueueFamilyIndex = c.VK_QUEUE_FAMILY_IGNORED;
            imageBarrier.image = self.image.handle;
            imageBarrier.subresourceRange.aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT;
            imageBarrier.subresourceRange.levelCount = 1;
            imageBarrier.subresourceRange.layerCount = 1;
            imageBarrier.srcAccessMask = c.VK_ACCESS_TRANSFER_WRITE_BIT;
            imageBarrier.dstAccessMask = c.VK_ACCESS_NONE;
            c.vkCmdPipelineBarrier(
                uploadCmd.handle,
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
        uploadCmd.end();

        var submitInfo = c.VkSubmitInfo{};
        submitInfo.sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO;
        submitInfo.commandBufferCount = 1;
        submitInfo.pCommandBuffers = &uploadCmd.handle;
        gpuAllocator.context.device.graphicsQueue.submit(&submitInfo, null);
        gpuAllocator.context.device.graphicsQueue.wait();
    }
};
