const gpu = @import("../gpu.zig");
const vulkan = @import("../vulkan.zig");
const c = @cImport(@cInclude("vulkan/vulkan.h"));

const GPUAllocator = gpu.GPUAllocator;
const MemoryBlock = gpu.MemoryBlock;
const VulkanBuffer = @import("../vulkan/vulkan_buffer_new.zig").VulkanBuffer;

pub const UniformBuffer = struct {
    buffer: VulkanBuffer,
    memory: MemoryBlock,

    pub fn new(gpuAllocator: *GPUAllocator, size: usize) !UniformBuffer {
        const buffer = try VulkanBuffer.new(
            gpuAllocator.context,
            size,
            c.VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT,
            c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        );

        const memory = try gpuAllocator.alloc(size, buffer.properties, buffer.requirements);
        return .{
            .buffer = buffer,
            .memory = memory,
        };
    }

    pub fn destroy(self: *UniformBuffer, gpuAllocator: *GPUAllocator) void {
        gpuAllocator.free(&self.memory);
        self.buffer.destroy(gpuAllocator.context);
    }
};
