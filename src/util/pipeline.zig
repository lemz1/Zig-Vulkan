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

const InputAttributeInfo = struct {
    attributes: []c.VkVertexInputAttributeDescription,
    sizes: []u32,
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

        const inputAttributeInfos = try createInputAttributes(&vertexCompiler, &vertexResources, allocator);
        defer allocator.free(inputAttributeInfos.attributes);
        defer allocator.free(inputAttributeInfos.sizes);

        const inputBindings = try createInputBindings(&inputAttributeInfos, allocator);
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
            inputAttributeInfos.attributes,
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
    ) !InputAttributeInfo {
        const resourceList = spvcResources.getResourceList(.StageInput);

        var attributes = try ArrayList(c.VkVertexInputAttributeDescription).initCapacity(allocator, resourceList.count);
        var sizes = try ArrayList(u32).initCapacity(allocator, resourceList.count);

        var offsets = std.mem.zeroes([maxBindings]u32);

        for (0..resourceList.count) |i| {
            const spvcResource = resourceList.resources[i];
            const spvcType = try SPVCType.new(spvcCompiler, spvcResource.type_id);
            const baseType = spvcType.getBaseType();
            const vectorSize = spvcType.getVectorSize();
            const numDimensions = spvcType.getNumDimensions();
            var multiplier: u32 = 1;
            for (0..numDimensions) |j| {
                multiplier *= spvcType.getDimensions(@intCast(j));
            }

            const binding = spvcCompiler.getDecoration(spvcResource.id, .Binding);
            const location = spvcCompiler.getDecoration(spvcResource.id, .Location);
            const format = getFormat(baseType, vectorSize);

            try attributes.append(.{
                .binding = binding,
                .location = location,
                .format = format,
                .offset = offsets[binding],
            });

            const size = getSize(format) * multiplier;

            try sizes.append(size);

            offsets[binding] += size;
        }

        return .{
            .attributes = try attributes.toOwnedSlice(),
            .sizes = try sizes.toOwnedSlice(),
        };
    }

    fn createInputBindings(
        attributeInfos: *const InputAttributeInfo,
        allocator: Allocator,
    ) ![]c.VkVertexInputBindingDescription {
        var bindings = ArrayList(c.VkVertexInputBindingDescription).init(allocator);

        for (0..attributeInfos.attributes.len) |i| {
            var binding = blk: {
                for (bindings.items) |*item| {
                    if (item.binding == attributeInfos.attributes[i].binding) {
                        break :blk item;
                    }
                }

                try bindings.append(.{
                    .binding = attributeInfos.attributes[i].binding,
                    .inputRate = c.VK_VERTEX_INPUT_RATE_VERTEX,
                    .stride = 0,
                });
                break :blk &bindings.items[bindings.items.len - 1];
            };

            binding.stride += attributeInfos.sizes[i];
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

    fn getFormat(baseType: SPVCBaseType, vectorSize: u32) c.VkFormat {
        switch (baseType) {
            .Boolean => return c.VK_FORMAT_R8_SINT,
            .Int8 => {
                switch (vectorSize) {
                    1 => return c.VK_FORMAT_R8_SINT,
                    2 => return c.VK_FORMAT_R8G8_SINT,
                    3 => return c.VK_FORMAT_R8G8B8_SINT,
                    4 => return c.VK_FORMAT_R8G8B8A8_SINT,
                    else => unreachable,
                }
            },
            .UInt8 => {
                switch (vectorSize) {
                    1 => return c.VK_FORMAT_R8_UINT,
                    2 => return c.VK_FORMAT_R8G8_UINT,
                    3 => return c.VK_FORMAT_R8G8B8_UINT,
                    4 => return c.VK_FORMAT_R8G8B8A8_UINT,
                    else => unreachable,
                }
            },
            .Int16 => {
                switch (vectorSize) {
                    1 => return c.VK_FORMAT_R16_SINT,
                    2 => return c.VK_FORMAT_R16G16_SINT,
                    3 => return c.VK_FORMAT_R16G16B16_SINT,
                    4 => return c.VK_FORMAT_R16G16B16A16_SINT,
                    else => unreachable,
                }
            },
            .UInt16 => {
                switch (vectorSize) {
                    1 => return c.VK_FORMAT_R16_UINT,
                    2 => return c.VK_FORMAT_R16G16_UINT,
                    3 => return c.VK_FORMAT_R16G16B16_UINT,
                    4 => return c.VK_FORMAT_R16G16B16A16_UINT,
                    else => unreachable,
                }
            },
            .Int32 => {
                switch (vectorSize) {
                    1 => return c.VK_FORMAT_R32_SINT,
                    2 => return c.VK_FORMAT_R32G32_SINT,
                    3 => return c.VK_FORMAT_R32G32B32_SINT,
                    4 => return c.VK_FORMAT_R32G32B32A32_SINT,
                    else => unreachable,
                }
            },
            .UInt32 => {
                switch (vectorSize) {
                    1 => return c.VK_FORMAT_R32_UINT,
                    2 => return c.VK_FORMAT_R32G32_UINT,
                    3 => return c.VK_FORMAT_R32G32B32_UINT,
                    4 => return c.VK_FORMAT_R32G32B32A32_UINT,
                    else => unreachable,
                }
            },
            .Int64 => {
                switch (vectorSize) {
                    1 => return c.VK_FORMAT_R64_SINT,
                    2 => return c.VK_FORMAT_R64G64_SINT,
                    3 => return c.VK_FORMAT_R64G64B64_SINT,
                    4 => return c.VK_FORMAT_R64G64B64A64_SINT,
                    else => unreachable,
                }
            },
            .UInt64 => {
                switch (vectorSize) {
                    1 => return c.VK_FORMAT_R64_UINT,
                    2 => return c.VK_FORMAT_R64G64_UINT,
                    3 => return c.VK_FORMAT_R64G64B64_UINT,
                    4 => return c.VK_FORMAT_R64G64B64A64_UINT,
                    else => unreachable,
                }
            },
            .Float16 => {
                switch (vectorSize) {
                    1 => return c.VK_FORMAT_R16_SFLOAT,
                    2 => return c.VK_FORMAT_R16G16_SFLOAT,
                    3 => return c.VK_FORMAT_R16G16B16_SFLOAT,
                    4 => return c.VK_FORMAT_R16G16B16A16_SFLOAT,
                    else => unreachable,
                }
            },
            .Float32 => {
                switch (vectorSize) {
                    1 => return c.VK_FORMAT_R32_SFLOAT,
                    2 => return c.VK_FORMAT_R32G32_SFLOAT,
                    3 => return c.VK_FORMAT_R32G32B32_SFLOAT,
                    4 => return c.VK_FORMAT_R32G32B32A32_SFLOAT,
                    else => unreachable,
                }
            },
            .Float64 => {
                switch (vectorSize) {
                    1 => return c.VK_FORMAT_R64_SFLOAT,
                    2 => return c.VK_FORMAT_R64G64_SFLOAT,
                    3 => return c.VK_FORMAT_R64G64B64_SFLOAT,
                    4 => return c.VK_FORMAT_R64G64B64A64_SFLOAT,
                    else => unreachable,
                }
            },
            else => return c.VK_FORMAT_UNDEFINED,
        }
    }

    fn getSize(format: c.VkFormat) u32 {
        switch (format) {
            c.VK_FORMAT_R8_SINT => return @sizeOf(i8) * 1,
            c.VK_FORMAT_R8G8_SINT => return @sizeOf(i8) * 2,
            c.VK_FORMAT_R8G8B8_SINT => return @sizeOf(i8) * 3,
            c.VK_FORMAT_R8G8B8A8_SINT => return @sizeOf(i8) * 4,
            c.VK_FORMAT_R8_UINT => return @sizeOf(u8) * 1,
            c.VK_FORMAT_R8G8_UINT => return @sizeOf(u8) * 2,
            c.VK_FORMAT_R8G8B8_UINT => return @sizeOf(u8) * 3,
            c.VK_FORMAT_R8G8B8A8_UINT => return @sizeOf(u8) * 4,
            c.VK_FORMAT_R16_SINT => return @sizeOf(i16) * 1,
            c.VK_FORMAT_R16G16_SINT => return @sizeOf(i16) * 2,
            c.VK_FORMAT_R16G16B16_SINT => return @sizeOf(i16) * 3,
            c.VK_FORMAT_R16G16B16A16_SINT => return @sizeOf(i16) * 4,
            c.VK_FORMAT_R16_UINT => return @sizeOf(u16) * 1,
            c.VK_FORMAT_R16G16_UINT => return @sizeOf(u16) * 2,
            c.VK_FORMAT_R16G16B16_UINT => return @sizeOf(u16) * 3,
            c.VK_FORMAT_R16G16B16A16_UINT => return @sizeOf(u16) * 4,
            c.VK_FORMAT_R32_SINT => return @sizeOf(i32) * 1,
            c.VK_FORMAT_R32G32_SINT => return @sizeOf(i32) * 2,
            c.VK_FORMAT_R32G32B32_SINT => return @sizeOf(i32) * 3,
            c.VK_FORMAT_R32G32B32A32_SINT => return @sizeOf(i32) * 4,
            c.VK_FORMAT_R32_UINT => return @sizeOf(u32) * 1,
            c.VK_FORMAT_R32G32_UINT => return @sizeOf(u32) * 2,
            c.VK_FORMAT_R32G32B32_UINT => return @sizeOf(u32) * 3,
            c.VK_FORMAT_R32G32B32A32_UINT => return @sizeOf(u32) * 4,
            c.VK_FORMAT_R64_SINT => return @sizeOf(i64) * 1,
            c.VK_FORMAT_R64G64_SINT => return @sizeOf(i64) * 2,
            c.VK_FORMAT_R64G64B64_SINT => return @sizeOf(i64) * 3,
            c.VK_FORMAT_R64G64B64A64_SINT => return @sizeOf(i64) * 4,
            c.VK_FORMAT_R64_UINT => return @sizeOf(u64) * 1,
            c.VK_FORMAT_R64G64_UINT => return @sizeOf(u64) * 2,
            c.VK_FORMAT_R64G64B64_UINT => return @sizeOf(u64) * 3,
            c.VK_FORMAT_R64G64B64A64_UINT => return @sizeOf(u64) * 4,
            c.VK_FORMAT_R16_SFLOAT => return @sizeOf(f16) * 1,
            c.VK_FORMAT_R16G16_SFLOAT => return @sizeOf(f16) * 2,
            c.VK_FORMAT_R16G16B16_SFLOAT => return @sizeOf(f16) * 3,
            c.VK_FORMAT_R16G16B16A16_SFLOAT => return @sizeOf(f16) * 4,
            c.VK_FORMAT_R32_SFLOAT => return @sizeOf(f32) * 1,
            c.VK_FORMAT_R32G32_SFLOAT => return @sizeOf(f32) * 2,
            c.VK_FORMAT_R32G32B32_SFLOAT => return @sizeOf(f32) * 3,
            c.VK_FORMAT_R32G32B32A32_SFLOAT => return @sizeOf(f32) * 4,
            c.VK_FORMAT_R64_SFLOAT => return @sizeOf(f64) * 1,
            c.VK_FORMAT_R64G64_SFLOAT => return @sizeOf(f64) * 2,
            c.VK_FORMAT_R64G64B64_SFLOAT => return @sizeOf(f64) * 3,
            c.VK_FORMAT_R64G64B64A64_SFLOAT => return @sizeOf(f64) * 4,
            else => return 0,
        }
    }
};
