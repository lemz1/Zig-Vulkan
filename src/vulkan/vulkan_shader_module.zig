const std = @import("std");
const vulkan = @import("../vulkan.zig");
const c = @cImport(@cInclude("vulkan/vulkan.h"));

const Allocator = std.mem.Allocator;
const VulkanContext = vulkan.VulkanContext;
const vkCheck = vulkan.vkCheck;

pub const VulkanShaderModule = struct {
    handle: c.VkShaderModule,

    pub fn new(context: *const VulkanContext, size: usize, spirv: [*c]const u32) !VulkanShaderModule {
        var createInfo = c.VkShaderModuleCreateInfo{};
        createInfo.sType = c.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
        createInfo.codeSize = size;
        createInfo.pCode = spirv;

        var shaderModule: c.VkShaderModule = undefined;
        switch (c.vkCreateShaderModule(context.device.handle, &createInfo, null, &shaderModule)) {
            c.VK_SUCCESS => {
                return .{
                    .handle = shaderModule,
                };
            },
            else => {
                std.debug.print("[Vulkan] Could not create Shader Module\n", .{});
                return error.CreateShaderModule;
            },
        }
    }

    pub fn destroy(self: *VulkanShaderModule, context: *const VulkanContext) void {
        c.vkDestroyShaderModule(context.device.handle, self.handle, null);
    }
};
