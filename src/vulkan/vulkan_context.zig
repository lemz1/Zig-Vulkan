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
const VulkanSemaphore = vulkan.VulkanSemaphore;
const VulkanCommandPool = vulkan.VulkanCommandPool;
const VulkanCommandBuffer = vulkan.VulkanCommandBuffer;

const c = @cImport(@cInclude("vulkan/vulkan.h"));

const vkCheck = util.vkCheck;

const enableValidationLayers = switch (builtin.mode) {
    .Debug, .ReleaseSafe => true,
    else => false,
};

pub const VulkanContext = struct {
    framesInFlight: u32,

    instance: VulkanInstance,
    device: VulkanDevice,
    surface: VulkanSurface,
    swapchain: VulkanSwapchain,
    framebuffers: []VulkanFramebuffer,
    renderPass: VulkanRenderPass,
    commandPools: []VulkanCommandPool,
    commandBuffers: []VulkanCommandBuffer,
    fences: []VulkanFence,
    acquireSemaphores: []VulkanSemaphore,
    releaseSemaphores: []VulkanSemaphore,
    allocator: Allocator,

    const CreateOptions = struct {
        framesInFlight: u32 = 2,
    };

    pub fn create(window: *const Window, options: CreateOptions, allocator: Allocator) !VulkanContext {
        const framesInFlight: u32 = if (options.framesInFlight >= 1) options.framesInFlight else 2;

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
        const swapchain = try VulkanSwapchain.new(&device, &surface, c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT, null, allocator);
        const renderPass = try VulkanRenderPass.new(&device, swapchain.format);

        const framebuffers = try allocator.alloc(VulkanFramebuffer, swapchain.images.len);
        for (0..swapchain.images.len) |i| {
            framebuffers[i] = try VulkanFramebuffer.new(&device, &renderPass, 1, &swapchain.imageViews[i], swapchain.width, swapchain.height);
        }

        const commandPools = try allocator.alloc(VulkanCommandPool, framesInFlight);
        const commandBuffers = try allocator.alloc(VulkanCommandBuffer, framesInFlight);

        const fences = try allocator.alloc(VulkanFence, framesInFlight);

        const acquireSemaphores = try allocator.alloc(VulkanSemaphore, framesInFlight);
        const releaseSemaphores = try allocator.alloc(VulkanSemaphore, framesInFlight);

        for (0..framesInFlight) |i| {
            commandPools[i] = try VulkanCommandPool.new(&device, device.graphicsQueue.familyIndex);
            commandBuffers[i] = try VulkanCommandBuffer.new(&device, &commandPools[i]);

            fences[i] = try VulkanFence.new(&device, true);

            acquireSemaphores[i] = try VulkanSemaphore.new(&device);
            releaseSemaphores[i] = try VulkanSemaphore.new(&device);
        }

        return .{
            .framesInFlight = framesInFlight,

            .instance = instance,
            .device = device,
            .surface = surface,
            .swapchain = swapchain,
            .framebuffers = framebuffers,
            .renderPass = renderPass,
            .commandPools = commandPools,
            .commandBuffers = commandBuffers,
            .fences = fences,
            .acquireSemaphores = acquireSemaphores,
            .releaseSemaphores = releaseSemaphores,
            .allocator = allocator,
        };
    }

    pub fn destroy(self: *VulkanContext) void {
        self.device.wait();

        for (0..self.framesInFlight) |i| {
            self.commandBuffers[i].destroy(&self.device, &self.commandPools[i]);
            self.commandPools[i].destroy(&self.device);

            self.releaseSemaphores[i].destroy(&self.device);
            self.acquireSemaphores[i].destroy(&self.device);

            self.fences[i].destroy(&self.device);
        }

        for (self.framebuffers) |*framebuffer| {
            framebuffer.destroy(&self.device);
        }

        self.renderPass.destroy(&self.device);
        self.swapchain.destroy(&self.device);
        self.surface.destroy(&self.instance);
        self.device.destroy();
        self.instance.destroy();

        self.allocator.free(self.releaseSemaphores);
        self.allocator.free(self.acquireSemaphores);
        self.allocator.free(self.fences);
        self.allocator.free(self.commandBuffers);
        self.allocator.free(self.commandPools);
        self.allocator.free(self.framebuffers);
    }

    pub fn recreateSwapchain(self: *VulkanContext) !void {
        var surfaceCapabilities: c.VkSurfaceCapabilitiesKHR = undefined;
        vkCheck(c.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(self.device.physicalDevice, self.surface.handle, &surfaceCapabilities));
        if (surfaceCapabilities.currentExtent.width == 0 or surfaceCapabilities.currentExtent.height == 0) {
            return;
        }

        self.device.wait();

        var oldSwapchain = self.swapchain;
        self.swapchain = try VulkanSwapchain.new(&self.device, &self.surface, c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT, &oldSwapchain, self.allocator);
        oldSwapchain.destroy(&self.device);

        self.renderPass.destroy(&self.device);
        self.renderPass = try VulkanRenderPass.new(&self.device, self.swapchain.format);

        for (self.framebuffers) |*framebuffer| {
            framebuffer.destroy(&self.device);
        }
        self.allocator.free(self.framebuffers);
        self.framebuffers = try self.allocator.alloc(VulkanFramebuffer, self.swapchain.images.len);

        for (0..self.framebuffers.len) |i| {
            self.framebuffers[i] = try VulkanFramebuffer.new(
                &self.device,
                &self.renderPass,
                1,
                &self.swapchain.imageViews[i],
                self.swapchain.width,
                self.swapchain.height,
            );
        }
    }
};
