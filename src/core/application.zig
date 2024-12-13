const std = @import("std");
const core = @import("../core.zig");
const vulkan = @import("../vulkan.zig");
const util = @import("../util.zig");
const glslang = @import("../glslang.zig");
const spvc = @import("../spvc.zig");
const c = @cImport(@cInclude("vulkan/vulkan.h"));

const GLSLang = glslang.GLSLang;
const SPVCContext = spvc.SPVCContext;
const SPVCParsedIR = spvc.SPVCParsedIR;
const SPVCCompiler = spvc.SPVCCompiler;
const SPVCResources = spvc.SPVCResources;
const SPVCType = spvc.SPVCType;
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
const AssetManager = util.AssetManager;
const GLFW = core.GLFW;
const Window = core.Window;
const Event = core.Event;
const ImageData = util.ImageData;
const vkCheck = @import("../vulkan/base.zig").vkCheck;

pub const OnCreateParams = struct {
    app: *Application,
};

pub const OnUpdateParams = struct {
    app: *Application,
    deltaTime: f32,
};

pub const OnDestroyParams = struct {
    app: *Application,
};

pub const ApplicationCreateOptions = struct {
    allocator: Allocator,
    vulkanOptions: VulkanContextCreateOptions = .{},
};

pub const Application = struct {
    window: Window,
    ctx: VulkanContext,
    spvcCtx: SPVCContext,

    onCreate: Event(OnCreateParams),
    onUpdate: Event(OnUpdateParams),
    onDestroy: Event(OnDestroyParams),

    allocator: Allocator,

    pub fn new(options: ApplicationCreateOptions) !Application {
        try GLSLang.init();

        const spvcCtx = try SPVCContext.new();

        try GLFW.init();

        const window = try Window.create(1280, 720, "Vulkan");

        const ctx = try VulkanContext.create(&window, options.vulkanOptions, options.allocator);

        const onCreate = Event(OnCreateParams).new(options.allocator);
        const onUpdate = Event(OnUpdateParams).new(options.allocator);
        const onDestroy = Event(OnDestroyParams).new(options.allocator);

        return .{
            .window = window,
            .ctx = ctx,
            .spvcCtx = spvcCtx,

            .onCreate = onCreate,
            .onUpdate = onUpdate,
            .onDestroy = onDestroy,

            .allocator = options.allocator,
        };
    }

    pub fn destroy(self: *Application) void {
        self.onDestroy.destroy();
        self.onUpdate.destroy();
        self.onCreate.destroy();
        self.ctx.destroy();
        self.window.destroy();
        GLFW.deinit();
        self.spvcCtx.destroy();
        GLSLang.deinit();
    }

    pub fn run(self: *Application) void {
        var assetManager = AssetManager.new(&self.ctx);
        defer assetManager.destroy();

        var image = assetManager.loadImage("assets/images/test.png", .RGBA8) catch return;
        defer image.release();

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

        var descriptorSet = blk: {
            var bindings = [1]c.VkDescriptorSetLayoutBinding{undefined};
            bindings[0].binding = 0;
            bindings[0].descriptorCount = 1;
            bindings[0].descriptorType = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
            bindings[0].stageFlags = c.VK_SHADER_STAGE_FRAGMENT_BIT;
            bindings[0].pImmutableSamplers = null;

            break :blk VulkanDescriptorSet.new(&self.ctx.device, &descriptorPool, 1, &bindings) catch return;
        };
        defer descriptorSet.destroy(&self.ctx.device);
        descriptorSet.updateSampler(&self.ctx.device, &sampler, image.asset, 0);

        const modelUniformBuffers = self.allocator.alloc(VulkanBuffer, self.ctx.framesInFlight) catch return;
        defer self.allocator.free(modelUniformBuffers);
        for (0..modelUniformBuffers.len) |i| {
            modelUniformBuffers[i] = VulkanBuffer.new(
                &self.ctx.device,
                @sizeOf(f32) * 2,
                c.VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT | c.VK_BUFFER_USAGE_TRANSFER_DST_BIT,
                c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
            ) catch return;
            const data: []const f32 = &.{ 0.1, 0.2 };
            modelUniformBuffers[i].uploadData(&self.ctx.device, data) catch return;
        }
        defer {
            for (modelUniformBuffers) |*buffer| {
                buffer.destroy(&self.ctx.device);
            }
        }

        var modelDescriptorPool = blk: {
            const sizes = [1]c.VkDescriptorPoolSize{
                .{
                    .descriptorCount = self.ctx.framesInFlight,
                    .type = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
                },
            };

            break :blk VulkanDescriptorPool.new(&self.ctx.device, &sizes) catch return;
        };
        defer modelDescriptorPool.destroy(&self.ctx.device);

        const modelDescriptorSets = self.allocator.alloc(VulkanDescriptorSet, self.ctx.framesInFlight) catch return;
        defer self.allocator.free(modelDescriptorSets);
        for (0..modelDescriptorSets.len) |i| {
            var bindings = [1]c.VkDescriptorSetLayoutBinding{undefined};
            bindings[0].binding = 0;
            bindings[0].descriptorCount = 1;
            bindings[0].descriptorType = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
            bindings[0].stageFlags = c.VK_SHADER_STAGE_VERTEX_BIT;
            bindings[0].pImmutableSamplers = null;

            modelDescriptorSets[i] = VulkanDescriptorSet.new(&self.ctx.device, &modelDescriptorPool, 1, &bindings) catch return;
            modelDescriptorSets[i].updateBuffer(&self.ctx.device, &modelUniformBuffers[i], @sizeOf(f32) * 2, 0);
        }
        defer {
            for (modelDescriptorSets) |*set| {
                set.destroy(&self.ctx.device);
            }
        }

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

        var vertShader = assetManager.loadShader("assets/shaders/texture.vert", .Vertex) catch return;
        defer vertShader.release();

        var fragShader = assetManager.loadShader("assets/shaders/texture.frag", .Fragment) catch return;
        defer fragShader.release();

        var pipeline = blk: {
            var vertModule = VulkanShaderModule.new(&self.ctx.device, vertShader.asset.spirvSize, vertShader.asset.spirvCode) catch return;
            defer vertModule.destroy(&self.ctx.device);

            var fragModule = VulkanShaderModule.new(&self.ctx.device, fragShader.asset.spirvSize, fragShader.asset.spirvCode) catch return;
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

            const layouts: []const c.VkDescriptorSetLayout = &.{
                descriptorSet.layout,
                modelDescriptorSets[0].layout,
            };

            break :blk VulkanPipeline.new(
                &self.ctx.device,
                &vertModule,
                &fragModule,
                &self.ctx.renderPass,
                &attributes,
                &bindings,
                layouts,
            ) catch return;
        };
        defer pipeline.destroy(&self.ctx.device);

        defer self.ctx.device.wait();

        self.onCreate.dispatch(.{ .app = self });

        var time: f32 = GLFW.getTime();

        var frameIndex: u32 = 0;
        while (!self.window.shouldClose()) {
            GLFW.pollEvents();

            const newTime = GLFW.getTime();
            const deltaTime = newTime - time;
            time = newTime;

            self.onUpdate.dispatch(.{ .app = self, .deltaTime = deltaTime });

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

                const clearValues = [2]c.VkClearValue{
                    .{
                        .color = .{
                            .float32 = [4]f32{ 0.1, 0.1, 0.1, 1.0 },
                        },
                    },
                    .{
                        .depthStencil = .{ .depth = 1.0, .stencil = 0.0 },
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
                beginInfo.clearValueCount = @intCast(clearValues.len);
                beginInfo.pClearValues = &clearValues;
                commandBuffer.beginRenderPass(&beginInfo);

                commandBuffer.bindGraphicsPipeline(&pipeline);

                commandBuffer.bindVertexBuffer(&vertexBuffer, 0);
                commandBuffer.bindIndexBuffer(&indexBuffer, 0);
                commandBuffer.bindDescriptorSets(
                    &pipeline,
                    &.{
                        descriptorSet.handle,
                        modelDescriptorSets[frameIndex].handle,
                    },
                );
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

        self.onDestroy.dispatch(.{ .app = self });
    }
};
