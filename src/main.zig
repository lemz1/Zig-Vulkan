const std = @import("std");

const c = @cImport(@cInclude("vulkan/vulkan.h"));

const vkCheck = @import("vulkan/util.zig").vkCheck;

const core = @import("core.zig");
const vulkan = @import("vulkan.zig");

const VulkanContext = vulkan.VulkanContext;
const VulkanPipeline = vulkan.VulkanPipeline;
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

    var ctx = try VulkanContext.create(&window, .{}, allocator);
    defer ctx.destroy();

    var pipeline = try VulkanPipeline.new(
        &ctx.device,
        "assets/shaders/simple_vert.spv",
        "assets/shaders/simple_frag.spv",
        &ctx.renderPass,
        allocator,
    );
    defer pipeline.destroy(&ctx.device);

    defer ctx.device.wait();

    var frameIndex: u32 = 0;
    while (!window.shouldClose()) {
        GLFW.pollEvents();

        const commandPool = ctx.commandPools[frameIndex];
        const commandBuffer = ctx.commandBuffers[frameIndex];
        const fence = ctx.fences[frameIndex];
        const acquireSemaphore = ctx.acquireSemaphores[frameIndex];
        const releaseSemaphore = ctx.releaseSemaphores[frameIndex];

        fence.wait(&ctx.device);

        var imageIndex: u32 = 0;
        {
            const result = ctx.swapchain.acquireNextImage(&ctx.device, &acquireSemaphore, null, &imageIndex);
            switch (result) {
                c.VK_ERROR_OUT_OF_DATE_KHR, c.VK_SUBOPTIMAL_KHR => {
                    ctx.recreateSwapchain() catch {
                        std.debug.print("[Vulkan] could not recreate swapchain\n", .{});
                    };

                    continue;
                },
                else => {
                    vkCheck(result);
                },
            }
        }

        fence.reset(&ctx.device);

        commandPool.reset(&ctx.device);

        commandBuffer.begin();
        {
            commandBuffer.setViewport(@floatFromInt(ctx.swapchain.width), @floatFromInt(ctx.swapchain.height));
            commandBuffer.setScissor(ctx.swapchain.width, ctx.swapchain.height);

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
            commandBuffer.beginRenderPass(&beginInfo);

            commandBuffer.bindGraphicsPipeline(&pipeline);
            commandBuffer.draw(3);

            commandBuffer.endRenderPass();
        }
        commandBuffer.end();

        var submitInfo = c.VkSubmitInfo{};
        submitInfo.sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO;
        submitInfo.commandBufferCount = 1;
        submitInfo.pCommandBuffers = &commandBuffer.handle;
        submitInfo.waitSemaphoreCount = 1;
        submitInfo.pWaitSemaphores = &acquireSemaphore.handle;
        submitInfo.signalSemaphoreCount = 1;
        submitInfo.pSignalSemaphores = &releaseSemaphore.handle;
        const waitMask: c.VkPipelineStageFlags = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
        submitInfo.pWaitDstStageMask = &waitMask;
        ctx.device.graphicsQueue.submit(&submitInfo, &fence);

        var presentInfo = c.VkPresentInfoKHR{};
        presentInfo.sType = c.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;
        presentInfo.swapchainCount = 1;
        presentInfo.pSwapchains = &ctx.swapchain.handle;
        presentInfo.pImageIndices = &imageIndex;
        presentInfo.waitSemaphoreCount = 1;
        presentInfo.pWaitSemaphores = &releaseSemaphore.handle;
        {
            const result = ctx.device.graphicsQueue.present(&presentInfo);
            switch (result) {
                c.VK_ERROR_OUT_OF_DATE_KHR, c.VK_SUBOPTIMAL_KHR => {
                    ctx.recreateSwapchain() catch {
                        std.debug.print("[Vulkan] could not recreate swapchain\n", .{});
                    };
                },
                else => {
                    vkCheck(result);
                },
            }
        }

        frameIndex = (frameIndex + 1) % ctx.framesInFlight;
    }
}
