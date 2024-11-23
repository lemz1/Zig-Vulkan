const c = @cImport(@cInclude("vulkan/vulkan.h"));
const util = @import("util.zig");
const std = @import("std");

const vkCheck = util.vkCheck;

const validationLayers = &[_][*:0]const u8{
    "VK_LAYER_KHRONOS_validation",
};

const instanceExtensions = &[_][*:0]const u8{
    c.VK_KHR_SURFACE_EXTENSION_NAME,
    c.VK_EXT_DEBUG_UTILS_EXTENSION_NAME,
};

const enableValidationLayers = true;

const VulkanError = error{
    CreateInstance,
};

pub const Context = struct {
    pub fn create() !@This() {
        _ = try createVkInstance();
        return Context{};
    }

    fn createVkInstance() !c.VkInstance {
        var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
        const allocator = gpa.allocator();
        defer _ = gpa.deinit();

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
            createInfo.enabledLayerCount = validationLayers.len;
            createInfo.ppEnabledLayerNames = validationLayers;
        } else {
            createInfo.enabledLayerCount = 0;
        }

        createInfo.enabledExtensionCount = instanceExtensions.len;
        createInfo.ppEnabledExtensionNames = instanceExtensions;

        var instance: c.VkInstance = undefined;
        switch (c.vkCreateInstance(&createInfo, null, &instance)) {
            c.VK_SUCCESS => {
                return instance;
            },
            else => {
                std.debug.print("could not create vk instance\n", .{});
                return VulkanError.CreateInstance;
            },
        }
    }
};
