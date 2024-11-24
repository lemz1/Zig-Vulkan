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

const Window = core.Window;

const VulkanSwapchainError = error{
    CreateSwapchain,
};

pub const VulkanSwapchain = struct {
    handle: c.VkSwapchainKHR,

    // pub fn new(device: *const VulkanDevice) !VulkanSwapchain {
    //     var swapchain: c.VkSwapchainKHR = undefined;
    //     switch (c.vkCreateSwapchainKHR(device.handle, &createInfo, null, &swapchain)) {
    //         c.VK_SUCCESS => {
    //             return .{
    //                 .handle = swapchain,
    //             };
    //         },
    //         else => {
    //             std.debug.print("[Vulkan] could not create swapchain\n", .{});
    //             return VulkanSwapchainError.CreateSwapchain;
    //         },
    //     }
    // }
};
