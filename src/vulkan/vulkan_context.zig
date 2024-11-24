const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

const util = @import("util.zig");

const core = @import("../core.zig");
const vulkan = @import("../vulkan.zig");

const Window = core.Window;

const VulkanInstance = vulkan.VulkanInstance;
const VulkanDevice = vulkan.VulkanDevice;
const VulkanSurface = vulkan.VulkanSurface;

const c = @cImport({
    @cInclude("vulkan/vulkan.h");
    @cInclude("glfw/glfw3.h");
});

const vkCheck = util.vkCheck;

const enableValidationLayers = switch (builtin.mode) {
    .Debug, .ReleaseSafe => true,
    else => false,
};

pub const VulkanContext = struct {
    instance: VulkanInstance,
    device: VulkanDevice,
    surface: VulkanSurface,
    allocator: Allocator,

    pub fn create(window: *const Window, allocator: Allocator) !VulkanContext {
        const validationLayers: []const [*:0]const u8 = &[_][*:0]const u8{
            "VK_LAYER_KHRONOS_validation",
        };

        var instanceExtensionsCount: u32 = 0;
        const instanceExtensions = c.glfwGetRequiredInstanceExtensions(&instanceExtensionsCount);

        const instance = try VulkanInstance.new(enableValidationLayers, @intCast(validationLayers.len), validationLayers.ptr, instanceExtensionsCount, instanceExtensions, allocator);
        const device = try VulkanDevice.new(&instance, allocator);
        const surface = try VulkanSurface.new(&instance, window);

        return .{
            .instance = instance,
            .device = device,
            .surface = surface,
            .allocator = allocator,
        };
    }

    pub fn destroy(self: *VulkanContext) void {
        self.surface.destroy(&self.instance);
        self.device.destroy();
        self.instance.destroy();
    }
};
