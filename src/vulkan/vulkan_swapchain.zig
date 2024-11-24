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
const VulkanSurface = vulkan.VulkanSurface;

const Window = core.Window;

const VulkanSwapchainError = error{
    CreateSwapchain,
};

pub const VulkanSwapchain = struct {
    handle: c.VkSwapchainKHR,
    images: []c.VkImage,
    allocator: Allocator,

    pub fn new(device: *const VulkanDevice, surface: *const VulkanSurface, usage: c.VkImageUsageFlags, allocator: Allocator) !VulkanSwapchain {
        var supportsPresent: c.VkBool32 = 0;
        vkCheck(c.vkGetPhysicalDeviceSurfaceSupportKHR(device.physicalDevice, device.graphicsQueue.familyIndex, surface.handle, &supportsPresent));

        var numFormats: u32 = 0;
        vkCheck(c.vkGetPhysicalDeviceSurfaceFormatsKHR(device.physicalDevice, surface.handle, &numFormats, null));
        const availableFormats = try allocator.alloc(c.VkSurfaceFormatKHR, numFormats);
        defer allocator.free(availableFormats);
        vkCheck(c.vkGetPhysicalDeviceSurfaceFormatsKHR(device.physicalDevice, surface.handle, &numFormats, availableFormats.ptr));

        const format = availableFormats[0].format;
        const colorSpace = availableFormats[0].colorSpace;

        var surfaceCapabilites = c.VkSurfaceCapabilitiesKHR{};
        vkCheck(c.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(device.physicalDevice, surface.handle, &surfaceCapabilites));

        if (surfaceCapabilites.currentExtent.width == 0xFFFFFFFF) {
            surfaceCapabilites.currentExtent.width = surfaceCapabilites.minImageExtent.width;
        }

        if (surfaceCapabilites.currentExtent.height == 0xFFFFFFFF) {
            surfaceCapabilites.currentExtent.height = surfaceCapabilites.minImageExtent.height;
        }

        var createInfo = c.VkSwapchainCreateInfoKHR{};
        createInfo.sType = c.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
        createInfo.surface = surface.handle;
        createInfo.minImageCount = 3;
        createInfo.imageFormat = format;
        createInfo.imageColorSpace = colorSpace;
        createInfo.imageExtent = surfaceCapabilites.currentExtent;
        createInfo.imageArrayLayers = 1;
        createInfo.imageUsage = usage;
        createInfo.imageSharingMode = c.VK_SHARING_MODE_EXCLUSIVE;
        createInfo.preTransform = c.VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR;
        createInfo.compositeAlpha = c.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
        createInfo.presentMode = c.VK_PRESENT_MODE_FIFO_KHR;

        var swapchain: c.VkSwapchainKHR = undefined;
        switch (c.vkCreateSwapchainKHR(device.handle, &createInfo, null, &swapchain)) {
            c.VK_SUCCESS => {},
            else => {
                std.debug.print("[Vulkan] could not create swapchain\n", .{});
                return VulkanSwapchainError.CreateSwapchain;
            },
        }

        var imageCount: u32 = 0;
        vkCheck(c.vkGetSwapchainImagesKHR(device.handle, swapchain, &imageCount, null));
        const images = try allocator.alloc(c.VkImage, imageCount);
        vkCheck(c.vkGetSwapchainImagesKHR(device.handle, swapchain, &imageCount, images.ptr));

        return .{
            .handle = swapchain,
            .images = images,
            .allocator = allocator,
        };
    }

    pub fn destroy(self: *VulkanSwapchain, device: *const VulkanDevice) void {
        self.allocator.free(self.images);
        c.vkDestroySwapchainKHR(device.handle, self.handle, null);
    }
};
