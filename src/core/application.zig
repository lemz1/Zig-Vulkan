const std = @import("std");
const core = @import("../core.zig");
const vulkan = @import("../vulkan.zig");
const util = @import("../util.zig");
const c = @cImport(@cInclude("vulkan/vulkan.h"));

const Allocator = std.mem.Allocator;
const VulkanContext = vulkan.VulkanContext;
const VulkanPipeline = vulkan.VulkanPipeline;
const VulkanBuffer = vulkan.VulkanBuffer;
const VulkanImage = vulkan.VulkanImage;
const VulkanSampler = vulkan.VulkanSampler;
const VulkanDescriptorSet = vulkan.VulkanDescriptorSet;
const VulkanCreateOptions = vulkan.VulkanCreateOptions;
const GLFW = core.GLFW;
const Window = core.Window;
const ImageData = util.ImageData;
const vkCheck = @import("../vulkan/base.zig").vkCheck;

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
        var imageData = if (ImageData.load("assets/images/test.png", .RGBA8)) |v| v else |_| return;
        defer imageData.destroy();

        var image = if (VulkanImage.new(
            &self.ctx.device,
            &imageData,
            c.VK_IMAGE_USAGE_SAMPLED_BIT | c.VK_IMAGE_USAGE_TRANSFER_DST_BIT,
        )) |v| v else |_| return;
        defer image.destroy(&self.ctx.device);

        image.uploadData(
            &self.ctx.device,
            &imageData,
            c.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
            c.VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT,
        ) catch {
            std.debug.print("Failed to upload data to Image\n", .{});
            return;
        };

        var sampler = if (VulkanSampler.new(&self.ctx.device)) |v| v else |_| return;
        defer sampler.destroy(&self.ctx.device);

        var descriptorSet = if (VulkanDescriptorSet.new(&self.ctx.device)) |v| v else |_| return;
        defer descriptorSet.destroy(&self.ctx.device);

        descriptorSet.update(&self.ctx.device, &sampler, &image);

        const vertices: []const f32 = &.{
            -0.5,
            -0.5,
            0.0,
            0.0,

            0.5,
            -0.5,
            1.0,
            0.0,

            -0.5,
            0.5,
            0.0,
            1.0,

            0.5,
            0.5,
            1.0,
            1.0,
        };

        var vertexBuffer = if (VulkanBuffer.new(
            &self.ctx.device,
            @sizeOf(f32) * vertices.len,
            c.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT | c.VK_BUFFER_USAGE_TRANSFER_DST_BIT,
            c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
        )) |v| v else |_| return;
        defer vertexBuffer.destroy(&self.ctx.device);

        vertexBuffer.uploadData(&self.ctx.device, vertices) catch {
            std.debug.print("Failed to upload data to Vertex Buffer\n", .{});
            return;
        };

        const indices: []const u32 = &.{ 0, 1, 2, 1, 3, 2 };

        var indexBuffer = if (VulkanBuffer.new(
            &self.ctx.device,
            @sizeOf(f32) * vertices.len,
            c.VK_BUFFER_USAGE_INDEX_BUFFER_BIT | c.VK_BUFFER_USAGE_TRANSFER_DST_BIT,
            c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
        )) |v| v else |_| return;
        defer indexBuffer.destroy(&self.ctx.device);

        indexBuffer.uploadData(&self.ctx.device, indices) catch {
            std.debug.print("Failed to upload data to Index Buffer\n", .{});
            return;
        };

        var vertexBindingDescriptions = [1]c.VkVertexInputBindingDescription{undefined};
        vertexBindingDescriptions[0].binding = 0;
        vertexBindingDescriptions[0].inputRate = c.VK_VERTEX_INPUT_RATE_VERTEX;
        vertexBindingDescriptions[0].stride = @sizeOf(f32) * 4;

        var vertexAttributeDescriptions = [2]c.VkVertexInputAttributeDescription{ undefined, undefined };
        vertexAttributeDescriptions[0].binding = 0;
        vertexAttributeDescriptions[0].location = 0;
        vertexAttributeDescriptions[0].format = c.VK_FORMAT_R32G32_SFLOAT;
        vertexAttributeDescriptions[0].offset = 0;
        vertexAttributeDescriptions[1].binding = 0;
        vertexAttributeDescriptions[1].location = 1;
        vertexAttributeDescriptions[1].format = c.VK_FORMAT_R32G32_SFLOAT;
        vertexAttributeDescriptions[1].offset = @sizeOf(f32) * 2;

        var descriptorSetLayouts = [1]c.VkDescriptorSetLayout{descriptorSet.layout};

        var pipeline = if (VulkanPipeline.new(
            &self.ctx.device,
            "assets/shaders/texture_vert.spv",
            "assets/shaders/texture_frag.spv",
            &self.ctx.renderPass,
            &vertexAttributeDescriptions,
            &vertexBindingDescriptions,
            &descriptorSetLayouts,
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
                            std.debug.print("[Vulkan] Could not recreate Swapchain\n", .{});
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

                commandBuffer.bindVertexBuffer(&vertexBuffer, 0);
                commandBuffer.bindIndexBuffer(&indexBuffer, 0);
                c.vkCmdBindDescriptorSets(commandBuffer.handle, c.VK_PIPELINE_BIND_POINT_GRAPHICS, pipeline.layout, 0, 1, &descriptorSet.handle, 0, null);
                commandBuffer.drawIndexed(indices.len);

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
                            std.debug.print("[Vulkan] Could not recreate Swapchain\n", .{});
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
