const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

const util = @import("util.zig");

const VulkanInstance = @import("vulkan_instance.zig").VulkanInstance;
const VulkanDevice = @import("vulkan_device.zig").VulkanDevice;

const c = @cImport(@cInclude("vulkan/vulkan.h"));

const vkCheck = util.vkCheck;

const validationLayers: []const [*:0]const u8 = &[_][*:0]const u8{
    "VK_LAYER_KHRONOS_validation",
};

const instanceExtensions: []const [*:0]const u8 = &[_][*:0]const u8{
    c.VK_KHR_SURFACE_EXTENSION_NAME,
    c.VK_EXT_DEBUG_UTILS_EXTENSION_NAME,
};

const enableValidationLayers = switch (builtin.mode) {
    .Debug, .ReleaseSafe => true,
    else => false,
};

pub const VulkanContext = struct {
    instance: VulkanInstance,
    device: VulkanDevice,
    allocator: Allocator,

    pub fn create(allocator: Allocator) !VulkanContext {
        const instance = try VulkanInstance.new(enableValidationLayers, validationLayers, instanceExtensions, allocator);
        const device = try VulkanDevice.new(&instance, allocator);

        return .{
            .instance = instance,
            .device = device,
            .allocator = allocator,
        };
    }

    pub fn destroy(self: *VulkanContext) void {
        self.device.destroy();
        self.instance.destroy();
    }
};
