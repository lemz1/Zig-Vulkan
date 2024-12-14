const std = @import("std");
const glslang = @import("../glslang.zig");
const spvc = @import("../spvc.zig");
const vulkan = @import("../vulkan.zig");
const util = @import("../util.zig");
const c = @cImport(@cInclude("vulkan/vulkan.h"));

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const AutoHashMap = std.hash_map.AutoHashMap;
const RuntimeShader = glslang.RuntimeShader;
const SPVCContext = spvc.SPVCContext;
const SPVCParsedIR = spvc.SPVCParsedIR;
const SPVCCompiler = spvc.SPVCCompiler;
const SPVCType = spvc.SPVCType;
const SPVCBaseType = spvc.SPVCBaseType;
const SPVCResources = spvc.SPVCResources;
const VulkanContext = vulkan.VulkanContext;
const VulkanRenderPass = vulkan.VulkanRenderPass;
const VulkanShaderModule = vulkan.VulkanShaderModule;
const VulkanDescriptorPool = vulkan.VulkanDescriptorPool;
const VulkanDescriptorSet = vulkan.VulkanDescriptorSet;
const VulkanPipeline = vulkan.VulkanPipeline;
const DescriptorSetGroup = util.DescriptorSetGroup;

const maxBindings = 16;

const ResourceInfo = struct {
    stage: c.VkShaderStageFlags,
    resources: *const SPVCResources,
    compiler: *const SPVCCompiler,
};

