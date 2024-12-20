const std = @import("std");

const vulkan = @import("../vulkan.zig");
const c = @cImport(@cInclude("vulkan/vulkan.h"));

const Allocator = std.mem.Allocator;
const VulkanInstance = vulkan.VulkanInstance;
const VulkanQueue = vulkan.VulkanQueue;
const vkCheck = vulkan.vkCheck;

pub const VulkanDevice = struct {
    handle: c.VkDevice,
    physicalDevice: c.VkPhysicalDevice,
    physicalDeviceProperties: c.VkPhysicalDeviceProperties,
    graphicsQueue: VulkanQueue,

    hasResizableBAR: bool,

    pub fn new(
        instance: *const VulkanInstance,
        deviceExtensionsCount: u32,
        deviceExtensions: [*c]const [*c]const u8,
        allocator: Allocator,
    ) !VulkanDevice {
        var deviceCount: u32 = 0;
        vkCheck(c.vkEnumeratePhysicalDevices(instance.handle, &deviceCount, null));
        const physicalDevices = try allocator.alloc(c.VkPhysicalDevice, deviceCount);
        defer allocator.free(physicalDevices);
        vkCheck(c.vkEnumeratePhysicalDevices(instance.handle, &deviceCount, physicalDevices.ptr));

        if (physicalDevices.len == 0) {
            return error.NoGPUsFound;
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

        var memoryProperties: c.VkPhysicalDeviceMemoryProperties = undefined;
        c.vkGetPhysicalDeviceMemoryProperties(physicalDevice, &memoryProperties);

        const hasResizableBAR = memoryProperties.memoryHeapCount < 3;

        std.debug.print("  {s} Resizable BAR\n", .{if (hasResizableBAR) "Has" else "Doesn't have"});

        std.debug.print("  Found {d} Memory Heap{s}\n", .{ memoryProperties.memoryHeapCount, if (memoryProperties.memoryHeapCount > 1) "s" else "" });

        for (0..memoryProperties.memoryHeapCount) |i| {
            const size: f32 = @as(f32, @floatFromInt(memoryProperties.memoryHeaps[i].size)) / 1000.0 / 1000.0;
            const isDeviceLocal = (memoryProperties.memoryHeaps[i].flags & c.VK_MEMORY_HEAP_DEVICE_LOCAL_BIT) != 0;
            std.debug.print("  Heap {d}:\n", .{i});
            std.debug.print("    Size: {d:.2} Mb\n", .{size});
            std.debug.print("    Device Local: {}\n", .{isDeviceLocal});
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
                std.debug.print("[Vulkan] Could not Create Device\n", .{});
                return error.CreateDevice;
            },
        }

        var graphicsQueue: c.VkQueue = undefined;
        c.vkGetDeviceQueue(device, graphicsFamilyIndex, 0, &graphicsQueue);

        return .{
            .handle = device,
            .physicalDevice = physicalDevice,
            .physicalDeviceProperties = physicalDeviceProperties,
            .graphicsQueue = VulkanQueue.new(graphicsQueue, graphicsFamilyIndex),

            .hasResizableBAR = hasResizableBAR,
        };
    }

    pub fn destroy(self: *VulkanDevice) void {
        c.vkDestroyDevice(self.handle, null);
    }

    pub fn wait(self: *const VulkanDevice) void {
        vkCheck(c.vkDeviceWaitIdle(self.handle));
    }
};
