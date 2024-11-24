const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

const util = @import("util.zig");

const c = @cImport(@cInclude("vulkan/vulkan.h"));

const vkCheck = util.vkCheck;

const vulkan = @import("../vulkan.zig");

const VulkanInstance = vulkan.VulkanInstance;
const VulkanQueue = vulkan.VulkanQueue;

const VulkanDeviceError = error{
    CreateDevice,
};

pub const VulkanDevice = struct {
    handle: c.VkDevice,
    physicalDevice: c.VkPhysicalDevice,
    physicalDeviceProperties: c.VkPhysicalDeviceProperties,
    graphicsQueue: VulkanQueue,

    pub fn new(instance: *const VulkanInstance, deviceExtensionsCount: u32, deviceExtensions: [*c]const [*c]const u8, allocator: Allocator) !VulkanDevice {
        var deviceCount: u32 = 0;
        vkCheck(c.vkEnumeratePhysicalDevices(instance.handle, &deviceCount, null));
        const physicalDevices = try allocator.alloc(c.VkPhysicalDevice, deviceCount);
        defer allocator.free(physicalDevices);
        vkCheck(c.vkEnumeratePhysicalDevices(instance.handle, &deviceCount, physicalDevices.ptr));

        const physicalDevice = physicalDevices[0];

        var physicalDeviceProperties: c.VkPhysicalDeviceProperties = undefined;
        c.vkGetPhysicalDeviceProperties(physicalDevice, &physicalDeviceProperties);

        var enabledFeatures = c.VkPhysicalDeviceFeatures{};

        var numQueueFamilies: u32 = 0;
        c.vkGetPhysicalDeviceQueueFamilyProperties(physicalDevice, &numQueueFamilies, null);
        const queueFamilies = try allocator.alloc(c.VkQueueFamilyProperties, numQueueFamilies);
        defer allocator.free(queueFamilies);
        c.vkGetPhysicalDeviceQueueFamilyProperties(physicalDevice, &numQueueFamilies, queueFamilies.ptr);

        var graphicsQueue: VulkanQueue = undefined;

        for (0..numQueueFamilies) |i| {
            const queueFamily = &queueFamilies[i];
            if ((queueFamily.queueFlags & c.VK_QUEUE_GRAPHICS_BIT) != 0) {
                graphicsQueue.familyIndex = @intCast(i);
                break;
            }
        }

        const queuePriority: f32 = 1.0;

        var queueCreateInfo = c.VkDeviceQueueCreateInfo{};
        queueCreateInfo.sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
        queueCreateInfo.queueFamilyIndex = graphicsQueue.familyIndex;
        queueCreateInfo.queueCount = 1;
        queueCreateInfo.pQueuePriorities = &queuePriority;

        var createInfo = c.VkDeviceCreateInfo{};
        createInfo.sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
        createInfo.queueCreateInfoCount = 1;
        createInfo.pQueueCreateInfos = &queueCreateInfo;
        createInfo.enabledExtensionCount = deviceExtensionsCount;
        createInfo.ppEnabledExtensionNames = deviceExtensions;
        createInfo.pEnabledFeatures = &enabledFeatures;

        var device: c.VkDevice = undefined;
        switch (c.vkCreateDevice(physicalDevice, &createInfo, null, &device)) {
            c.VK_SUCCESS => {},
            else => {
                std.debug.print("[Vulkan] could not create device\n", .{});
                return VulkanDeviceError.CreateDevice;
            },
        }

        c.vkGetDeviceQueue(device, graphicsQueue.familyIndex, 0, &graphicsQueue.queue);

        return .{
            .handle = device,
            .physicalDevice = physicalDevice,
            .physicalDeviceProperties = physicalDeviceProperties,
            .graphicsQueue = graphicsQueue,
        };
    }

    pub fn destroy(self: *VulkanDevice) void {
        c.vkDestroyDevice(self.handle, null);
    }

    pub fn wait(self: *const VulkanDevice) void {
        vkCheck(c.vkDeviceWaitIdle(self.handle));
    }
};
