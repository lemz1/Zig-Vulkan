const std = @import("std");
const builtin = @import("builtin");
const base = @import("base.zig");
const vulkan = @import("../vulkan.zig");
const util = @import("../util.zig");
const core = @import("../core.zig");
const c = @cImport(@cInclude("vulkan/vulkan.h"));

const Allocator = std.mem.Allocator;
const VulkanInstance = vulkan.VulkanInstance;
const VulkanDevice = vulkan.VulkanDevice;
const GLFW = core.GLFW;
const vkCheck = base.vkCheck;

const enableValidationLayers = switch (builtin.mode) {
    .Debug, .ReleaseSafe => true,
    else => false,
};

pub const VulkanContextCreateOptions = struct {
    framesInFlight: u32 = 2,
};

pub const VulkanContext = struct {
    framesInFlight: u32,

    instance: VulkanInstance,
    device: VulkanDevice,

    pub fn create(options: VulkanContextCreateOptions, allocator: Allocator) !VulkanContext {
        const framesInFlight: u32 = if (options.framesInFlight >= 1) options.framesInFlight else 2;

        const validationLayers: []const [*:0]const u8 = &[_][*:0]const u8{
            "VK_LAYER_KHRONOS_validation",
        };

        var glfwInstanceExtensionsCount: u32 = 0;
        const glfwInstanceExtensions = GLFW.instanceExtensions(&glfwInstanceExtensionsCount);

        const additionalInstanceExtensions: []const [*:0]const u8 = &[_][*:0]const u8{
            c.VK_EXT_DEBUG_UTILS_EXTENSION_NAME,
            c.VK_EXT_VALIDATION_FEATURES_EXTENSION_NAME,
        };

        var instanceExtensions = try allocator.alloc([*:0]const u8, glfwInstanceExtensionsCount + additionalInstanceExtensions.len);
        defer allocator.free(instanceExtensions);
        for (0..glfwInstanceExtensionsCount) |i| {
            instanceExtensions[i] = glfwInstanceExtensions[i];
        }
        for (0..additionalInstanceExtensions.len) |i| {
            instanceExtensions[i + glfwInstanceExtensionsCount] = additionalInstanceExtensions[i];
        }

        const deviceExtensions: []const [*:0]const u8 = &[_][*:0]const u8{
            c.VK_KHR_SWAPCHAIN_EXTENSION_NAME,
        };

        const instance = try VulkanInstance.new(
            enableValidationLayers,
            @intCast(validationLayers.len),
            validationLayers.ptr,
            @intCast(instanceExtensions.len),
            instanceExtensions.ptr,
            allocator,
        );
        const device = try VulkanDevice.new(&instance, @intCast(deviceExtensions.len), deviceExtensions.ptr, allocator);

        return .{
            .framesInFlight = framesInFlight,

            .instance = instance,
            .device = device,
        };
    }

    pub fn destroy(self: *VulkanContext) void {
        self.device.wait();

        self.device.destroy();
        self.instance.destroy();
    }
};
