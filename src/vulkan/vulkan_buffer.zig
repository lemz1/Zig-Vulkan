const std = @import("std");
const base = @import("base.zig");
const vulkan = @import("../vulkan.zig");
const c = @cImport(@cInclude("vulkan/vulkan.h"));

const Allocator = std.mem.Allocator;
const VulkanContext = vulkan.VulkanContext;
const VulkanCommandPool = vulkan.VulkanCommandPool;
const VulkanCommandBuffer = vulkan.VulkanCommandBuffer;
const vkCheck = base.vkCheck;
const memcpy = @cImport(@cInclude("memory.h")).memcpy;

const VulkanBufferError = error{
    CreateBuffer,
    CreateMemory,
};

pub const VulkanBuffer = struct {
    handle: c.VkBuffer,
    memory: c.VkDeviceMemory,

    uploadCmdPool: VulkanCommandPool,
    uploadCmdBuffer: VulkanCommandBuffer,

    pub fn new(context: *const VulkanContext, size: u64, usage: c.VkBufferUsageFlags, memoryProperties: c.VkMemoryPropertyFlags) !VulkanBuffer {
        var createInfo = c.VkBufferCreateInfo{};
        createInfo.sType = c.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
        createInfo.size = size;
        createInfo.usage = usage;

        var buffer: c.VkBuffer = undefined;
        switch (c.vkCreateBuffer(context.device.handle, &createInfo, null, &buffer)) {
            c.VK_SUCCESS => {},
            else => {
                std.debug.print("[Vulkan] Could not create Buffer\n", .{});
                return VulkanBufferError.CreateBuffer;
            },
        }

        var memoryRequirements: c.VkMemoryRequirements = undefined;
        c.vkGetBufferMemoryRequirements(context.device.handle, buffer, &memoryRequirements);

        const memoryIndex = try base.findMemoryType(context, memoryRequirements.memoryTypeBits, memoryProperties);

        var allocateInfo = c.VkMemoryAllocateInfo{};
        allocateInfo.sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
        allocateInfo.allocationSize = memoryRequirements.size;
        allocateInfo.memoryTypeIndex = memoryIndex;

        var memory: c.VkDeviceMemory = undefined;
        switch (c.vkAllocateMemory(context.device.handle, &allocateInfo, null, &memory)) {
            c.VK_SUCCESS => {},
            else => {
                std.debug.print("[Vulkan] Could not allocate Memory\n", .{});
                return VulkanBufferError.CreateBuffer;
            },
        }

        vkCheck(c.vkBindBufferMemory(context.device.handle, buffer, memory, 0));

        const uploadCmdPool = try VulkanCommandPool.new(context, context.device.graphicsQueue.familyIndex);
        const uploadCmdBuffer = try VulkanCommandBuffer.new(context, &uploadCmdPool);

        return .{
            .handle = buffer,
            .memory = memory,

            .uploadCmdPool = uploadCmdPool,
            .uploadCmdBuffer = uploadCmdBuffer,
        };
    }

    pub fn destroy(self: *VulkanBuffer, context: *const VulkanContext) void {
        self.uploadCmdPool.destroy(context);
        c.vkFreeMemory(context.device.handle, self.memory, null);
        c.vkDestroyBuffer(context.device.handle, self.handle, null);
    }

    pub fn uploadData(self: *const VulkanBuffer, context: *const VulkanContext, data: anytype) !void {
        const typeInfo = @typeInfo(@TypeOf(data));

        comptime {
            if (typeInfo != .pointer or typeInfo.pointer.size != .Slice) {
                @compileError("Data is not a Slice\n");
            }
        }

        const size: c.VkDeviceSize = data.len * @sizeOf(typeInfo.pointer.child);

        if (context.device.hasResizableBAR) {
            var mapped: ?*anyopaque = undefined;
            vkCheck(c.vkMapMemory(context.device.handle, self.memory, 0, size, 0, &mapped));
            _ = memcpy(mapped, data.ptr, size);
            c.vkUnmapMemory(context.device.handle, self.memory);
        } else {
            var stagingBuffer = try VulkanBuffer.new(
                context,
                size,
                c.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
                c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
            );
            defer stagingBuffer.destroy(context);

            var mapped: ?*anyopaque = undefined;
            vkCheck(c.vkMapMemory(context.device.handle, stagingBuffer.memory, 0, size, 0, &mapped));
            _ = memcpy(mapped, data.ptr, size);
            c.vkUnmapMemory(context.device.handle, stagingBuffer.memory);

            self.uploadCmdPool.reset(context);

            self.uploadCmdBuffer.begin();
            self.uploadCmdBuffer.copyBuffer(&stagingBuffer, self, .{
                .srcOffset = 0,
                .dstOffset = 0,
                .size = size,
            });
            self.uploadCmdBuffer.end();

            var submitInfo = c.VkSubmitInfo{};
            submitInfo.sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO;
            submitInfo.commandBufferCount = 1;
            submitInfo.pCommandBuffers = &self.uploadCmdBuffer.handle;
            context.device.graphicsQueue.submit(&submitInfo, null);
            context.device.graphicsQueue.wait();
        }
    }
};