pub const Pipeline = struct {
    descriptorPool: VulkanDescriptorPool,
    descriptorSet: DescriptorSetGroup,
    pipeline: VulkanPipeline,

    pub fn graphicsPipeline(
        vulkanContext: *const VulkanContext,
        spvcContext: *const SPVCContext,
        renderPass: *const VulkanRenderPass,
        vertexShader: *const RuntimeShader,
        fragmentShader: *const RuntimeShader,
        allocator: Allocator,
    ) !Pipeline {
        defer spvcContext.release();

        const vertexParsedIR = try SPVCParsedIR.new(spvcContext, vertexShader.spirvCode, vertexShader.spirvWords);
        const vertexCompiler = try SPVCCompiler.new(spvcContext, &vertexParsedIR);
        const vertexResources = try SPVCResources.new(&vertexCompiler);

        const fragmentParsedIR = try SPVCParsedIR.new(spvcContext, fragmentShader.spirvCode, fragmentShader.spirvWords);
        const fragmentCompiler = try SPVCCompiler.new(spvcContext, &fragmentParsedIR);
        const fragmentResources = try SPVCResources.new(&fragmentCompiler);

        const layoutBindings = try createDescriptorSetLayoutBindings(
            &.{
                .{
                    .stage = c.VK_SHADER_STAGE_VERTEX_BIT,
                    .resources = &vertexResources,
                    .compiler = &vertexCompiler,
                },
                .{
                    .stage = c.VK_SHADER_STAGE_FRAGMENT_BIT,
                    .resources = &fragmentResources,
                    .compiler = &fragmentCompiler,
                },
            },
            allocator,
        );
        defer allocator.free(layoutBindings);

        const descriptorPoolSizes = try createDescriptorPoolSizes(
            vulkanContext,
            &.{ &vertexResources, &fragmentResources },
            allocator,
        );
        defer allocator.free(descriptorPoolSizes);

        const descriptorPool = try VulkanDescriptorPool.new(vulkanContext, descriptorPoolSizes);

        const descriptorSet = try DescriptorSetGroup.new(
            vulkanContext,
            &descriptorPool,
            layoutBindings,
            vulkanContext.framesInFlight,
            allocator,
        );

        const inputAttributes = try createInputAttributes(&vertexCompiler, &vertexResources, allocator);
        defer allocator.free(inputAttributes);

        const inputBindings = try createInputBindings(inputAttributes, allocator);
        defer allocator.free(inputBindings);

        var vertexModule = try VulkanShaderModule.new(vulkanContext, vertexShader.spirvSize, vertexShader.spirvCode);
        defer vertexModule.destroy(vulkanContext);

        var fragmentModule = try VulkanShaderModule.new(vulkanContext, fragmentShader.spirvSize, fragmentShader.spirvCode);
        defer fragmentModule.destroy(vulkanContext);

        const pipeline = try VulkanPipeline.new(
            vulkanContext,
            renderPass,
            &vertexModule,
            &fragmentModule,
            inputAttributes,
            inputBindings,
            &.{descriptorSet.layout.handle},
        );

        return .{
            .descriptorPool = descriptorPool,
            .descriptorSet = descriptorSet,
            .pipeline = pipeline,
        };
    }

    pub fn destroy(self: *Pipeline, vulkanContext: *const VulkanContext) void {
        self.pipeline.destroy(vulkanContext);
        self.descriptorSet.destroy(vulkanContext);
        self.descriptorPool.destroy(vulkanContext);
    }

    fn createInputAttributes(
        spvcCompiler: *const SPVCCompiler,
        spvcResources: *const SPVCResources,
        allocator: Allocator,
    ) ![]c.VkVertexInputAttributeDescription {
        const resourceList = spvcResources.getResourceList(.StageInput);

        var attributes = try ArrayList(c.VkVertexInputAttributeDescription).initCapacity(allocator, resourceList.count);

        var offsets = std.mem.zeroes([maxBindings]u32);

        for (0..resourceList.count) |i| {
            const spvcResource = resourceList.resources[i];
            const spvcType = try SPVCType.new(spvcCompiler, spvcResource.type_id);
            const baseType = spvcType.getBaseType();
            const vectorSize = spvcType.getVectorSize();

            const binding = spvcCompiler.getDecoration(spvcResource.id, .Binding);
            const location = spvcCompiler.getDecoration(spvcResource.id, .Location);
            const format = try getFormat(baseType, vectorSize);

            try attributes.append(.{
                .binding = binding,
                .location = location,
                .format = format,
                .offset = offsets[binding],
            });

            offsets[binding] += 2 * @sizeOf(f32);
        }

        return attributes.toOwnedSlice();
    }

    fn createInputBindings(
        attributes: []const c.VkVertexInputAttributeDescription,
        allocator: Allocator,
    ) ![]c.VkVertexInputBindingDescription {
        var bindings = ArrayList(c.VkVertexInputBindingDescription).init(allocator);

        for (attributes) |*attribute| {
            var binding = blk: {
                for (bindings.items) |*item| {
                    if (item.binding == attribute.binding) {
                        break :blk item;
                    }
                }

                try bindings.append(.{
                    .binding = attribute.binding,
                    .inputRate = c.VK_VERTEX_INPUT_RATE_VERTEX,
                    .stride = 0,
                });
                break :blk &bindings.items[bindings.items.len - 1];
            };

            binding.stride += getSize(attribute.format);
        }

        return bindings.toOwnedSlice();
    }

    fn createDescriptorSetLayoutBindings(
        resourceInfos: []const ResourceInfo,
        allocator: Allocator,
    ) ![]c.VkDescriptorSetLayoutBinding {
        var bindings = ArrayList(c.VkDescriptorSetLayoutBinding).init(allocator);

        for (resourceInfos) |info| {
            const uniformBuffers = info.resources.getResourceList(.UniformBuffer);

            for (0..uniformBuffers.count) |i| {
                const resource = uniformBuffers.resources[i];
                const binding = info.compiler.getDecoration(resource.id, .Binding);

                try bindings.append(.{
                    .binding = binding,
                    .descriptorCount = 1,
                    .descriptorType = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
                    .stageFlags = info.stage,
                    .pImmutableSamplers = null,
                });
            }

            const smapledImages = info.resources.getResourceList(.SampledImage);

            for (0..smapledImages.count) |i| {
                const resource = smapledImages.resources[i];
                const binding = info.compiler.getDecoration(resource.id, .Binding);

                try bindings.append(.{
                    .binding = binding,
                    .descriptorCount = 1,
                    .descriptorType = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
                    .stageFlags = info.stage,
                    .pImmutableSamplers = null,
                });
            }
        }

        return bindings.toOwnedSlice();
    }

    fn createDescriptorPoolSizes(
        vulkanContext: *const VulkanContext,
        spvcResources: []const *const SPVCResources,
        allocator: Allocator,
    ) ![]c.VkDescriptorPoolSize {
        var poolSizes = ArrayList(c.VkDescriptorPoolSize).init(allocator);

        var uniformBuffers: u32 = 0;
        var sampledImages: u32 = 0;
        for (spvcResources) |resources| {
            uniformBuffers += @intCast(resources.getResourceList(.UniformBuffer).count);
            sampledImages += @intCast(resources.getResourceList(.SampledImage).count);
        }

        if (uniformBuffers > 0) {
            try poolSizes.append(.{
                .descriptorCount = vulkanContext.framesInFlight * uniformBuffers,
                .type = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
            });
        }

        if (sampledImages > 0) {
            try poolSizes.append(.{
                .descriptorCount = vulkanContext.framesInFlight * sampledImages,
                .type = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
            });
        }

        return poolSizes.toOwnedSlice();
    }

    fn getFormat(baseType: SPVCBaseType, vectorSize: u32) !c.VkFormat {
        switch (baseType) {
            .Float32 => {
                switch (vectorSize) {
                    1 => return c.VK_FORMAT_R32_SFLOAT,
                    2 => return c.VK_FORMAT_R32G32_SFLOAT,
                    3 => return c.VK_FORMAT_R32G32B32_SFLOAT,
                    4 => return c.VK_FORMAT_R32G32B32A32_SFLOAT,
                    else => return error.LOL,
                }
            },
            else => return error.LOL,
        }
    }

    fn getSize(format: c.VkFormat) u32 {
        switch (format) {
            c.VK_FORMAT_R32_SFLOAT => return @sizeOf(f32),
            c.VK_FORMAT_R32G32_SFLOAT => return @sizeOf(f32) * 2,
            c.VK_FORMAT_R32G32B32_SFLOAT => return @sizeOf(f32) * 3,
            c.VK_FORMAT_R32G32B32A32_SFLOAT => return @sizeOf(f32) * 4,
            else => return 0,
        }
    }
};
