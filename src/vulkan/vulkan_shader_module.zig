const std = @import("std");
const base = @import("base.zig");
const vulkan = @import("../vulkan.zig");
const c = @cImport(@cInclude("vulkan/vulkan.h"));

const Allocator = std.mem.Allocator;
const VulkanDevice = vulkan.VulkanDevice;
const vkCheck = base.vkCheck;

const VulkanShaderModuleError = error{
    CreateShaderModule,
};

pub const VulkanShaderModule = struct {
    handle: c.VkShaderModule,

    pub fn new(device: *const VulkanDevice, filePath: []const u8, allocator: Allocator) !VulkanShaderModule {
        const file = try std.fs.cwd().openFile(filePath, .{ .mode = .read_only });
        defer file.close();

        const content = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
        defer allocator.free(content);

        var createInfo = c.VkShaderModuleCreateInfo{};
        createInfo.sType = c.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
        createInfo.codeSize = @sizeOf(u8) * content.len;
        createInfo.pCode = @ptrCast(@alignCast(content.ptr));

        var shaderModule: c.VkShaderModule = undefined;
        switch (c.vkCreateShaderModule(device.handle, &createInfo, null, &shaderModule)) {
            c.VK_SUCCESS => {
                return .{
                    .handle = shaderModule,
                };
            },
            else => {
                std.debug.print("[Vulkan] Could not create Shader Module\n", .{});
                return VulkanShaderModuleError.CreateShaderModule;
            },
        }
    }

    pub fn destroy(self: *VulkanShaderModule, device: *const VulkanDevice) void {
        c.vkDestroyShaderModule(device.handle, self.handle, null);
    }
};
