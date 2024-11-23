const std = @import("std");

const core = @import("core.zig");
const vulkan = @import("vulkan.zig");

const Context = vulkan.Context;
const GLFW = core.GLFW;
const Window = core.Window;

pub fn main() !void {
    var ctx = try Context.create();
    defer ctx.destroy();

    try GLFW.init();
    defer GLFW.deinit();

    var window = try Window.create(1280, 720, "Vulkan");
    defer window.destroy();

    while (!window.shouldClose()) {
        GLFW.pollEvents();
    }
}
