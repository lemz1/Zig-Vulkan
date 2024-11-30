const std = @import("std");
const vulkan = @import("../vulkan.zig");
const c = @cImport(@cInclude("vulkan/vulkan.h"));

const VulkanDevice = vulkan.VulkanDevice;
const cStrcmp = @cImport(@cInclude("string.h")).strcmp;

const VulkanUtilError = error{
    FindMemoryType,
};

pub fn strcmp(str1: [*c]const u8, str2: [*c]const u8) bool {
    return cStrcmp(str1, str2) == 1;
}

pub fn vkCheck(res: c.VkResult) void {
    switch (res) {
        c.VK_SUCCESS => {},
        else => {
            std.debug.print("[Vulkan] Error: {}", .{res});
        },
    }
}

pub fn findMemoryType(device: *const VulkanDevice, typeFilter: u32, memoryProperties: c.VkMemoryPropertyFlags) !u32 {
    var deviceMemoryProperties: c.VkPhysicalDeviceMemoryProperties = undefined;
    c.vkGetPhysicalDeviceMemoryProperties(device.physicalDevice, &deviceMemoryProperties);

    for (0..deviceMemoryProperties.memoryTypeCount) |i| {
        if ((typeFilter & (@as(u32, 1) << @intCast(i))) != 0) {
            if ((deviceMemoryProperties.memoryTypes[i].propertyFlags & memoryProperties) == memoryProperties) {
                return @intCast(i);
            }
        }
    }

    return VulkanUtilError.FindMemoryType;
}

pub fn propertyArray(comptime FieldType: type, allocator: std.mem.Allocator, obj: anytype, comptime fieldName: []const u8) ![]FieldType {
    const array = try allocator.alloc(FieldType, obj.len);
    for (0..obj.len) |i| {
        array[i] = @field(obj[i], fieldName);
    }
    return array;
}
