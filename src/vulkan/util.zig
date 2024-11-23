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
