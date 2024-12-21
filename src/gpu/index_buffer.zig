const gpu = @import("../gpu.zig");
const vulkan = @import("../vulkan.zig");
const c = @cImport(@cInclude("vulkan/vulkan.h"));

const GPUAllocator = gpu.GPUAllocator;
const MemoryBlock = gpu.MemoryBlock;
const VulkanContext = vulkan.VulkanContext;
const VulkanBuffer = vulkan.VulkanBuffer;
const VulkanCommandBuffer = vulkan.VulkanCommandBuffer;
const vkCheck = vulkan.vkCheck;
const memcpy = @cImport(@cInclude("memory.h")).memcpy;

pub const IndexBuffer = struct {
    buffer: VulkanBuffer,
    memory: MemoryBlock,

    stagingBuffer: VulkanBuffer,
    stagingMemory: MemoryBlock,

    pub fn new(gpuAllocator: *GPUAllocator, size: usize) !IndexBuffer {
        const buffer = try VulkanBuffer.new(
            gpuAllocator.context,
            size,
            c.VK_BUFFER_USAGE_INDEX_BUFFER_BIT,
        );

        const memory = try gpuAllocator.alloc(
            size,
            c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
            buffer.requirements,
        );
        memory.memory.bindBuffer(gpuAllocator.context, &buffer, memory.range.offset);

        const stagingBuffer = try VulkanBuffer.new(
            gpuAllocator.context,
            size,
            c.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
        );

        const stagingMemory = try gpuAllocator.alloc(
            size,
            c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
            stagingBuffer.requirements,
        );
        stagingMemory.memory.bindBuffer(gpuAllocator.context, &stagingBuffer, stagingMemory.range.offset);

        return .{
            .buffer = buffer,
            .memory = memory,

            .stagingBuffer = stagingBuffer,
            .stagingMemory = stagingMemory,
        };
    }

    pub fn destroy(self: *IndexBuffer, gpuAllocator: *GPUAllocator) void {
        gpuAllocator.free(&self.stagingMemory);
        self.stagingBuffer.destroy(gpuAllocator.context);

        gpuAllocator.free(&self.memory);
        self.buffer.destroy(gpuAllocator.context);
    }

    pub fn uploadData(
        self: *const IndexBuffer,
        context: *const VulkanContext,
        cmd: *const VulkanCommandBuffer,
        data: anytype,
    ) void {
        const typeInfo = @typeInfo(@TypeOf(data));

        comptime {
            if (typeInfo != .pointer or typeInfo.pointer.size != .Slice) {
                @compileError("Data is not a Slice\n");
            }
        }

        const size: c.VkDeviceSize = data.len * @sizeOf(typeInfo.pointer.child);

        if (context.device.hasResizableBAR) {
            var mapped: ?*anyopaque = undefined;
            vkCheck(c.vkMapMemory(context.device.handle, self.memory.memory.handle, self.memory.range.offset, size, 0, &mapped));
            _ = memcpy(mapped, data.ptr, size);
            c.vkUnmapMemory(context.device.handle, self.memory.memory.handle);
        } else {
            var mapped: ?*anyopaque = undefined;
            vkCheck(c.vkMapMemory(context.device.handle, self.stagingMemory.memory.handle, self.stagingMemory.range.offset, size, 0, &mapped));
            _ = memcpy(mapped, data.ptr, size);
            c.vkUnmapMemory(context.device.handle, self.stagingMemory.memory.handle);

            cmd.copyBuffer(&self.stagingBuffer, &self.buffer, .{
                .srcOffset = 0,
                .dstOffset = 0,
                .size = size,
            });
        }
    }
};
