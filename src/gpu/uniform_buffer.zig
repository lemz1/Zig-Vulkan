const gpu = @import("../gpu.zig");
const vulkan = @import("../vulkan.zig");
const c = @cImport(@cInclude("vulkan/vulkan.h"));

const GPUAllocator = gpu.GPUAllocator;
const MemoryBlock = gpu.MemoryBlock;
const VulkanContext = vulkan.VulkanContext;
const VulkanBuffer = vulkan.VulkanBuffer;
const vkCheck = vulkan.vkCheck;
const memcpy = @cImport(@cInclude("memory.h")).memcpy;

pub const UniformBuffer = struct {
    buffer: VulkanBuffer,
    memory: MemoryBlock,

    pub fn new(gpuAllocator: *GPUAllocator, size: usize) !UniformBuffer {
        const buffer = try VulkanBuffer.new(
            gpuAllocator.context,
            size,
            c.VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT,
        );

        const memory = try gpuAllocator.alloc(
            size,
            c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
            buffer.requirements,
        );
        memory.memory.bindBuffer(gpuAllocator.context, &buffer, memory.range.offset);

        return .{
            .buffer = buffer,
            .memory = memory,
        };
    }

    pub fn destroy(self: *UniformBuffer, gpuAllocator: *GPUAllocator) void {
        gpuAllocator.free(&self.memory);
        self.buffer.destroy(gpuAllocator.context);
    }

    pub fn uploadData(
        self: *const UniformBuffer,
        context: *const VulkanContext,
        data: anytype,
    ) void {
        const typeInfo = @typeInfo(@TypeOf(data));

        comptime {
            if (typeInfo != .pointer or typeInfo.pointer.size != .Slice) {
                @compileError("Data is not a Slice\n");
            }
        }

        const size: c.VkDeviceSize = data.len * @sizeOf(typeInfo.pointer.child);

        var mapped: ?*anyopaque = undefined;
        vkCheck(c.vkMapMemory(context.device.handle, self.memory.memory.handle, self.memory.range.offset, size, 0, &mapped));
        _ = memcpy(mapped, data.ptr, size);
        c.vkUnmapMemory(context.device.handle, self.memory.memory.handle);
    }
};
