const std = @import("std");

const core = @import("core.zig");
const vulkan = @import("vulkan.zig");

const VulkanContext = vulkan.VulkanContext;
const GLFW = core.GLFW;
const Window = core.Window;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var ctx = try VulkanContext.create(allocator);
    defer ctx.destroy();

    try GLFW.init();
    defer GLFW.deinit();

    var window = try Window.create(1280, 720, "Vulkan");
    defer window.destroy();

    while (!window.shouldClose()) {
        GLFW.pollEvents();
    }
}
