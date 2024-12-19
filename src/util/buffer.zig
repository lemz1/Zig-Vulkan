const std = @import("std");
const vulkan = @import("../vulkan.zig");
const c = @cImport(@cInclude("vulkan/vulkan.h"));

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const AutoHashMap = std.AutoHashMap;
const VulkanBuffer = vulkan.VulkanBuffer;
const VulkanContext = vulkan.VulkanContext;

const bufferSizeBytes: c.VkDeviceSize = 128 * 1000 * 1000;

pub const Buffer = struct {
    buffer: *const VulkanBuffer,
    offset: c.VkDeviceSize,
    size: c.VkDeviceSize,
};

pub const BufferManager = struct {
    context: *const VulkanContext,
    buffers: AutoHashMap(c.VkBufferUsageFlags, ArrayList(VulkanBuffer)),

    allocator: Allocator,

    pub fn new(context: *const VulkanContext, allocator: Allocator) !BufferManager {
        return .{
            .context = context,
            .buffers = AutoHashMap(c.VkBufferUsageFlags, ArrayList(VulkanBuffer)).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn destroy(self: *BufferManager) void {
        var it = self.buffers.valueIterator();
        while (it.next()) |buffer| {
            buffer.deinit();
        }
        self.buffers.deinit();
    }

    pub fn get(self: *BufferManager, size: c.VkDeviceSize, usage: c.VkBufferUsageFlags) !Buffer {
        var buffers = self.buffers.getPtr(usage);
        if (buffers == null) {
            buffers = try self.buffers.put(usage, ArrayList(VulkanBuffer).init(self.allocator));

            buffers.?.append(try VulkanBuffer.new(self.context, bufferSizeBytes, usage, c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT));
        }

        for (buffers.?.items) |*buffer| {
            // check whether the buffer has enough size
            // and give an offset
            return .{
                .buffer = buffer,
                .offset = 0,
                .size = size,
            };
        }
    }
};
