const std = @import("std");
const vulkan = @import("../vulkan.zig");
const c = @cImport(@cInclude("vulkan/vulkan.h"));

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const VulkanMemory = vulkan.VulkanMemory;
const VulkanContext = vulkan.VulkanContext;

const memoryAllocationSize = 16 * 1024 * 1024;

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

    pub fn remove(self: *AllocatedMemory, range: *const MemoryRange) void {
        for (0..self.ranges.items.len) |i| {
            if (&self.ranges.items[i] == range) {
                self.ranges.swapRemove(i);
                break;
            }
        }

        // use insertion sort, because ranges is almost sorted
        std.sort.insertion(MemoryRange, self.ranges.items, .{}, sort);
    }

    fn sort(_: anytype, a: MemoryRange, b: MemoryRange) bool {
        return a.offset < b.offset;
    }
};

const MemoryBlock = struct {
    memory: *const VulkanMemory,
    range: *const MemoryRange,
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

    pub fn get(self: *GPUAllocator, size: c.VkDeviceSize, typeFilter: u32, memoryProperties: c.VkMemoryPropertyFlags) !MemoryBlock {
        for (self.memories.items) |*memory| {
            if (memory.size - memory.offset >= size) {
                return .{
                    .memory = memory,
                    .offset = memory.offset,
                    .size = size,
                };
            }
        }

        self.allocate(typeFilter, memoryProperties);

        return self.get(size, typeFilter, memoryProperties);
    }

    fn allocate(self: *GPUAllocator, typeFilter: u32, memoryProperties: c.VkMemoryPropertyFlags) !void {
        const memory = try VulkanMemory.new(self.context, memoryAllocationSize, typeFilter, memoryProperties);
        self.memories.append(AllocatedMemory.new(
            memory,
            self.allocator,
        ));
    }
};
