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
    framebuffers: []c.VkFramebuffer,
    renderPass: VulkanRenderPass,
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

        const framebuffers = try allocator.alloc(c.VkFramebuffer, swapchain.images.len);
        for (0..swapchain.images.len) |i| {
            var createInfo = c.VkFramebufferCreateInfo{};
            createInfo.sType = c.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO;
            createInfo.renderPass = renderPass.handle;
            createInfo.attachmentCount = 1;
            createInfo.pAttachments = &swapchain.imageViews[i];
            createInfo.width = swapchain.width;
            createInfo.height = swapchain.height;
            createInfo.layers = 1;
            vkCheck(c.vkCreateFramebuffer(device.handle, &createInfo, null, &framebuffers[i]));
        }

        return .{
            .instance = instance,
            .device = device,
            .surface = surface,
            .swapchain = swapchain,
            .framebuffers = framebuffers,
            .renderPass = renderPass,
            .allocator = allocator,
        };
    }

    pub fn destroy(self: *VulkanContext) void {
        self.device.wait();

        for (self.framebuffers) |framebuffer| {
            c.vkDestroyFramebuffer(self.device.handle, framebuffer, null);
        }

        self.renderPass.destroy(&self.device);
        self.swapchain.destroy(&self.device);
        self.surface.destroy(&self.instance);
        self.device.destroy();
        self.instance.destroy();

        self.allocator.free(self.framebuffers);
    }
};
