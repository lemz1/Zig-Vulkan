const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

const util = @import("util.zig");

const c = @cImport(@cInclude("vulkan/vulkan.h"));

const vkCheck = util.vkCheck;

const VulkanInstanceError = error{
    CreateInstance,
};

pub const VulkanInstance = struct {
    handle: c.VkInstance,

    pub fn new(enableValidationLayers: bool, validationLayers: []const [*:0]const u8, instanceExtensions: []const [*:0]const u8, allocator: Allocator) !VulkanInstance {
        var appInfo = c.VkApplicationInfo{};
        appInfo.sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO;
        appInfo.pApplicationName = "Vulkan";
        appInfo.applicationVersion = c.VK_MAKE_VERSION(1, 0, 0);
        appInfo.pEngineName = "The Crazy Zig Engine";
        appInfo.engineVersion = c.VK_MAKE_VERSION(1, 0, 0);
        appInfo.apiVersion = c.VK_API_VERSION_1_3;

        var layerCount: u32 = 0;
        vkCheck(c.vkEnumerateInstanceLayerProperties(&layerCount, null));
        const availableLayers = try allocator.alloc(c.VkLayerProperties, layerCount);
        defer allocator.free(availableLayers);
        vkCheck(c.vkEnumerateInstanceLayerProperties(&layerCount, availableLayers.ptr));

        for (validationLayers) |layerName| {
            var found = false;
            for (availableLayers) |*layerProperties| {
                if (util.strcmp(layerName, &layerProperties.layerName)) {
                    found = true;
                    break;
                }
            }

            if (!found) {
                std.debug.print("could not find validation layer: {s}\n", .{layerName});
            }
        }

        var createInfo = c.VkInstanceCreateInfo{};
        createInfo.sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
        createInfo.pApplicationInfo = &appInfo;

        if (enableValidationLayers) {
            createInfo.enabledLayerCount = @intCast(validationLayers.len);
            createInfo.ppEnabledLayerNames = validationLayers.ptr;
        } else {
            createInfo.enabledLayerCount = 0;
        }

        createInfo.enabledExtensionCount = @intCast(instanceExtensions.len);
        createInfo.ppEnabledExtensionNames = instanceExtensions.ptr;

        var instance: c.VkInstance = undefined;
        switch (c.vkCreateInstance(&createInfo, null, &instance)) {
            c.VK_SUCCESS => {
                return .{
                    .handle = instance,
                };
            },
            else => {
                std.debug.print("[Vulkan] could not create vulkan instance\n", .{});
                return VulkanInstanceError.CreateInstance;
            },
        }
    }

    pub fn destroy(self: *VulkanInstance) void {
        c.vkDestroyInstance(self.handle, null);
    }
};
