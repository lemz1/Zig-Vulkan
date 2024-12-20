const std = @import("std");
const vulkan = @import("../vulkan.zig");
const c = @cImport(@cInclude("vulkan/vulkan.h"));

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const VulkanMemory = vulkan.VulkanMemory;
const VulkanContext = vulkan.VulkanContext;

const minAllocSize = 16 * 1024 * 1024;

const MemoryRange = struct {
    offset: c.VkDeviceSize,
    size: c.VkDeviceSize,
};

const AllocatedMemory = struct {
    memory: VulkanMemory,
    ranges: ArrayList(MemoryRange),

    pub fn new(memory: VulkanMemory, allocator: Allocator) AllocatedMemory {
        return .{
            .memory = memory,
            .ranges = ArrayList(MemoryRange).init(allocator),
        };
    }

    pub fn destroy(self: *AllocatedMemory, context: *const VulkanContext) void {
        self.ranges.deinit();
        self.memory.destroy(context);
    }

    pub fn add(self: *AllocatedMemory, range: MemoryRange) !void {
        try self.ranges.append(range);

        // use insertion sort, because ranges is almost sorted
        std.sort.insertion(MemoryRange, self.ranges.items, .{}, sort);
    }

    pub fn remove(self: *AllocatedMemory, range: MemoryRange) void {
        for (0..self.ranges.items.len) |i| {
            if (self.ranges.items[i].offset == range.offset) {
                _ = self.ranges.swapRemove(i);
                break;
            }
        }

        // use insertion sort, because ranges is almost sorted
        std.sort.insertion(MemoryRange, self.ranges.items, .{}, sort);
    }

    fn sort(_: @TypeOf(.{}), a: MemoryRange, b: MemoryRange) bool {
        return a.offset < b.offset;
    }
};

pub const MemoryBlock = struct {
    memory: *const VulkanMemory,
    range: MemoryRange,
};

pub const GPUAllocator = struct {
    context: *const VulkanContext,
    memories: ArrayList(AllocatedMemory),

    allocator: Allocator,

    pub fn new(context: *const VulkanContext, allocator: Allocator) !GPUAllocator {
        return .{
            .context = context,
            .memories = ArrayList(AllocatedMemory).init(allocator),

            .allocator = allocator,
        };
    }

    pub fn destroy(self: *GPUAllocator) void {
        for (self.memories.items) |*memory| {
            memory.destroy(self.context);
        }
        self.memories.deinit();
    }

    pub fn alloc(
        self: *GPUAllocator,
        size: c.VkDeviceSize,
        memoryProperties: c.VkMemoryPropertyFlags,
        memoryRequirements: c.VkMemoryRequirements,
    ) !MemoryBlock {
        for (self.memories.items) |*memory| {
            if (memory.memory.memoryRequirements & memoryRequirements.memoryTypeBits == 0 or memory.memory.memoryProperties & memoryProperties == 0 or memory.memory.size < size) {
                continue;
            }

            if (memory.ranges.items.len == 0) {
                const blockSize = memory.memory.size;
                if (blockSize >= size) {
                    const range = .{ .offset = 0, .size = size };
                    try memory.add(range);

                    return .{
                        .memory = &memory.memory,
                        .range = range,
                    };
                }
            }

            for (0..memory.ranges.items.len - 1) |i| {
                const offset = memory.ranges.items[i].offset + memory.ranges.items[i].size;
                const blockSize = memory.ranges.items[i + 1].offset - offset;

                if (blockSize >= size) {
                    const range = .{ .offset = offset, .size = size };
                    try memory.add(range);

                    return .{
                        .memory = &memory.memory,
                        .range = range,
                    };
                }
            }

            const offset = memory.ranges.items[memory.ranges.items.len - 1].offset + memory.ranges.items[memory.ranges.items.len - 1].size;
            const blockSize = memory.memory.size - offset;
            if (blockSize >= size) {
                const range = .{ .offset = offset, .size = size };
                try memory.add(range);

                return .{
                    .memory = &memory.memory,
                    .range = range,
                };
            }
        }

        const memory = try VulkanMemory.new(
            self.context,
            if (size < minAllocSize) minAllocSize else size,
            memoryRequirements.memoryTypeBits,
            memoryProperties,
        );
        try self.memories.append(AllocatedMemory.new(
            memory,
            self.allocator,
        ));

        return self.alloc(size, memoryProperties, memoryRequirements);
    }

    pub fn free(self: *GPUAllocator, block: *const MemoryBlock) void {
        for (self.memories.items) |*memory| {
            if (&memory.memory == block.memory) {
                memory.remove(block.range);
                return;
            }
        }
    }
};
