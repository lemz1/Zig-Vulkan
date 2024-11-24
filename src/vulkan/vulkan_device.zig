const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

const util = @import("util.zig");

const c = @cImport(@cInclude("vulkan/vulkan.h"));

const vkCheck = util.vkCheck;

const VulkanInstance = @import("vulkan_instance.zig").VulkanInstance;

const VulkanDeviceError = error{
    CreateDevice,
};

pub const VulkanDevice = struct {
    handle: c.VkDevice,

    pub fn new(instance: *const VulkanInstance, allocator: Allocator) !VulkanDevice {
        var deviceCount: u32 = 0;
        vkCheck(c.vkEnumeratePhysicalDevices(instance.handle, &deviceCount, null));
        const physicalDevices = try allocator.alloc(c.VkPhysicalDevice, deviceCount);
        defer allocator.free(physicalDevices);
        vkCheck(c.vkEnumeratePhysicalDevices(instance.handle, &deviceCount, physicalDevices.ptr));

        const physicalDevice = physicalDevices[0];

        const queuePriority: f32 = 1.0;

        var queueCreateInfo = c.VkDeviceQueueCreateInfo{};
        queueCreateInfo.sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
        queueCreateInfo.queueFamilyIndex = 0;
        queueCreateInfo.queueCount = 1;
        queueCreateInfo.pQueuePriorities = &queuePriority;

        var createInfo = c.VkDeviceCreateInfo{};
        createInfo.sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
        createInfo.queueCreateInfoCount = 1;
        createInfo.pQueueCreateInfos = &queueCreateInfo;

        var device: c.VkDevice = undefined;
        switch (c.vkCreateDevice(physicalDevice, &createInfo, null, &device)) {
            c.VK_SUCCESS => {
                return .{
                    .handle = device,
                };
            },
            else => {
                std.debug.print("[Vulkan] could not create device\n", .{});
                return VulkanDeviceError.CreateDevice;
            },
        }
    }

    pub fn destroy(self: *VulkanDevice) void {
        c.vkDestroyDevice(self.handle, null);
    }
};
