const std = @import("std");
const c = @cImport({
    @cDefine("GLFW_INCLUDE_NONE", {});
    @cInclude("GLFW/glfw3.h");
});
const vk = @import("vulkan/context.zig");

pub fn main() !void {
    _ = try vk.Context.create();

    _ = c.glfwInit();

    const handle = c.glfwCreateWindow(1280, 720, "Vulkan", null, null);

    while (c.glfwWindowShouldClose(handle) == 0) {
        c.glfwPollEvents();
    }

    c.glfwTerminate();
}
