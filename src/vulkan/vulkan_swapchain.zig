const std = @import("std");
const base = @import("base.zig");
const vulkan = @import("../vulkan.zig");
const c = @cImport(@cInclude("vulkan/vulkan.h"));

const Allocator = std.mem.Allocator;
const VulkanContext = vulkan.VulkanContext;
const VulkanSurface = vulkan.VulkanSurface;
const VulkanFence = vulkan.VulkanFence;
const VulkanSemaphore = vulkan.VulkanSemaphore;
const vkCheck = base.vkCheck;

const VulkanSwapchainError = error{
    CreateSwapchain,
};

pub const VulkanSwapchain = struct {
    handle: c.VkSwapchainKHR,
    width: u32,
    height: u32,
    images: []c.VkImage,
    imageViews: []c.VkImageView,
    format: c.VkFormat,
    colorSpace: c.VkColorSpaceKHR,
    allocator: Allocator,

    pub fn new(
        context: *const VulkanContext,
        surface: *const VulkanSurface,
        usage: c.VkImageUsageFlags,
        oldSwapchain: ?*const VulkanSwapchain,
        allocator: Allocator,
    ) !VulkanSwapchain {
        var supportsPresent: c.VkBool32 = 0;
        vkCheck(c.vkGetPhysicalDeviceSurfaceSupportKHR(context.device.physicalDevice, context.device.graphicsQueue.familyIndex, surface.handle, &supportsPresent));

        var numFormats: u32 = 0;
        vkCheck(c.vkGetPhysicalDeviceSurfaceFormatsKHR(context.device.physicalDevice, surface.handle, &numFormats, null));
        const availableFormats = try allocator.alloc(c.VkSurfaceFormatKHR, numFormats);
        defer allocator.free(availableFormats);
        vkCheck(c.vkGetPhysicalDeviceSurfaceFormatsKHR(context.device.physicalDevice, surface.handle, &numFormats, availableFormats.ptr));

        const format = availableFormats[0].format;
        const colorSpace = availableFormats[0].colorSpace;

        var surfaceCapabilities = c.VkSurfaceCapabilitiesKHR{};
        vkCheck(c.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(context.device.physicalDevice, surface.handle, &surfaceCapabilities));

        if (surfaceCapabilities.currentExtent.width == 0xFFFFFFFF) {
            surfaceCapabilities.currentExtent.width = surfaceCapabilities.minImageExtent.width;
        }

        if (surfaceCapabilities.currentExtent.height == 0xFFFFFFFF) {
            surfaceCapabilities.currentExtent.height = surfaceCapabilities.minImageExtent.height;
        }

        var createInfo = c.VkSwapchainCreateInfoKHR{};
        createInfo.sType = c.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
        createInfo.surface = surface.handle;
        createInfo.minImageCount = 3;
        createInfo.imageFormat = format;
        createInfo.imageColorSpace = colorSpace;
        createInfo.imageExtent = surfaceCapabilities.currentExtent;
        createInfo.imageArrayLayers = 1;
        createInfo.imageUsage = usage;
        createInfo.imageSharingMode = c.VK_SHARING_MODE_EXCLUSIVE;
        createInfo.preTransform = c.VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR;
        createInfo.compositeAlpha = c.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
        createInfo.presentMode = c.VK_PRESENT_MODE_FIFO_KHR;

        const oldSwapchainHandle: c.VkSwapchainKHR = if (oldSwapchain) |v| v.handle else null;
        createInfo.oldSwapchain = oldSwapchainHandle;

        var swapchain: c.VkSwapchainKHR = undefined;
        switch (c.vkCreateSwapchainKHR(context.device.handle, &createInfo, null, &swapchain)) {
            c.VK_SUCCESS => {},
            else => {
                std.debug.print("[Vulkan] Could not create Swapchain\n", .{});
                return VulkanSwapchainError.CreateSwapchain;
            },
        }

        var imageCount: u32 = 0;
        vkCheck(c.vkGetSwapchainImagesKHR(context.device.handle, swapchain, &imageCount, null));
        const images = try allocator.alloc(c.VkImage, imageCount);
        vkCheck(c.vkGetSwapchainImagesKHR(context.device.handle, swapchain, &imageCount, images.ptr));

        const imageViews = try allocator.alloc(c.VkImageView, imageCount);
        for (0..imageCount) |i| {
            var imageViewCreateInfo = c.VkImageViewCreateInfo{};
            imageViewCreateInfo.sType = c.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
            imageViewCreateInfo.image = images[i];
            imageViewCreateInfo.viewType = c.VK_IMAGE_VIEW_TYPE_2D;
            imageViewCreateInfo.format = format;
            imageViewCreateInfo.subresourceRange = .{
                .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
                .baseMipLevel = 0,
                .levelCount = 1,
                .baseArrayLayer = 0,
                .layerCount = 1,
            };
            vkCheck(c.vkCreateImageView(context.device.handle, &imageViewCreateInfo, null, &imageViews[i]));
        }

        return .{
            .handle = swapchain,
            .width = surfaceCapabilities.currentExtent.width,
            .height = surfaceCapabilities.currentExtent.height,
            .images = images,
            .imageViews = imageViews,
            .format = format,
            .colorSpace = colorSpace,
            .allocator = allocator,
        };
    }

    pub fn destroy(self: *VulkanSwapchain, context: *const VulkanContext) void {
        for (self.imageViews) |imageView| {
            c.vkDestroyImageView(context.device.handle, imageView, null);
        }
        c.vkDestroySwapchainKHR(context.device.handle, self.handle, null);

        self.allocator.free(self.imageViews);
        self.allocator.free(self.images);
    }

    pub fn acquireNextImage(
        self: *const VulkanSwapchain,
        context: *const VulkanContext,
        semaphore: ?*const VulkanSemaphore,
        fence: ?*const VulkanFence,
        imageIndex: *u32,
    ) c.VkResult {
        const semaphoreHandle: c.VkSemaphore = if (semaphore) |v| v.handle else null;
        const fenceHandle: c.VkFence = if (fence) |v| v.handle else null;

        return c.vkAcquireNextImageKHR(
            context.device.handle,
            self.handle,
            std.math.maxInt(u64),
            semaphoreHandle,
            fenceHandle,
            imageIndex,
        );
    }
};
