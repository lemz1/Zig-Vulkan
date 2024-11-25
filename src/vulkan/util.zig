const c = @cImport({
    @cInclude("string.h");
    @cInclude("vulkan/vulkan.h");
});
const std = @import("std");

pub fn strcmp(str1: [*c]const u8, str2: [*c]const u8) bool {
    return c.strcmp(str1, str2) == 1;
}

pub fn vkCheck(res: c.VkResult) void {
    switch (res) {
        c.VK_SUCCESS => {},
        else => {
            std.debug.print("[Vulkan] Error: {}", .{res});
        },
    }
}

pub fn propertyArray(comptime FieldType: type, allocator: std.mem.Allocator, obj: anytype, comptime fieldName: []const u8) ![]FieldType {
    const array = try allocator.alloc(FieldType, obj.len);
    for (0..obj.len) |i| {
        array[i] = @field(obj[i], fieldName);
    }
    return array;
}
