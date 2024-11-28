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
    NoGPUsFound,
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

        if (physicalDevices.len == 0) {
            return VulkanDeviceError.NoGPUsFound;
        }

        std.debug.print("Found {d} GPU{s}\n", .{ physicalDevices.len, if (physicalDevices.len > 1) "s" else "" });

        var physicalDevice: c.VkPhysicalDevice = undefined;
        var physicalDeviceProperties: c.VkPhysicalDeviceProperties = undefined;

        for (0..physicalDevices.len) |i| {
            var properties: c.VkPhysicalDeviceProperties = undefined;
            c.vkGetPhysicalDeviceProperties(physicalDevices[i], &properties);

            if (i == 0) {
                physicalDevice = physicalDevices[i];
                physicalDeviceProperties = properties;
            }

            const deviceNameLength = std.mem.len(@as([*c]const u8, &properties.deviceName));
            std.debug.print("  GPU {d}: {s}\n", .{
                i,
                properties.deviceName[0..deviceNameLength],
            });
        }

        const deviceNameLength = std.mem.len(@as([*c]const u8, &physicalDeviceProperties.deviceName));
        std.debug.print("Selected GPU: {s}\n", .{physicalDeviceProperties.deviceName[0..deviceNameLength]});

        {
            var properties: c.VkPhysicalDeviceMemoryProperties = undefined;
            c.vkGetPhysicalDeviceMemoryProperties(physicalDevice, &properties);

            std.debug.print("  Found {d} Memory Heap{s}\n", .{ properties.memoryHeapCount, if (properties.memoryHeapCount > 1) "s" else "" });

            for (0..properties.memoryHeapCount) |i| {
                const size: f32 = @as(f32, @floatFromInt(properties.memoryHeaps[i].size)) / 1000.0 / 1000.0;
                const isDeviceLocal = (properties.memoryHeaps[i].flags & c.VK_MEMORY_HEAP_DEVICE_LOCAL_BIT) != 0;
                std.debug.print("  Heap {d}:\n", .{i});
                std.debug.print("    Size: {d:.2} Mb\n", .{size});
                std.debug.print("    Device Local: {}\n", .{isDeviceLocal});
            }
        }

        var enabledFeatures = c.VkPhysicalDeviceFeatures{};

        var numQueueFamilies: u32 = 0;
        c.vkGetPhysicalDeviceQueueFamilyProperties(physicalDevice, &numQueueFamilies, null);
        const queueFamilies = try allocator.alloc(c.VkQueueFamilyProperties, numQueueFamilies);
        defer allocator.free(queueFamilies);
        c.vkGetPhysicalDeviceQueueFamilyProperties(physicalDevice, &numQueueFamilies, queueFamilies.ptr);

        var graphicsFamilyIndex: u32 = 0;
        for (0..numQueueFamilies) |i| {
            const queueFamily = &queueFamilies[i];
            if ((queueFamily.queueFlags & c.VK_QUEUE_GRAPHICS_BIT) != 0) {
                graphicsFamilyIndex = @intCast(i);
                break;
            }
        }

        const queuePriority: f32 = 1.0;

        var queueCreateInfo = c.VkDeviceQueueCreateInfo{};
        queueCreateInfo.sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
        queueCreateInfo.queueFamilyIndex = graphicsFamilyIndex;
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

        var graphicsQueue: c.VkQueue = undefined;
        c.vkGetDeviceQueue(device, graphicsFamilyIndex, 0, &graphicsQueue);

        return .{
            .handle = device,
            .physicalDevice = physicalDevice,
            .physicalDeviceProperties = physicalDeviceProperties,
            .graphicsQueue = VulkanQueue.new(graphicsQueue, graphicsFamilyIndex),
        };
    }

    pub fn destroy(self: *VulkanDevice) void {
        c.vkDestroyDevice(self.handle, null);
    }

    pub fn wait(self: *const VulkanDevice) void {
        vkCheck(c.vkDeviceWaitIdle(self.handle));
    }
};
