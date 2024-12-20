const std = @import("std");
const vulkan = @import("../vulkan.zig");
const c = @cImport(@cInclude("vulkan/vulkan.h"));

const VulkanContext = vulkan.VulkanContext;
const cStrcmp = @cImport(@cInclude("string.h")).strcmp;

const VulkanResult = enum(c.VkResult) {
    Success = c.VK_SUCCESS,
    NotReady = c.VK_NOT_READY,
    Timeout = c.VK_TIMEOUT,
    EventSet = c.VK_EVENT_SET,
    EventReset = c.VK_EVENT_RESET,
    Incomplete = c.VK_INCOMPLETE,
    ErrorOutOfHostMemory = c.VK_ERROR_OUT_OF_HOST_MEMORY,
    ErrorOutOfDeviceMemory = c.VK_ERROR_OUT_OF_DEVICE_MEMORY,
    ErrorInitializationFailed = c.VK_ERROR_INITIALIZATION_FAILED,
    ErrorDeviceLost = c.VK_ERROR_DEVICE_LOST,
    ErrorMemoryMapFailed = c.VK_ERROR_MEMORY_MAP_FAILED,
    ErrorLayerNotPresent = c.VK_ERROR_LAYER_NOT_PRESENT,
    ErrorExtensionNotPresent = c.VK_ERROR_EXTENSION_NOT_PRESENT,
    ErrorFeatureNotPresent = c.VK_ERROR_FEATURE_NOT_PRESENT,
    ErrorIncompatibleDriver = c.VK_ERROR_INCOMPATIBLE_DRIVER,
    ErrorTooManyObjects = c.VK_ERROR_TOO_MANY_OBJECTS,
    ErrorFormatNotSupported = c.VK_ERROR_FORMAT_NOT_SUPPORTED,
    ErrorFragmentedPool = c.VK_ERROR_FRAGMENTED_POOL,
    ErrorUnknown = c.VK_ERROR_UNKNOWN,
    ErrorOutOfPoolMemory = c.VK_ERROR_OUT_OF_POOL_MEMORY,
    ErrorInvalidExternalHandle = c.VK_ERROR_INVALID_EXTERNAL_HANDLE,
    ErrorFragmentation = c.VK_ERROR_FRAGMENTATION,
    ErrorInvalidOpaqueCaptureAddress = c.VK_ERROR_INVALID_OPAQUE_CAPTURE_ADDRESS,
    PipelineCompileRequired = c.VK_PIPELINE_COMPILE_REQUIRED,
    ErrorSurfaceLostKHR = c.VK_ERROR_SURFACE_LOST_KHR,
    ErrorNativeWindowInUseKHR = c.VK_ERROR_NATIVE_WINDOW_IN_USE_KHR,
    SuboptimalKHR = c.VK_SUBOPTIMAL_KHR,
    ErrorOutOfDateKHR = c.VK_ERROR_OUT_OF_DATE_KHR,
    ErrorIncompatibleDisplayKHR = c.VK_ERROR_INCOMPATIBLE_DISPLAY_KHR,
    ErrorValidationFailedEXT = c.VK_ERROR_VALIDATION_FAILED_EXT,
    ErrorInvalidShaderNV = c.VK_ERROR_INVALID_SHADER_NV,
    ErrorImageUsageNotSupportedKHR = c.VK_ERROR_IMAGE_USAGE_NOT_SUPPORTED_KHR,
    ErrorVideoPictureLayoutNotSupportedKHR = c.VK_ERROR_VIDEO_PICTURE_LAYOUT_NOT_SUPPORTED_KHR,
    ErrorVideoProfileOperationNotSupportedKHR = c.VK_ERROR_VIDEO_PROFILE_OPERATION_NOT_SUPPORTED_KHR,
    ErrorVideoProfileFormatNotSupportedKHR = c.VK_ERROR_VIDEO_PROFILE_FORMAT_NOT_SUPPORTED_KHR,
    ErrorVideoProfileCodecNotSupportedKHR = c.VK_ERROR_VIDEO_PROFILE_CODEC_NOT_SUPPORTED_KHR,
    ErrorVideoSTDVersionNotSupportedKHR = c.VK_ERROR_VIDEO_STD_VERSION_NOT_SUPPORTED_KHR,
    ErrorInvalidDRMFormatModifierPlaneLayoutEXT = c.VK_ERROR_INVALID_DRM_FORMAT_MODIFIER_PLANE_LAYOUT_EXT,
    ErrorNotPermittedKHR = c.VK_ERROR_NOT_PERMITTED_KHR,
    ErrorFullScreenExclusiveModeLostEXT = c.VK_ERROR_FULL_SCREEN_EXCLUSIVE_MODE_LOST_EXT,
    ThreadIdleKHR = c.VK_THREAD_IDLE_KHR,
    ThreadDoneKHR = c.VK_THREAD_DONE_KHR,
    OperationDeferredKHR = c.VK_OPERATION_DEFERRED_KHR,
    OperationNotDeferredKHR = c.VK_OPERATION_NOT_DEFERRED_KHR,
    ErrorCompressionExhaustedEXT = c.VK_ERROR_COMPRESSION_EXHAUSTED_EXT,
    ErrorIncompatibleShaderBinaryEXT = c.VK_ERROR_INCOMPATIBLE_SHADER_BINARY_EXT,
    // ErrorOutOfPoolMemoryKHR = c.VK_ERROR_OUT_OF_POOL_MEMORY_KHR,
    // ErrorInvalidExternalHandleKHR = c.VK_ERROR_INVALID_EXTERNAL_HANDLE_KHR,
    // ErrorFragmentationEXT = c.VK_ERROR_FRAGMENTATION_EXT,
    // ErrorNotPermittedEXT = c.VK_ERROR_NOT_PERMITTED_EXT,
    // ErrorInvalidDeviceAddressEXT = c.VK_ERROR_INVALID_DEVICE_ADDRESS_EXT,
    // ErrorInvalidOpaqueCaptureAddressKHR = c.VK_ERROR_INVALID_OPAQUE_CAPTURE_ADDRESS_KHR,
    // PipelineCompileRequiredEXT = c.VK_PIPELINE_COMPILE_REQUIRED_EXT,
    // ErrorPipelineCompileRequiredEXT = c.VK_ERROR_PIPELINE_COMPILE_REQUIRED_EXT,
    ResultMaxENUM = c.VK_RESULT_MAX_ENUM,
};

pub fn strcmp(str1: [*c]const u8, str2: [*c]const u8) bool {
    return cStrcmp(str1, str2) == 1;
}

pub fn vkCheck(res: c.VkResult) void {
    const result: VulkanResult = @enumFromInt(res);
    switch (result) {
        .Success => {},
        else => {
            std.debug.print("[Vulkan] Error: {s}\n", .{@tagName(result)});
        },
    }
}

pub fn findMemoryType(context: *const VulkanContext, typeFilter: u32, memoryProperties: c.VkMemoryPropertyFlags) !u32 {
    var deviceMemoryProperties: c.VkPhysicalDeviceMemoryProperties = undefined;
    c.vkGetPhysicalDeviceMemoryProperties(context.device.physicalDevice, &deviceMemoryProperties);

    for (0..deviceMemoryProperties.memoryTypeCount) |i| {
        if ((typeFilter & (@as(u32, 1) << @intCast(i))) != 0) {
            if ((deviceMemoryProperties.memoryTypes[i].propertyFlags & memoryProperties) == memoryProperties) {
                return @intCast(i);
            }
        }
    }

    return error.FindMemoryType;
}
