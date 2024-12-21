const std = @import("std");
const core = @import("../core.zig");
const vulkan = @import("../vulkan.zig");
const util = @import("../util.zig");
const gpu = @import("../gpu.zig");
const graphics = @import("../graphics.zig");
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
const VulkanRenderPass = vulkan.VulkanRenderPass;
const VulkanSwapchain = vulkan.VulkanSwapchain;
const VulkanSurface = vulkan.VulkanSurface;
const VulkanCommandPool = vulkan.VulkanCommandPool;
const VulkanCommandBuffer = vulkan.VulkanCommandBuffer;
const VulkanFence = vulkan.VulkanFence;
const VulkanSemaphore = vulkan.VulkanSemaphore;
const VulkanFramebuffer = vulkan.VulkanFramebuffer;
const VulkanShaderModule = vulkan.VulkanShaderModule;
const VulkanPipeline = vulkan.VulkanPipeline;
const VulkanBuffer = vulkan.VulkanBuffer;
const VulkanImage = vulkan.VulkanImage;
const VulkanSampler = vulkan.VulkanSampler;
const VulkanDescriptorPool = vulkan.VulkanDescriptorPool;
const VulkanDescriptorSet = vulkan.VulkanDescriptorSet;
const VulkanContextCreateOptions = vulkan.VulkanContextCreateOptions;
const AssetManager = util.AssetManager;
const ImageData = util.ImageData;
const DescriptorSetGroup = util.DescriptorSetGroup;
const GPUAllocator = gpu.GPUAllocator;
const VertexBuffer = gpu.VertexBuffer;
const IndexBuffer = gpu.IndexBuffer;
const UniformBuffer = gpu.UniformBuffer;
const Image = graphics.Image;
const GLFW = core.GLFW;
const Window = core.Window;
const Event = core.Event;
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
    spvcContext: SPVCContext,

    window: Window,

    vulkanContext: VulkanContext,
    surface: VulkanSurface,
    swapchain: VulkanSwapchain,
    renderPass: VulkanRenderPass,
    commandPools: []VulkanCommandPool,
    commandBuffers: []VulkanCommandBuffer,
    fences: []VulkanFence,
    acquireSemaphores: []VulkanSemaphore,
    releaseSemaphores: []VulkanSemaphore,

    onCreate: Event(OnCreateParams),
    onUpdate: Event(OnUpdateParams),
    onDestroy: Event(OnDestroyParams),

    allocator: Allocator,

    pub fn new(options: ApplicationCreateOptions) !Application {
        try GLSLang.init();

        const spvcContext = try SPVCContext.new();

        try GLFW.init();

        const window = try Window.create(1280, 720, "Vulkan");

        const vulkanContext = try VulkanContext.create(options.vulkanOptions, options.allocator);

        const surface = try VulkanSurface.new(&vulkanContext, &window);
        const swapchain = try VulkanSwapchain.new(&vulkanContext, &surface, c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT, null, options.allocator);
        const renderPass = try VulkanRenderPass.new(&vulkanContext, swapchain.format);

        const commandPools = try options.allocator.alloc(VulkanCommandPool, vulkanContext.framesInFlight);
        const commandBuffers = try options.allocator.alloc(VulkanCommandBuffer, vulkanContext.framesInFlight);

        const fences = try options.allocator.alloc(VulkanFence, vulkanContext.framesInFlight);

        const acquireSemaphores = try options.allocator.alloc(VulkanSemaphore, vulkanContext.framesInFlight);
        const releaseSemaphores = try options.allocator.alloc(VulkanSemaphore, vulkanContext.framesInFlight);

        for (0..vulkanContext.framesInFlight) |i| {
            commandPools[i] = try VulkanCommandPool.new(&vulkanContext, vulkanContext.device.graphicsQueue.familyIndex);
            commandBuffers[i] = try VulkanCommandBuffer.new(&vulkanContext, &commandPools[i]);

            fences[i] = try VulkanFence.new(&vulkanContext, true);

            acquireSemaphores[i] = try VulkanSemaphore.new(&vulkanContext);
            releaseSemaphores[i] = try VulkanSemaphore.new(&vulkanContext);
        }

        const onCreate = Event(OnCreateParams).new(options.allocator);
        const onUpdate = Event(OnUpdateParams).new(options.allocator);
        const onDestroy = Event(OnDestroyParams).new(options.allocator);

        return .{
            .spvcContext = spvcContext,

            .window = window,

            .vulkanContext = vulkanContext,
            .surface = surface,
            .swapchain = swapchain,
            .renderPass = renderPass,
            .commandPools = commandPools,
            .commandBuffers = commandBuffers,
            .fences = fences,
            .acquireSemaphores = acquireSemaphores,
            .releaseSemaphores = releaseSemaphores,

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

        for (0..self.vulkanContext.framesInFlight) |i| {
            self.commandPools[i].destroy(&self.vulkanContext);

            self.releaseSemaphores[i].destroy(&self.vulkanContext);
            self.acquireSemaphores[i].destroy(&self.vulkanContext);

            self.fences[i].destroy(&self.vulkanContext);
        }

        self.renderPass.destroy(&self.vulkanContext);
        self.swapchain.destroy(&self.vulkanContext);
        self.surface.destroy(&self.vulkanContext);
        self.vulkanContext.destroy();

        self.allocator.free(self.releaseSemaphores);
        self.allocator.free(self.acquireSemaphores);
        self.allocator.free(self.fences);
        self.allocator.free(self.commandBuffers);
        self.allocator.free(self.commandPools);

        self.window.destroy();

        GLFW.deinit();

        self.spvcContext.destroy();

        GLSLang.deinit();
    }

    pub fn run(self: *Application) void {
        var gpuAllocator = GPUAllocator.new(&self.vulkanContext, self.allocator) catch return;
        defer gpuAllocator.destroy();

        var assetManager = AssetManager.new(&gpuAllocator, &self.spvcContext, self.allocator);
        defer assetManager.destroy();

        var image = assetManager.loadImage("assets/images/test.png") catch return;
        defer image.release();

        var sampler = VulkanSampler.new(&self.vulkanContext, .Linear, .Clamped) catch return;
        defer sampler.destroy(&self.vulkanContext);

        var uploadPool = VulkanCommandPool.new(&self.vulkanContext, self.vulkanContext.device.graphicsQueue.familyIndex) catch return;
        defer uploadPool.destroy(&self.vulkanContext);

        const uploadCmd = VulkanCommandBuffer.new(&self.vulkanContext, &uploadPool) catch return;

        var depthbuffers = self.allocator.alloc(Image, self.swapchain.images.len) catch return;
        var framebuffers = self.allocator.alloc(VulkanFramebuffer, self.swapchain.images.len) catch return;
        for (0..depthbuffers.len) |i| {
            depthbuffers[i] = Image.new(
                &gpuAllocator,
                &ImageData.empty(self.swapchain.width, self.swapchain.height, .Depth32),
                c.VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT,
            ) catch return;

            const attachments = [_]c.VkImageView{
                self.swapchain.imageViews[i],
                depthbuffers[i].view.handle,
            };

            framebuffers[i] = VulkanFramebuffer.new(
                &self.vulkanContext,
                &self.renderPass,
                @intCast(attachments.len),
                &attachments,
                self.swapchain.width,
                self.swapchain.height,
            ) catch return;
        }
        defer {
            for (0..depthbuffers.len) |i| {
                framebuffers[i].destroy(&self.vulkanContext);
                depthbuffers[i].destroy(&gpuAllocator);
            }
            self.allocator.free(framebuffers);
            self.allocator.free(depthbuffers);
        }

        const modelUniformBuffers = self.allocator.alloc(UniformBuffer, self.vulkanContext.framesInFlight) catch return;
        defer self.allocator.free(modelUniformBuffers);
        for (0..modelUniformBuffers.len) |i| {
            modelUniformBuffers[i] = UniformBuffer.new(&gpuAllocator, @sizeOf(f32) * 2) catch return;
            const data: []const f32 = &.{ 0.1, 0.2 };
            modelUniformBuffers[i].uploadData(&self.vulkanContext, data);
        }
        defer {
            for (modelUniformBuffers) |*buffer| {
                buffer.destroy(&gpuAllocator);
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

        var vertexBuffer = VertexBuffer.new(&gpuAllocator, @sizeOf(f32) * vertices.len) catch return;
        defer vertexBuffer.destroy(&gpuAllocator);

        const indices: []const u32 = &.{ 0, 1, 2, 1, 3, 2 };

        var indexBuffer = IndexBuffer.new(&gpuAllocator, @sizeOf(f32) * vertices.len) catch return;
        defer indexBuffer.destroy(&gpuAllocator);

        {
            uploadCmd.begin();
            vertexBuffer.uploadData(&self.vulkanContext, &uploadCmd, vertices);
            indexBuffer.uploadData(&self.vulkanContext, &uploadCmd, indices);
            uploadCmd.end();

            var submitInfo = c.VkSubmitInfo{};
            submitInfo.sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO;
            submitInfo.commandBufferCount = 1;
            submitInfo.pCommandBuffers = &uploadCmd.handle;
            self.vulkanContext.device.graphicsQueue.submit(&submitInfo, null);
            self.vulkanContext.device.graphicsQueue.wait();
        }

        var pipeline = assetManager.loadGraphicsPipeline(&self.renderPass, "assets/shaders/texture") catch return;
        defer pipeline.release();

        pipeline.asset.getDscriptorSet(0).updateBuffer(&self.vulkanContext, &modelUniformBuffers[0].buffer, @sizeOf(f32) * 2, 0);
        pipeline.asset.getDscriptorSet(0).updateSampler(&self.vulkanContext, &sampler, &image.asset.view, 1);
        pipeline.asset.getDscriptorSet(1).updateBuffer(&self.vulkanContext, &modelUniformBuffers[1].buffer, @sizeOf(f32) * 2, 0);
        pipeline.asset.getDscriptorSet(1).updateSampler(&self.vulkanContext, &sampler, &image.asset.view, 1);

        defer self.vulkanContext.device.wait();

        self.onCreate.dispatch(.{ .app = self });

        var time: f32 = GLFW.getTime();

        var frameIndex: u32 = 0;
        while (!self.window.shouldClose()) {
            GLFW.pollEvents();

            const newTime = GLFW.getTime();
            const deltaTime = newTime - time;
            time = newTime;

            const commandPool = self.commandPools[frameIndex];
            const commandBuffer = self.commandBuffers[frameIndex];
            const fence = self.fences[frameIndex];
            const acquireSemaphore = self.acquireSemaphores[frameIndex];
            const releaseSemaphore = self.releaseSemaphores[frameIndex];

            fence.wait(&self.vulkanContext);

            var imageIndex: u32 = 0;
            {
                const result = self.swapchain.acquireNextImage(&self.vulkanContext, &acquireSemaphore, null, &imageIndex);
                switch (result) {
                    c.VK_ERROR_OUT_OF_DATE_KHR, c.VK_SUBOPTIMAL_KHR => {
                        self.recreateSwapchain() catch {
                            std.debug.print("[Vulkan] Could not recreate Swapchain\n", .{});
                        };

                        continue;
                    },
                    else => {
                        vkCheck(result);
                    },
                }
            }

            self.onUpdate.dispatch(.{ .app = self, .deltaTime = deltaTime });

            fence.reset(&self.vulkanContext);

            commandPool.reset(&self.vulkanContext);

            commandBuffer.begin();
            {
                commandBuffer.setViewport(@floatFromInt(self.swapchain.width), @floatFromInt(self.swapchain.height));
                commandBuffer.setScissor(self.swapchain.width, self.swapchain.height);

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
                beginInfo.renderPass = self.renderPass.handle;
                beginInfo.framebuffer = framebuffers[imageIndex].handle;
                beginInfo.renderArea = .{
                    .offset = .{ .x = 0, .y = 0 },
                    .extent = .{ .width = self.swapchain.width, .height = self.swapchain.height },
                };
                beginInfo.clearValueCount = @intCast(clearValues.len);
                beginInfo.pClearValues = &clearValues;
                commandBuffer.beginRenderPass(&beginInfo);

                commandBuffer.bindGraphicsPipeline(&pipeline.asset.pipeline);

                commandBuffer.bindVertexBuffer(&vertexBuffer.buffer, 0);
                commandBuffer.bindIndexBuffer(&indexBuffer.buffer, 0);
                commandBuffer.bindDescriptorSets(
                    &pipeline.asset.pipeline,
                    &.{pipeline.asset.getDscriptorSet(frameIndex).handle},
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
                self.vulkanContext.device.graphicsQueue.submit(&submitInfo, &fence);
            }

            {
                var presentInfo = c.VkPresentInfoKHR{};
                presentInfo.sType = c.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;
                presentInfo.swapchainCount = 1;
                presentInfo.pSwapchains = &self.swapchain.handle;
                presentInfo.pImageIndices = &imageIndex;
                presentInfo.waitSemaphoreCount = 1;
                presentInfo.pWaitSemaphores = &releaseSemaphore.handle;
                {
                    const result = self.vulkanContext.device.graphicsQueue.present(&presentInfo);
                    switch (result) {
                        c.VK_ERROR_OUT_OF_DATE_KHR, c.VK_SUBOPTIMAL_KHR => {
                            self.recreateSwapchain() catch {
                                std.debug.print("[Vulkan] Could not recreate Swapchain\n", .{});
                            };
                        },
                        else => {
                            vkCheck(result);
                        },
                    }
                }
            }

            frameIndex = (frameIndex + 1) % self.vulkanContext.framesInFlight;
        }

        self.onDestroy.dispatch(.{ .app = self });
    }

    fn recreateSwapchain(_: *Application) !void {
        // var surfaceCapabilities: c.VkSurfaceCapabilitiesKHR = undefined;
        // vkCheck(c.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(self.vulkanContext.device.physicalDevice, self.surface.handle, &surfaceCapabilities));
        // if (surfaceCapabilities.currentExtent.width == 0 or surfaceCapabilities.currentExtent.height == 0) {
        //     return;
        // }

        // self.vulkanContext.device.wait();

        // var oldSwapchain = self.swapchain;
        // self.swapchain = try VulkanSwapchain.new(&self.vulkanContext, &self.surface, c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT, &oldSwapchain, self.allocator);
        // oldSwapchain.destroy(&self.vulkanContext);

        // self.renderPass.destroy(&self.vulkanContext);
        // self.renderPass = try VulkanRenderPass.new(&self.vulkanContext, self.swapchain.format);

        // for (0..framebuffers.len) |i| {
        //     framebuffers[i].destroy(&self.vulkanContext);
        //     depthbuffers[i].destroy(&self.vulkanContext);
        // }
        // self.allocator.free(framebuffers);
        // self.allocator.free(depthbuffers);
        // depthbuffers = try self.allocator.alloc(VulkanImage, self.swapchain.images.len);
        // framebuffers = try self.allocator.alloc(VulkanFramebuffer, self.swapchain.images.len);

        // for (0..framebuffers.len) |i| {
        //     depthbuffers[i] = try VulkanImage.new(
        //         &self.vulkanContext,
        //         &ImageData.empty(self.swapchain.width, self.swapchain.height, .Depth32),
        //         c.VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT,
        //     );
        //     const attachments = [_]c.VkImageView{
        //         self.swapchain.imageViews[i],
        //         depthbuffers[i].view,
        //     };
        //     framebuffers[i] = try VulkanFramebuffer.new(
        //         &self.vulkanContext,
        //         &self.renderPass,
        //         @intCast(attachments.len),
        //         &attachments,
        //         self.swapchain.width,
        //         self.swapchain.height,
        //     );
        // }
    }
};
