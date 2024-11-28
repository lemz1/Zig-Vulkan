const std = @import("std");
const Allocator = std.mem.Allocator;

const c = @cImport(@cInclude("vulkan/vulkan.h"));

const memcpy = @cImport(@cInclude("memory.h")).memcpy;

const vkCheck = @import("../vulkan/util.zig").vkCheck;

const core = @import("../core.zig");
const vulkan = @import("../vulkan.zig");

const VulkanContext = vulkan.VulkanContext;
const VulkanPipeline = vulkan.VulkanPipeline;
const VulkanBuffer = vulkan.VulkanBuffer;
const VulkanCreateOptions = vulkan.VulkanCreateOptions;
const GLFW = core.GLFW;
const Window = core.Window;

pub const ApplicationCreateOptions = struct {
    allocator: Allocator,
    vulkanOptions: VulkanCreateOptions = .{},
};

pub const Application = struct {
    window: Window,
    ctx: VulkanContext,

    allocator: Allocator,

    pub fn new(options: ApplicationCreateOptions) !Application {
        try GLFW.init();

        const window = try Window.create(1280, 720, "Vulkan");

        const ctx = try VulkanContext.create(&window, options.vulkanOptions, options.allocator);

        return .{
            .window = window,
            .ctx = ctx,
            .allocator = options.allocator,
        };
    }

    pub fn destroy(self: *Application) void {
        self.ctx.destroy();
        self.window.destroy();
        GLFW.deinit();
    }

    pub fn run(self: *Application) void {
        const vertices = &[_]f32{ 0.0, -0.5, 0.5, 0.5, -0.5, 0.5 };

        var vertexBuffer = if (VulkanBuffer.new(
            &self.ctx.device,
            @sizeOf(f32) * vertices.len,
            c.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
            c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT,
        )) |v| v else |_| return;
        defer vertexBuffer.destroy(&self.ctx.device);

        var data: ?*anyopaque = undefined;
        vkCheck(c.vkMapMemory(self.ctx.device.handle, vertexBuffer.memory, 0, @sizeOf(f32) * vertices.len, 0, &data));
        _ = memcpy(data, vertices, @sizeOf(f32) * vertices.len);
        c.vkUnmapMemory(self.ctx.device.handle, vertexBuffer.memory);

        var vertexBindingDescriptions = [1]c.VkVertexInputBindingDescription{undefined};
        vertexBindingDescriptions[0].binding = 0;
        vertexBindingDescriptions[0].inputRate = c.VK_VERTEX_INPUT_RATE_VERTEX;
        vertexBindingDescriptions[0].stride = @sizeOf(f32) * 2;

        var vertexAttributeDescriptions = [1]c.VkVertexInputAttributeDescription{undefined};
        vertexAttributeDescriptions[0].binding = 0;
        vertexAttributeDescriptions[0].location = 0;
        vertexAttributeDescriptions[0].format = c.VK_FORMAT_R32G32_SFLOAT;
        vertexAttributeDescriptions[0].offset = 0;

        var pipeline = if (VulkanPipeline.new(
            &self.ctx.device,
            "assets/shaders/buffer_vert.spv",
            "assets/shaders/buffer_frag.spv",
            &self.ctx.renderPass,
            &vertexAttributeDescriptions,
            &vertexBindingDescriptions,
            self.allocator,
        )) |v| v else |_| return;
        defer pipeline.destroy(&self.ctx.device);

        defer self.ctx.device.wait();

        var frameIndex: u32 = 0;
        while (!self.window.shouldClose()) {
            GLFW.pollEvents();

            const commandPool = self.ctx.commandPools[frameIndex];
            const commandBuffer = self.ctx.commandBuffers[frameIndex];
            const fence = self.ctx.fences[frameIndex];
            const acquireSemaphore = self.ctx.acquireSemaphores[frameIndex];
            const releaseSemaphore = self.ctx.releaseSemaphores[frameIndex];

            fence.wait(&self.ctx.device);

            var imageIndex: u32 = 0;
            {
                const result = self.ctx.swapchain.acquireNextImage(&self.ctx.device, &acquireSemaphore, null, &imageIndex);
                switch (result) {
                    c.VK_ERROR_OUT_OF_DATE_KHR, c.VK_SUBOPTIMAL_KHR => {
                        self.ctx.recreateSwapchain() catch {
                            std.debug.print("[Vulkan] could not recreate swapchain\n", .{});
                        };

                        continue;
                    },
                    else => {
                        vkCheck(result);
                    },
                }
            }

            fence.reset(&self.ctx.device);

            commandPool.reset(&self.ctx.device);

            commandBuffer.begin();
            {
                commandBuffer.setViewport(@floatFromInt(self.ctx.swapchain.width), @floatFromInt(self.ctx.swapchain.height));
                commandBuffer.setScissor(self.ctx.swapchain.width, self.ctx.swapchain.height);

                var clearValue = c.VkClearValue{
                    .color = .{
                        .float32 = [4]f32{ 0.1, 0.1, 0.1, 1.0 },
                    },
                };

                var beginInfo = c.VkRenderPassBeginInfo{};
                beginInfo.sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
                beginInfo.renderPass = self.ctx.renderPass.handle;
                beginInfo.framebuffer = self.ctx.framebuffers[imageIndex].handle;
                beginInfo.renderArea = .{
                    .offset = .{ .x = 0, .y = 0 },
                    .extent = .{ .width = self.ctx.swapchain.width, .height = self.ctx.swapchain.height },
                };
                beginInfo.clearValueCount = 1;
                beginInfo.pClearValues = &clearValue;
                commandBuffer.beginRenderPass(&beginInfo);

                commandBuffer.bindGraphicsPipeline(&pipeline);
                const offset: c.VkDeviceSize = undefined;
                c.vkCmdBindVertexBuffers(commandBuffer.handle, 0, 1, &vertexBuffer.handle, &offset);
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
            self.ctx.device.graphicsQueue.submit(&submitInfo, &fence);

            var presentInfo = c.VkPresentInfoKHR{};
            presentInfo.sType = c.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;
            presentInfo.swapchainCount = 1;
            presentInfo.pSwapchains = &self.ctx.swapchain.handle;
            presentInfo.pImageIndices = &imageIndex;
            presentInfo.waitSemaphoreCount = 1;
            presentInfo.pWaitSemaphores = &releaseSemaphore.handle;
            {
                const result = self.ctx.device.graphicsQueue.present(&presentInfo);
                switch (result) {
                    c.VK_ERROR_OUT_OF_DATE_KHR, c.VK_SUBOPTIMAL_KHR => {
                        self.ctx.recreateSwapchain() catch {
                            std.debug.print("[Vulkan] could not recreate swapchain\n", .{});
                        };
                    },
                    else => {
                        vkCheck(result);
                    },
                }
            }

            frameIndex = (frameIndex + 1) % self.ctx.framesInFlight;
        }
    }
};
