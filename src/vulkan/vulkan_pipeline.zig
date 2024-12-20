const std = @import("std");
const vulkan = @import("../vulkan.zig");
const c = @cImport(@cInclude("vulkan/vulkan.h"));

const Allocator = std.mem.Allocator;
const VulkanContext = vulkan.VulkanContext;
const VulkanRenderPass = vulkan.VulkanRenderPass;
const VulkanDescriptorSetLayout = vulkan.VulkanDescriptorSetLayout;
const VulkanShaderModule = vulkan.VulkanShaderModule;
const vkCheck = vulkan.vkCheck;

pub const VulkanPipeline = struct {
    handle: c.VkPipeline,
    layout: c.VkPipelineLayout,

    pub fn new(
        context: *const VulkanContext,
        renderPass: *const VulkanRenderPass,
        vertModule: *const VulkanShaderModule,
        fragModule: *const VulkanShaderModule,
        attributeDescriptions: []const c.VkVertexInputAttributeDescription,
        bindingDescriptions: []const c.VkVertexInputBindingDescription,
        descriptorSetLayouts: []const c.VkDescriptorSetLayout,
    ) !VulkanPipeline {
        var shaderStages = [2]c.VkPipelineShaderStageCreateInfo{ undefined, undefined };

        shaderStages[0] = c.VkPipelineShaderStageCreateInfo{};
        shaderStages[0].sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
        shaderStages[0].stage = c.VK_SHADER_STAGE_VERTEX_BIT;
        shaderStages[0].module = vertModule.handle;
        shaderStages[0].pName = "main";

        shaderStages[1] = c.VkPipelineShaderStageCreateInfo{};
        shaderStages[1].sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
        shaderStages[1].stage = c.VK_SHADER_STAGE_FRAGMENT_BIT;
        shaderStages[1].module = fragModule.handle;
        shaderStages[1].pName = "main";

        var vertexInputState = c.VkPipelineVertexInputStateCreateInfo{};
        vertexInputState.sType = c.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;
        vertexInputState.vertexBindingDescriptionCount = @intCast(bindingDescriptions.len);
        vertexInputState.pVertexBindingDescriptions = bindingDescriptions.ptr;
        vertexInputState.vertexAttributeDescriptionCount = @intCast(attributeDescriptions.len);
        vertexInputState.pVertexAttributeDescriptions = attributeDescriptions.ptr;

        var inputAssemblyState = c.VkPipelineInputAssemblyStateCreateInfo{};
        inputAssemblyState.sType = c.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO;
        inputAssemblyState.topology = c.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;

        var viewportState = c.VkPipelineViewportStateCreateInfo{};
        viewportState.sType = c.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
        viewportState.viewportCount = 1;
        // const viewport = c.VkViewport{
        //     .x = 0.0,
        //     .y = 0.0,
        //     .width = @floatFromInt(width),
        //     .height = @floatFromInt(height),
        // };
        // viewportState.pViewports = &viewport;
        viewportState.scissorCount = 1;
        // const scissor = c.VkRect2D{
        //     .offset = .{ .x = 0, .y = 0 },
        //     .extent = .{ .width = width, .height = height },
        // };
        // viewportState.pScissors = &scissor;

        var rasterizationState = c.VkPipelineRasterizationStateCreateInfo{};
        rasterizationState.sType = c.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO;
        rasterizationState.lineWidth = 1.0;

        var multisampleState = c.VkPipelineMultisampleStateCreateInfo{};
        multisampleState.sType = c.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO;
        multisampleState.rasterizationSamples = c.VK_SAMPLE_COUNT_1_BIT;

        var depthStencilState = c.VkPipelineDepthStencilStateCreateInfo{};
        depthStencilState.sType = c.VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO;
        depthStencilState.depthTestEnable = c.VK_TRUE;
        depthStencilState.depthWriteEnable = c.VK_TRUE;
        depthStencilState.depthCompareOp = c.VK_COMPARE_OP_LESS;
        depthStencilState.minDepthBounds = 0.0;
        depthStencilState.maxDepthBounds = 1.0;

        var colorBlendAttachment = c.VkPipelineColorBlendAttachmentState{};
        colorBlendAttachment.colorWriteMask = c.VK_COLOR_COMPONENT_R_BIT | c.VK_COLOR_COMPONENT_G_BIT | c.VK_COLOR_COMPONENT_B_BIT | c.VK_COLOR_COMPONENT_A_BIT;
        colorBlendAttachment.blendEnable = c.VK_TRUE;
        colorBlendAttachment.srcColorBlendFactor = c.VK_BLEND_FACTOR_SRC_ALPHA;
        colorBlendAttachment.dstColorBlendFactor = c.VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA;
        colorBlendAttachment.colorBlendOp = c.VK_BLEND_OP_ADD;
        colorBlendAttachment.srcAlphaBlendFactor = c.VK_BLEND_FACTOR_ONE;
        colorBlendAttachment.dstAlphaBlendFactor = c.VK_BLEND_FACTOR_ZERO;
        colorBlendAttachment.alphaBlendOp = c.VK_BLEND_OP_ADD;

        var colorBlendState = c.VkPipelineColorBlendStateCreateInfo{};
        colorBlendState.sType = c.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;
        colorBlendState.attachmentCount = 1;
        colorBlendState.pAttachments = &colorBlendAttachment;

        var dynamicState = c.VkPipelineDynamicStateCreateInfo{};
        dynamicState.sType = c.VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO;
        const dynamicStates = &[_]u32{ c.VK_DYNAMIC_STATE_VIEWPORT, c.VK_DYNAMIC_STATE_SCISSOR };
        dynamicState.dynamicStateCount = @intCast(dynamicStates.len);
        dynamicState.pDynamicStates = dynamicStates;

        var pipelineLayout: c.VkPipelineLayout = undefined;
        {
            var createInfo = c.VkPipelineLayoutCreateInfo{};
            createInfo.sType = c.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
            createInfo.setLayoutCount = @intCast(descriptorSetLayouts.len);
            createInfo.pSetLayouts = descriptorSetLayouts.ptr;

            switch (c.vkCreatePipelineLayout(context.device.handle, &createInfo, null, &pipelineLayout)) {
                c.VK_SUCCESS => {},
                else => {
                    std.debug.print("[Vulkan] Could not create Pipeline Layout\n", .{});
                    return error.CreatePipelineLayout;
                },
            }
        }

        var pipeline: c.VkPipeline = undefined;
        {
            var createInfo = c.VkGraphicsPipelineCreateInfo{};
            createInfo.sType = c.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;
            createInfo.stageCount = @intCast(shaderStages.len);
            createInfo.pStages = &shaderStages;
            createInfo.pVertexInputState = &vertexInputState;
            createInfo.pInputAssemblyState = &inputAssemblyState;
            createInfo.pViewportState = &viewportState;
            createInfo.pRasterizationState = &rasterizationState;
            createInfo.pMultisampleState = &multisampleState;
            createInfo.pDepthStencilState = &depthStencilState;
            createInfo.pColorBlendState = &colorBlendState;
            createInfo.pDynamicState = &dynamicState;
            createInfo.layout = pipelineLayout;
            createInfo.renderPass = renderPass.handle;
            createInfo.subpass = 0;

            switch (c.vkCreateGraphicsPipelines(context.device.handle, null, 1, &createInfo, null, &pipeline)) {
                c.VK_SUCCESS => {
                    return .{
                        .handle = pipeline,
                        .layout = pipelineLayout,
                    };
                },
                else => {
                    std.debug.print("[Vulkan] Could not create Pipeline\n", .{});
                    return error.CreatePipeline;
                },
            }
        }
    }

    pub fn destroy(self: *VulkanPipeline, context: *const VulkanContext) void {
        c.vkDestroyPipeline(context.device.handle, self.handle, null);
        c.vkDestroyPipelineLayout(context.device.handle, self.layout, null);
    }
};
