const std = @import("std");
const core = @import("../core.zig");
const vulkan = @import("../vulkan.zig");
const util = @import("../util.zig");
const glslang = vulkan.glslang;
const c = @cImport(@cInclude("vulkan/vulkan.h"));

const glslang_bindings = glslang.glslang;

const RuntimeShader = glslang.RuntimeShader;
const Allocator = std.mem.Allocator;
const VulkanContext = vulkan.VulkanContext;
const VulkanShaderModule = vulkan.VulkanShaderModule;
const VulkanPipeline = vulkan.VulkanPipeline;
const VulkanBuffer = vulkan.VulkanBuffer;
const VulkanImage = vulkan.VulkanImage;
const VulkanSampler = vulkan.VulkanSampler;
const VulkanDescriptorPool = vulkan.VulkanDescriptorPool;
const VulkanDescriptorSet = vulkan.VulkanDescriptorSet;
const VulkanContextCreateOptions = vulkan.VulkanContextCreateOptions;
const GLFW = core.GLFW;
const Window = core.Window;
const ImageData = util.ImageData;
const vkCheck = @import("../vulkan/base.zig").vkCheck;

pub const ApplicationCreateOptions = struct {
    allocator: Allocator,
    vulkanOptions: VulkanContextCreateOptions = .{},
};

pub const Application = struct {
    window: Window,
    ctx: VulkanContext,

    allocator: Allocator,

    pub fn new(options: ApplicationCreateOptions) !Application {
        try glslang_bindings.load();

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

        glslang_bindings.unload();
    }

    pub fn run(self: *Application) void {
        var image = blk: {
            var data = ImageData.load("assets/images/test.png", .RGBA8) catch return;
            defer data.destroy();

            const image = VulkanImage.new(
                &self.ctx.device,
                &data,
                c.VK_IMAGE_USAGE_SAMPLED_BIT | c.VK_IMAGE_USAGE_TRANSFER_DST_BIT,
            ) catch return;

            image.uploadData(
                &self.ctx.device,
                &data,
                c.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
                c.VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT,
            ) catch {
                std.debug.print("Failed to upload data to Image\n", .{});
                return;
            };

            break :blk image;
        };
        defer image.destroy(&self.ctx.device);

        var sampler = VulkanSampler.new(&self.ctx.device, .Linear, .Clamped) catch return;
        defer sampler.destroy(&self.ctx.device);

        var descriptorPool = blk: {
            const sizes = [1]c.VkDescriptorPoolSize{
                .{
                    .descriptorCount = 1,
                    .type = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
                },
            };

            break :blk VulkanDescriptorPool.new(&self.ctx.device, &sizes) catch return;
        };
        defer descriptorPool.destroy(&self.ctx.device);

        var descriptorSet = VulkanDescriptorSet.new(&self.ctx.device, &descriptorPool) catch return;
        defer descriptorSet.destroy(&self.ctx.device);
        descriptorSet.updateSampler(&self.ctx.device, &sampler, &image, 0, 1);

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

        var vertexBuffer = VulkanBuffer.new(
            &self.ctx.device,
            @sizeOf(f32) * vertices.len,
            c.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT | c.VK_BUFFER_USAGE_TRANSFER_DST_BIT,
            c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
        ) catch return;
        defer vertexBuffer.destroy(&self.ctx.device);

        vertexBuffer.uploadData(&self.ctx.device, vertices) catch {
            std.debug.print("Failed to upload data to Vertex Buffer\n", .{});
            return;
        };

        const indices: []const u32 = &.{ 0, 1, 2, 1, 3, 2 };

        var indexBuffer = VulkanBuffer.new(
            &self.ctx.device,
            @sizeOf(f32) * vertices.len,
            c.VK_BUFFER_USAGE_INDEX_BUFFER_BIT | c.VK_BUFFER_USAGE_TRANSFER_DST_BIT,
            c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
        ) catch return;
        defer indexBuffer.destroy(&self.ctx.device);

        indexBuffer.uploadData(&self.ctx.device, indices) catch {
            std.debug.print("Failed to upload data to Index Buffer\n", .{});
            return;
        };

        var vertShader = RuntimeShader.fromFile("assets/shaders/texture.vert", .Vertex, self.allocator) catch return;
        defer vertShader.destroy();

        var fragShader = RuntimeShader.fromFile("assets/shaders/texture.frag", .Fragment, self.allocator) catch return;
        defer fragShader.destroy();

        var pipeline = blk: {
            var vertModule = VulkanShaderModule.new(&self.ctx.device, vertShader.size, vertShader.spirv) catch return;
            defer vertModule.destroy(&self.ctx.device);

            var fragModule = VulkanShaderModule.new(&self.ctx.device, fragShader.size, fragShader.spirv) catch return;
            defer fragModule.destroy(&self.ctx.device);

            var bindings = [1]c.VkVertexInputBindingDescription{undefined};
            bindings[0].binding = 0;
            bindings[0].inputRate = c.VK_VERTEX_INPUT_RATE_VERTEX;
            bindings[0].stride = @sizeOf(f32) * 4;

            var attributes = [2]c.VkVertexInputAttributeDescription{ undefined, undefined };
            attributes[0].binding = 0;
            attributes[0].location = 0;
            attributes[0].format = c.VK_FORMAT_R32G32_SFLOAT;
            attributes[0].offset = 0;
            attributes[1].binding = 0;
            attributes[1].location = 1;
            attributes[1].format = c.VK_FORMAT_R32G32_SFLOAT;
            attributes[1].offset = @sizeOf(f32) * 2;

            const layouts = [1]c.VkDescriptorSetLayout{descriptorSet.layout};

            break :blk VulkanPipeline.new(
                &self.ctx.device,
                &vertModule,
                &fragModule,
                &self.ctx.renderPass,
                &attributes,
                &bindings,
                &layouts,
            ) catch return;
        };
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
                commandBuffer.bindDescriptorSet(&pipeline, &descriptorSet);
                commandBuffer.drawIndexed(indices.len);

                commandBuffer.endRenderPass();
            }
            commandBuffer.end();

            {
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
            }

            {
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
            }

            frameIndex = (frameIndex + 1) % self.ctx.framesInFlight;
        }
    }
};
