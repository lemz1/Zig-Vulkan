const std = @import("std");

const c = @cImport(@cInclude("vulkan/vulkan.h"));

const vkCheck = @import("vulkan/util.zig").vkCheck;

const core = @import("core.zig");
const vulkan = @import("vulkan.zig");

const VulkanContext = vulkan.VulkanContext;
const GLFW = core.GLFW;
const Window = core.Window;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try GLFW.init();
    defer GLFW.deinit();

    var window = try Window.create(1280, 720, "Vulkan");
    defer window.destroy();

    var ctx = try VulkanContext.create(&window, allocator);
    defer ctx.destroy();

    while (!window.shouldClose()) {
        GLFW.pollEvents();

        var imageIndex: u32 = 0;
        _ = c.vkAcquireNextImageKHR(ctx.device.handle, ctx.swapchain.handle, std.math.maxInt(u64), null, ctx.fence.handle, &imageIndex);

        ctx.commandPool.reset(&ctx.device);

        ctx.commandBuffer.begin();
        {
            var clearValue = c.VkClearValue{
                .color = .{
                    .float32 = [4]f32{ 0.1, 0.1, 0.1, 1.0 },
                },
            };

            var beginInfo = c.VkRenderPassBeginInfo{};
            beginInfo.sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
            beginInfo.renderPass = ctx.renderPass.handle;
            beginInfo.framebuffer = ctx.framebuffers[imageIndex].handle;
            beginInfo.renderArea = .{
                .offset = .{ .x = 0, .y = 0 },
                .extent = .{ .width = ctx.swapchain.width, .height = ctx.swapchain.height },
            };
            beginInfo.clearValueCount = 1;
            beginInfo.pClearValues = &clearValue;
            ctx.commandBuffer.beginRenderPass(&beginInfo);

            ctx.commandBuffer.endRenderPass();
        }
        ctx.commandBuffer.end();

        ctx.fence.wait(&ctx.device);
        ctx.fence.reset(&ctx.device);

        var submitInfo = c.VkSubmitInfo{};
        submitInfo.sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO;
        submitInfo.commandBufferCount = 1;
        submitInfo.pCommandBuffers = &ctx.commandBuffer.handle;
        ctx.device.graphicsQueue.submit(&submitInfo, null);

        ctx.device.wait();

        var presentInfo = c.VkPresentInfoKHR{};
        presentInfo.sType = c.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;
        presentInfo.swapchainCount = 1;
        presentInfo.pSwapchains = &ctx.swapchain.handle;
        presentInfo.pImageIndices = &imageIndex;
        _ = ctx.device.graphicsQueue.present(&presentInfo);
    }
}
