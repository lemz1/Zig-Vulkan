const std = @import("std");
const vulkan = @import("../vulkan.zig");
const c = @cImport(@cInclude("vulkan/vulkan.h"));

const Allocator = std.mem.Allocator;
const VulkanContext = vulkan.VulkanContext;
const VulkanDescriptorPool = vulkan.VulkanDescriptorPool;
const VulkanDescriptorSetLayout = vulkan.VulkanDescriptorSetLayout;
const VulkanDescriptorSet = vulkan.VulkanDescriptorSet;

pub const DescriptorSetGroup = struct {
    layout: VulkanDescriptorSetLayout,
    sets: []VulkanDescriptorSet,

    allocator: Allocator,

    pub fn new(
        context: *const VulkanContext,
        pool: *const VulkanDescriptorPool,
        bindings: []const c.VkDescriptorSetLayoutBinding,
        allocator: Allocator,
    ) !DescriptorSetGroup {
        const layout = try VulkanDescriptorSetLayout.new(context, bindings);

        const sets = try allocator.alloc(VulkanDescriptorSet, context.framesInFlight);
        for (0..sets.len) |i| {
            sets[i] = try VulkanDescriptorSet.new(context, pool, &layout);
        }

        return .{
            .layout = layout,
            .sets = sets,

            .allocator = allocator,
        };
    }

    pub fn destroy(self: *DescriptorSetGroup, context: *const VulkanContext) void {
        self.allocator.free(self.sets);
        self.layout.destroy(context);
    }

    pub fn get(self: *const DescriptorSetGroup, frameIndex: u32) *const VulkanDescriptorSet {
        return &self.sets[frameIndex];
    }
};
