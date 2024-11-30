const std = @import("std");
const base = @import("base.zig");
const vulkan = @import("../vulkan.zig");
const c = @cImport(@cInclude("vulkan/vulkan.h"));

const Allocator = std.mem.Allocator;
const VulkanDevice = vulkan.VulkanDevice;
const VulkanCommandPool = vulkan.VulkanCommandPool;
const VulkanCommandBuffer = vulkan.VulkanCommandBuffer;
const vkCheck = base.vkCheck;
const memcpy = @cImport(@cInclude("memory.h")).memcpy;

const VulkanShaderModuleError = error{
    CreateShaderModule,
};
const VulkanBufferError = error{
    CreateBuffer,
    CreateMemory,
};

pub const VulkanBuffer = struct {
    handle: c.VkBuffer,
    memory: c.VkDeviceMemory,

    uploadCmdPool: VulkanCommandPool,
    uploadCmdBuffer: VulkanCommandBuffer,

    pub fn new(device: *const VulkanDevice, size: u64, usage: c.VkBufferUsageFlags, memoryProperties: c.VkMemoryPropertyFlags) !VulkanBuffer {
        var createInfo = c.VkBufferCreateInfo{};
        createInfo.sType = c.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
        createInfo.size = size;
        createInfo.usage = usage;

        var buffer: c.VkBuffer = undefined;
        switch (c.vkCreateBuffer(device.handle, &createInfo, null, &buffer)) {
            c.VK_SUCCESS => {},
            else => {
                std.debug.print("[Vulkan] Could not create Buffer\n", .{});
                return VulkanBufferError.CreateBuffer;
            },
        }

        var memoryRequirements: c.VkMemoryRequirements = undefined;
        c.vkGetBufferMemoryRequirements(device.handle, buffer, &memoryRequirements);

        const memoryIndex = try base.findMemoryType(device, memoryRequirements.memoryTypeBits, memoryProperties);

        var allocateInfo = c.VkMemoryAllocateInfo{};
        allocateInfo.sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
        allocateInfo.allocationSize = memoryRequirements.size;
        allocateInfo.memoryTypeIndex = memoryIndex;

        var memory: c.VkDeviceMemory = undefined;
        switch (c.vkAllocateMemory(device.handle, &allocateInfo, null, &memory)) {
            c.VK_SUCCESS => {},
            else => {
                std.debug.print("[Vulkan] Could not allocate Memory\n", .{});
                return VulkanBufferError.CreateBuffer;
            },
        }

        vkCheck(c.vkBindBufferMemory(device.handle, buffer, memory, 0));

        const uploadCmdPool = try VulkanCommandPool.new(device, device.graphicsQueue.familyIndex);
        const uploadCmdBuffer = try VulkanCommandBuffer.new(device, &uploadCmdPool);

        return .{
            .handle = buffer,
            .memory = memory,

            .uploadCmdPool = uploadCmdPool,
            .uploadCmdBuffer = uploadCmdBuffer,
        };
    }

    pub fn destroy(self: *VulkanBuffer, device: *const VulkanDevice) void {
        self.uploadCmdBuffer.destroy(device, &self.uploadCmdPool);
        self.uploadCmdPool.destroy(device);
        c.vkFreeMemory(device.handle, self.memory, null);
        c.vkDestroyBuffer(device.handle, self.handle, null);
    }

    pub fn uploadData(self: *const VulkanBuffer, device: *const VulkanDevice, data: anytype) !void {
        const typeInfo = @typeInfo(@TypeOf(data));

        comptime {
            if (typeInfo != .pointer or typeInfo.pointer.size != .Slice) {
                @compileError("Data is not a Slice\n");
            }
        }

        const size: c.VkDeviceSize = data.len * @sizeOf(typeInfo.pointer.child);

        if (device.hasResizableBAR) {
            var mapped: ?*anyopaque = undefined;
            vkCheck(c.vkMapMemory(device.handle, self.memory, 0, size, 0, &mapped));
            _ = memcpy(mapped, data.ptr, size);
            c.vkUnmapMemory(device.handle, self.memory);
        } else {
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
            device.graphicsQueue.submit(&submitInfo, null);
            device.graphicsQueue.wait();
        }
    }
};
