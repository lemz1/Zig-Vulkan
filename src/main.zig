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
        _ = c.vkAcquireNextImageKHR(ctx.device.handle, ctx.swapchain.handle, std.math.maxInt(u64), null, ctx.fence, &imageIndex);

        vkCheck(c.vkResetCommandPool(ctx.device.handle, ctx.commandPool, 0));

        {
            var beginInfo = c.VkCommandBufferBeginInfo{};
            beginInfo.sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
            beginInfo.flags = c.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
            vkCheck(c.vkBeginCommandBuffer(ctx.commandBuffer, &beginInfo));
        }
        {
            var clearValue = c.VkClearValue{
                .color = .{
                    .float32 = [4]f32{ 0.1, 0.1, 0.1, 1.0 },
                },
            };

            var beginInfo = c.VkRenderPassBeginInfo{};
            beginInfo.sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
            beginInfo.renderPass = ctx.renderPass.handle;
            beginInfo.framebuffer = ctx.framebuffers[imageIndex];
            beginInfo.renderArea = .{
                .offset = .{ .x = 0, .y = 0 },
                .extent = .{ .width = ctx.swapchain.width, .height = ctx.swapchain.height },
            };
            beginInfo.clearValueCount = 1;
            beginInfo.pClearValues = &clearValue;
            c.vkCmdBeginRenderPass(ctx.commandBuffer, &beginInfo, c.VK_SUBPASS_CONTENTS_INLINE);

            c.vkCmdEndRenderPass(ctx.commandBuffer);
        }
        vkCheck(c.vkEndCommandBuffer(ctx.commandBuffer));

        vkCheck(c.vkWaitForFences(ctx.device.handle, 1, &ctx.fence, c.VK_TRUE, std.math.maxInt(u64)));
        vkCheck(c.vkResetFences(ctx.device.handle, 1, &ctx.fence));

        var submitInfo = c.VkSubmitInfo{};
        submitInfo.sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO;
        submitInfo.commandBufferCount = 1;
        submitInfo.pCommandBuffers = &ctx.commandBuffer;
        vkCheck(c.vkQueueSubmit(ctx.device.graphicsQueue.queue, 1, &submitInfo, null));

        ctx.device.wait();

        var presentInfo = c.VkPresentInfoKHR{};
        presentInfo.sType = c.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;
        presentInfo.swapchainCount = 1;
        presentInfo.pSwapchains = &ctx.swapchain.handle;
        presentInfo.pImageIndices = &imageIndex;
        _ = c.vkQueuePresentKHR(ctx.device.graphicsQueue.queue, &presentInfo);
    }
}
