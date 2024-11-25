const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

const util = @import("util.zig");

const core = @import("../core.zig");
const vulkan = @import("../vulkan.zig");

const Window = core.Window;
const GLFW = core.GLFW;

const VulkanInstance = vulkan.VulkanInstance;
const VulkanDevice = vulkan.VulkanDevice;
const VulkanSurface = vulkan.VulkanSurface;
const VulkanSwapchain = vulkan.VulkanSwapchain;
const VulkanRenderPass = vulkan.VulkanRenderPass;
const VulkanFramebuffer = vulkan.VulkanFramebuffer;
const VulkanFence = vulkan.VulkanFence;
const VulkanCommandPool = vulkan.VulkanCommandPool;
const VulkanCommandBuffer = vulkan.VulkanCommandBuffer;

const c = @cImport(@cInclude("vulkan/vulkan.h"));

const vkCheck = util.vkCheck;

const enableValidationLayers = switch (builtin.mode) {
    .Debug, .ReleaseSafe => true,
    else => false,
};

pub const VulkanContext = struct {
    instance: VulkanInstance,
    device: VulkanDevice,
    surface: VulkanSurface,
    swapchain: VulkanSwapchain,
    framebuffers: []VulkanFramebuffer,
    renderPass: VulkanRenderPass,
    commandPool: VulkanCommandPool,
    commandBuffer: VulkanCommandBuffer,
    fence: VulkanFence,
    allocator: Allocator,

    pub fn create(window: *const Window, allocator: Allocator) !VulkanContext {
        const validationLayers: []const [*:0]const u8 = &[_][*:0]const u8{
            "VK_LAYER_KHRONOS_validation",
        };

        var instanceExtensionsCount: u32 = 0;
        const instanceExtensions = GLFW.instanceExtensions(&instanceExtensionsCount);

        const deviceExtensions: []const [*:0]const u8 = &[_][*:0]const u8{
            c.VK_KHR_SWAPCHAIN_EXTENSION_NAME,
        };

        const instance = try VulkanInstance.new(enableValidationLayers, @intCast(validationLayers.len), validationLayers.ptr, instanceExtensionsCount, instanceExtensions, allocator);
        const device = try VulkanDevice.new(&instance, @intCast(deviceExtensions.len), deviceExtensions.ptr, allocator);
        const surface = try VulkanSurface.new(&instance, window);
        const swapchain = try VulkanSwapchain.new(&device, &surface, c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT, allocator);
        const renderPass = try VulkanRenderPass.new(&device, swapchain.format);

        const framebuffers = try allocator.alloc(VulkanFramebuffer, swapchain.images.len);
        for (0..swapchain.images.len) |i| {
            framebuffers[i] = try VulkanFramebuffer.new(&device, &renderPass, 1, &swapchain.imageViews[i], swapchain.width, swapchain.height);
        }

        const commandPool = try VulkanCommandPool.new(&device, device.graphicsQueue.familyIndex);

        const commandBuffer = try VulkanCommandBuffer.new(&device, &commandPool);

        const fence = try VulkanFence.new(&device);

        return .{
            .instance = instance,
            .device = device,
            .surface = surface,
            .swapchain = swapchain,
            .framebuffers = framebuffers,
            .renderPass = renderPass,
            .commandPool = commandPool,
            .commandBuffer = commandBuffer,
            .fence = fence,
            .allocator = allocator,
        };
    }

    pub fn destroy(self: *VulkanContext) void {
        self.device.wait();

        self.fence.destroy(&self.device);

        self.commandBuffer.destroy(&self.device, &self.commandPool);
        self.commandPool.destroy(&self.device);

        for (self.framebuffers) |*framebuffer| {
            framebuffer.destroy(&self.device);
        }

        self.renderPass.destroy(&self.device);
        self.swapchain.destroy(&self.device);
        self.surface.destroy(&self.instance);
        self.device.destroy();
        self.instance.destroy();

        self.allocator.free(self.framebuffers);
    }
};
