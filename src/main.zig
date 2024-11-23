const std = @import("std");
const c = @cImport(@cInclude("GLFW/glfw3.h"));

pub fn main() !void {
    _ = c.glfwInit();

    const handle = c.glfwCreateWindow(1280, 720, "Vulkan", null, null);

    while (c.glfwWindowShouldClose(handle) == 0) {
        c.glfwPollEvents();
    }

    c.glfwTerminate();
}
