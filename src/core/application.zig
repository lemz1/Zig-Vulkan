const std = @import("std");
const core = @import("../core.zig");
const vulkan = @import("../vulkan.zig");
const util = @import("../util.zig");
const glslang = vulkan.glslang;
const c = @cImport(@cInclude("vulkan/vulkan.h"));
const cglslang = @cImport(@cInclude("glslang/Include/glslang_c_interface.h"));

const Allocator = std.mem.Allocator;
const VulkanContext = vulkan.VulkanContext;
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
        try glslang.load();

        var input = cglslang.glslang_input_t{};
        input.language = cglslang.GLSLANG_SOURCE_GLSL;
        input.stage = cglslang.GLSLANG_STAGE_VERTEX;
        input.client = cglslang.GLSLANG_CLIENT_VULKAN;
        input.client_version = cglslang.GLSLANG_TARGET_VULKAN_1_3;
        input.target_language = cglslang.GLSLANG_TARGET_SPV;
        input.target_language_version = cglslang.GLSLANG_TARGET_SPV_1_6;
        input.code =
            \\ #version 450 core
            \\ 
            \\ vec2 positions[3] = vec2[](
            \\   vec2(0.0, -0.5),
            \\   vec2(0.5, 0.5),
            \\   vec2(-0.5, 0.5)
            \\ );
            \\ 
            \\ void main() {
            \\   gl_Position = vec4(positions[gl_VertexIndex], 0.0, 1.0);
            \\ }
        ;
        input.default_version = 450;
        input.default_profile = cglslang.GLSLANG_NO_PROFILE;
        input.force_default_version_and_profile = 0;
        input.forward_compatible = 0;
        input.messages = cglslang.GLSLANG_MSG_DEFAULT_BIT;
        input.resource = @ptrCast(glslang.defaultResource());

        const shader = glslang.shaderCreate(@ptrCast(&input)) orelse @panic("shut");

        if (!glslang.shaderPreprocess(shader, @ptrCast(&input))) {
            @panic("shut 2");
        }

        if (!glslang.shaderParse(shader, @ptrCast(&input))) {
            @panic("shut 3");
        }

        const program = glslang.programCreate() orelse @panic("shut 4");
        glslang.programAddShader(program, shader);

        if (!glslang.programLink(program)) {
            @panic("shut 5");
        }

        glslang.programSPIRVGenerate(program, input.stage);
        const size = glslang.programSPIRVGetSize(program);
        const spirv = glslang.programSPIRVGetPtr(program);

        if (glslang.programSPIRVGetMessages(program) != null) {
            @panic("shut 6");
        }

        std.debug.print("{any}, {any}\n", .{ size, spirv });

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

        glslang.unload();
    }

    pub fn run(self: *Application) void {
        var image = blk: {
            var data = if (ImageData.load("assets/images/test.png", .RGBA8)) |v| v else |_| return;
            defer data.destroy();

            const image = if (VulkanImage.new(
                &self.ctx.device,
                &data,
                c.VK_IMAGE_USAGE_SAMPLED_BIT | c.VK_IMAGE_USAGE_TRANSFER_DST_BIT,
            )) |v| v else |_| return;

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

        var sampler = if (VulkanSampler.new(&self.ctx.device, .Linear, .Clamped)) |v| v else |_| return;
        defer sampler.destroy(&self.ctx.device);

        var descriptorPool = blk: {
            const sizes = [1]c.VkDescriptorPoolSize{
                .{
                    .descriptorCount = 1,
                    .type = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
                },
            };

            if (VulkanDescriptorPool.new(&self.ctx.device, &sizes)) |v| break :blk v else |_| return;
        };
        defer descriptorPool.destroy(&self.ctx.device);

        var descriptorSet = blk: {
            const descriptorSet = if (VulkanDescriptorSet.new(&self.ctx.device, &descriptorPool)) |v| v else |_| return;
            descriptorSet.updateSampler(&self.ctx.device, &sampler, &image, 0, 1);
            break :blk descriptorSet;
        };
        defer descriptorSet.destroy(&self.ctx.device);

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

        var pipeline = blk: {
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

            if (VulkanPipeline.new(
                &self.ctx.device,
                "assets/shaders/texture.vert.spv",
                "assets/shaders/texture.frag.spv",
                &self.ctx.renderPass,
                &attributes,
                &bindings,
                &layouts,
                self.allocator,
            )) |v| break :blk v else |_| return;
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
