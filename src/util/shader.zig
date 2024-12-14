const std = @import("std");
const glslang = @import("../glslang.zig");
const vulkan = @import("../vulkan.zig");
const c = @cImport(@cInclude("vulkan/vulkan.h"));

const Allocator = std.mem.Allocator;
const RuntimeShader = glslang.RuntimeShader;
const VulkanDevice = vulkan.VulkanDevice;
const VulkanRenderPass = vulkan.VulkanRenderPass;
const VulkanShaderModule = vulkan.VulkanShaderModule;
const VulkanDescriptorPool = vulkan.VulkanDescriptorPool;
const VulkanDescriptorSet = vulkan.VulkanDescriptorSet;
const VulkanPipeline = vulkan.VulkanPipeline;

pub const Pipeline = struct {
    descriptorPool: VulkanDescriptorPool,
    descriptorSets: [][]VulkanDescriptorSet,
    pipeline: VulkanPipeline,
    allocator: Allocator,

    pub fn graphicsPipeline(
        device: *const VulkanDevice,
        renderPass: *const VulkanRenderPass,
        framesInFlight: u32,
        vertexShader: *const RuntimeShader,
        fragmentShader: *const RuntimeShader,
        bindingDescriptions: []const c.VkVertexInputBindingDescription,
        allocator: Allocator,
    ) !Pipeline {
        var vertexModule = try VulkanShaderModule.new(device, vertexShader.spirvSize, vertexShader.spirvCode);
        defer vertexModule.destroy(device);

        var fragmentModule = try VulkanShaderModule.new(device, fragmentShader.spirvSize, fragmentShader.spirvCode);
        defer fragmentModule.destroy(device);

        const descriptorPool = blk: {
            break :blk try VulkanDescriptorPool.new(device, poolSizes);
        };

        const descriptorSets = try allocator.alloc([]VulkanDescriptorSet, framesInFlight);
        for (0..descriptorSets.len) |i| {
            descriptorSets[i] = try allocator.alloc(VulkanDescriptorSet, descriptorsToGenerate);
        }

        const pipeline = try VulkanPipeline.new(
            device,
            &vertexModule,
            &fragmentModule,
            renderPass,
            attributeDescriptions, // generate this
            bindingDescriptions,
            descriptorSetLayouts, // generate this
        );
        return .{
            .pipeline = pipeline,
        };
    }

    pub fn destroy(self: *Pipeline, device: *const VulkanDevice) void {
        self.pipeline.destroy(device);
        for (self.descriptorSets) |sets| {
            for (sets) |*set| {
                set.destroy(device);
            }
            self.allocator.free(sets);
        }
        self.allocator.free(self.descriptorSets);
        self.descriptorPool.destroy(device);
    }
};
