const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

const util = @import("util.zig");

const c = @cImport(@cInclude("vulkan/vulkan.h"));

const vkCheck = util.vkCheck;

const core = @import("../core.zig");
const vulkan = @import("../vulkan.zig");

const VulkanInstance = vulkan.VulkanInstance;
const VulkanDevice = vulkan.VulkanDevice;
const VulkanRenderPass = vulkan.VulkanRenderPass;
const VulkanShaderModule = vulkan.VulkanShaderModule;

const Window = core.Window;

const VulkanPipelineError = error{
    CreatePipeline,
    CreatePipelineLayout,
};

pub const VulkanPipeline = struct {
    handle: c.VkPipeline,
    layout: c.VkPipelineLayout,

    pub fn new(
        device: *const VulkanDevice,
        vertPath: []const u8,
        fragPath: []const u8,
        renderPass: *const VulkanRenderPass,
        allocator: Allocator,
    ) !VulkanPipeline {
        var vertModule = try VulkanShaderModule.new(device, vertPath, allocator);
        defer vertModule.destroy(device);

        var fragModule = try VulkanShaderModule.new(device, fragPath, allocator);
        defer fragModule.destroy(device);

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

        var colorBlendAttachment = c.VkPipelineColorBlendAttachmentState{};
        colorBlendAttachment.colorWriteMask = c.VK_COLOR_COMPONENT_R_BIT | c.VK_COLOR_COMPONENT_G_BIT | c.VK_COLOR_COMPONENT_B_BIT | c.VK_COLOR_COMPONENT_A_BIT;
        colorBlendAttachment.blendEnable = c.VK_FALSE;

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

            switch (c.vkCreatePipelineLayout(device.handle, &createInfo, null, &pipelineLayout)) {
                c.VK_SUCCESS => {},
                else => {
                    std.debug.print("[Vulkan] could not create pipeline layout\n", .{});
                    return VulkanPipelineError.CreatePipelineLayout;
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
            createInfo.pColorBlendState = &colorBlendState;
            createInfo.pDynamicState = &dynamicState;
            createInfo.layout = pipelineLayout;
            createInfo.renderPass = renderPass.handle;
            createInfo.subpass = 0;

            switch (c.vkCreateGraphicsPipelines(device.handle, null, 1, &createInfo, null, &pipeline)) {
                c.VK_SUCCESS => {
                    return .{
                        .handle = pipeline,
                        .layout = pipelineLayout,
                    };
                },
                else => {
                    std.debug.print("[Vulkan] could not create pipeline\n", .{});
                    return VulkanPipelineError.CreatePipeline;
                },
            }
        }
    }

    pub fn destroy(self: *VulkanPipeline, device: *const VulkanDevice) void {
        c.vkDestroyPipeline(device.handle, self.handle, null);
        c.vkDestroyPipelineLayout(device.handle, self.layout, null);
    }
};
