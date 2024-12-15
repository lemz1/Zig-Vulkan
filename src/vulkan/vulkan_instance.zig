const std = @import("std");
const base = @import("base.zig");
const vulkan = @import("../vulkan.zig");
const c = @cImport(@cInclude("vulkan/vulkan.h"));

const Allocator = std.mem.Allocator;
const VulkanDevice = vulkan.VulkanDevice;
const vkCheck = base.vkCheck;

pub const VulkanInstance = struct {
    handle: c.VkInstance,
    debugCallback: c.VkDebugUtilsMessengerEXT,

    pub fn new(enableValidationLayers: bool, validationLayersCount: u32, validationLayers: [*c]const [*c]const u8, instanceExtensionsCount: u32, instanceExtensions: [*c]const [*c]const u8, allocator: Allocator) !VulkanInstance {
        var instance: c.VkInstance = undefined;
        {
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

            for (0..validationLayersCount) |i| {
                var found = false;
                for (availableLayers) |*layerProperties| {
                    if (base.strcmp(validationLayers[i], &layerProperties.layerName)) {
                        found = true;
                        break;
                    }
                }

                if (!found) {
                    std.debug.print("Could not find Validation Layer: {s}\n", .{validationLayers[i]});
                }
            }

            const enableValidationFeatures = &[_]c.VkValidationFeatureEnableEXT{
                // c.VK_VALIDATION_FEATURE_ENABLE_BEST_PRACTICES_EXT,
                c.VK_VALIDATION_FEATURE_ENABLE_GPU_ASSISTED_EXT,
                c.VK_VALIDATION_FEATURE_ENABLE_SYNCHRONIZATION_VALIDATION_EXT,
            };
            var validationFeatures = c.VkValidationFeaturesEXT{};
            validationFeatures.sType = c.VK_STRUCTURE_TYPE_VALIDATION_FEATURES_EXT;
            validationFeatures.enabledValidationFeatureCount = enableValidationFeatures.len;
            validationFeatures.pEnabledValidationFeatures = enableValidationFeatures;

            var createInfo = c.VkInstanceCreateInfo{};
            createInfo.pNext = &validationFeatures;
            createInfo.sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
            createInfo.pApplicationInfo = &appInfo;

            if (enableValidationLayers) {
                createInfo.enabledLayerCount = validationLayersCount;
                createInfo.ppEnabledLayerNames = validationLayers;
            } else {
                createInfo.enabledLayerCount = 0;
            }

            createInfo.enabledExtensionCount = instanceExtensionsCount;
            createInfo.ppEnabledExtensionNames = instanceExtensions;

            switch (c.vkCreateInstance(&createInfo, null, &instance)) {
                c.VK_SUCCESS => {},
                else => {
                    std.debug.print("[Vulkan] Could not create Instance\n", .{});
                    return error.CreateInstance;
                },
            }
        }

        var debugCallback: c.VkDebugUtilsMessengerEXT = undefined;
        {
            const pfnCreateDebugUtilsMessengerEXT: c.PFN_vkCreateDebugUtilsMessengerEXT = @ptrCast(c.vkGetInstanceProcAddr(instance, "vkCreateDebugUtilsMessengerEXT"));

            var createInfo = c.VkDebugUtilsMessengerCreateInfoEXT{};
            createInfo.sType = c.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT;
            createInfo.messageSeverity = c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT | c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT;
            createInfo.messageType = c.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT | c.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT | c.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT;
            createInfo.pfnUserCallback = reportDebugCallback;
            switch (pfnCreateDebugUtilsMessengerEXT.?(instance, &createInfo, null, &debugCallback)) {
                c.VK_SUCCESS => {},
                else => {
                    std.debug.print("[Vulkan] Could not create Debug Callback\n", .{});
                    return error.CreateDebugCallback;
                },
            }
        }

        return .{
            .handle = instance,
            .debugCallback = debugCallback,
        };
    }

    pub fn destroy(self: *VulkanInstance) void {
        const pfnDestroyDebugUtilsMessengerEXT: c.PFN_vkDestroyDebugUtilsMessengerEXT = @ptrCast(c.vkGetInstanceProcAddr(self.handle, "vkDestroyDebugUtilsMessengerEXT"));

        pfnDestroyDebugUtilsMessengerEXT.?(self.handle, self.debugCallback, null);
        c.vkDestroyInstance(self.handle, null);
    }

    // expected type '*const fn (c_uint, u32, [*c]const cimport.struct_VkDebugUtilsMessengerCallbackDataEXT, ?*anyopaque) callconv(.C) u32'
    // found '*const fn (c_uint, c_uint, [*c]const cimport.struct_VkDebugUtilsMessengerCallbackDataEXT, ?*anyopaque) u32'
    fn reportDebugCallback(
        severity: c.VkDebugUtilsMessageSeverityFlagBitsEXT,
        _: c.VkDebugUtilsMessageTypeFlagBitsEXT,
        callbackData: [*c]const c.VkDebugUtilsMessengerCallbackDataEXT,
        _: ?*anyopaque,
    ) callconv(.C) c.VkBool32 {
        if ((severity & c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT) != 0) {
            std.debug.print("[Vulkan] Error: {s}\n", .{callbackData.*.pMessage});
        } else {
            std.debug.print("[Vulkan] Warn: {s}\n", .{callbackData.*.pMessage});
        }
        return c.VK_FALSE;
    }
};
