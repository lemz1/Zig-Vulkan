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
const GLFW = core.GLFW;
const Window = core.Window;
const Event = core.Event;
const ImageData = util.ImageData;
const DescriptorSetGroup = util.DescriptorSetGroup;
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
    depthbuffers: []VulkanImage,
    framebuffers: []VulkanFramebuffer,
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

        const depthbuffers = try options.allocator.alloc(VulkanImage, swapchain.images.len);
        const framebuffers = try options.allocator.alloc(VulkanFramebuffer, swapchain.images.len);
        for (0..swapchain.images.len) |i| {
            depthbuffers[i] = try VulkanImage.new(
                &vulkanContext,
                &ImageData.empty(swapchain.width, swapchain.height, .Depth32),
                c.VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT,
            );
            const attachments = [_]c.VkImageView{
                swapchain.imageViews[i],
                depthbuffers[i].view,
            };
            framebuffers[i] = try VulkanFramebuffer.new(&vulkanContext, &renderPass, @intCast(attachments.len), &attachments, swapchain.width, swapchain.height);
        }

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
            .depthbuffers = depthbuffers,
            .framebuffers = framebuffers,
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

        for (0..self.framebuffers.len) |i| {
            self.framebuffers[i].destroy(&self.vulkanContext);
            self.depthbuffers[i].destroy(&self.vulkanContext);
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
        self.allocator.free(self.framebuffers);
        self.allocator.free(self.depthbuffers);

        self.window.destroy();

        GLFW.deinit();

        self.spvcContext.destroy();

        GLSLang.deinit();
    }

    pub fn run(self: *Application) void {
        var assetManager = AssetManager.new(&self.vulkanContext, self.allocator);
        defer assetManager.destroy();

        var image = assetManager.loadImage("assets/images/test.png", .RGBA8) catch return;
        defer image.release();

        var sampler = VulkanSampler.new(&self.vulkanContext, .Linear, .Clamped) catch return;
        defer sampler.destroy(&self.vulkanContext);

        var descriptorPool = blk: {
            const sizes = [1]c.VkDescriptorPoolSize{
                .{
                    .descriptorCount = self.vulkanContext.framesInFlight,
                    .type = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
                },
            };

            break :blk VulkanDescriptorPool.new(&self.vulkanContext, &sizes) catch return;
        };
        defer descriptorPool.destroy(&self.vulkanContext);

        var descriptorSetGroup = blk: {
            var bindings = [1]c.VkDescriptorSetLayoutBinding{undefined};
            bindings[0].binding = 0;
            bindings[0].descriptorCount = 1;
            bindings[0].descriptorType = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
            bindings[0].stageFlags = c.VK_SHADER_STAGE_FRAGMENT_BIT;
            bindings[0].pImmutableSamplers = null;

            break :blk DescriptorSetGroup.new(
                &self.vulkanContext,
                &descriptorPool,
                &bindings,
                self.vulkanContext.framesInFlight,
                self.allocator,
            ) catch return;
        };
        defer descriptorSetGroup.destroy(&self.vulkanContext);
        descriptorSetGroup.sets[0].updateSampler(&self.vulkanContext, &sampler, image.asset, 0);
        descriptorSetGroup.sets[1].updateSampler(&self.vulkanContext, &sampler, image.asset, 0);

        const modelUniformBuffers = self.allocator.alloc(VulkanBuffer, self.vulkanContext.framesInFlight) catch return;
        defer self.allocator.free(modelUniformBuffers);
        for (0..modelUniformBuffers.len) |i| {
            modelUniformBuffers[i] = VulkanBuffer.new(
                &self.vulkanContext,
                @sizeOf(f32) * 2,
                c.VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT | c.VK_BUFFER_USAGE_TRANSFER_DST_BIT,
                c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
            ) catch return;
            const data: []const f32 = &.{ 0.1, 0.2 };
            modelUniformBuffers[i].uploadData(&self.vulkanContext, data) catch return;
        }
        defer {
            for (modelUniformBuffers) |*buffer| {
                buffer.destroy(&self.vulkanContext);
            }
        }

        var modelDescriptorPool = blk: {
            const sizes = [1]c.VkDescriptorPoolSize{
                .{
                    .descriptorCount = self.vulkanContext.framesInFlight,
                    .type = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
                },
            };

            break :blk VulkanDescriptorPool.new(&self.vulkanContext, &sizes) catch return;
        };
        defer modelDescriptorPool.destroy(&self.vulkanContext);

        var modelDescriptorSetGroup = blk: {
            var bindings = [1]c.VkDescriptorSetLayoutBinding{undefined};
            bindings[0].binding = 0;
            bindings[0].descriptorCount = 1;
            bindings[0].descriptorType = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
            bindings[0].stageFlags = c.VK_SHADER_STAGE_VERTEX_BIT;
            bindings[0].pImmutableSamplers = null;

            break :blk DescriptorSetGroup.new(
                &self.vulkanContext,
                &modelDescriptorPool,
                &bindings,
                self.vulkanContext.framesInFlight,
                self.allocator,
            ) catch return;
        };
        defer modelDescriptorSetGroup.destroy(&self.vulkanContext);
        modelDescriptorSetGroup.sets[0].updateBuffer(&self.vulkanContext, &modelUniformBuffers[0], @sizeOf(f32) * 2, 0);
        modelDescriptorSetGroup.sets[1].updateBuffer(&self.vulkanContext, &modelUniformBuffers[1], @sizeOf(f32) * 2, 0);

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
            &self.vulkanContext,
            @sizeOf(f32) * vertices.len,
            c.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT | c.VK_BUFFER_USAGE_TRANSFER_DST_BIT,
            c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
        ) catch return;
        defer vertexBuffer.destroy(&self.vulkanContext);

        vertexBuffer.uploadData(&self.vulkanContext, vertices) catch {
            std.debug.print("Failed to upload data to Vertex Buffer\n", .{});
            return;
        };

        const indices: []const u32 = &.{ 0, 1, 2, 1, 3, 2 };

        var indexBuffer = VulkanBuffer.new(
            &self.vulkanContext,
            @sizeOf(f32) * vertices.len,
            c.VK_BUFFER_USAGE_INDEX_BUFFER_BIT | c.VK_BUFFER_USAGE_TRANSFER_DST_BIT,
            c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
        ) catch return;
        defer indexBuffer.destroy(&self.vulkanContext);

        indexBuffer.uploadData(&self.vulkanContext, indices) catch {
            std.debug.print("Failed to upload data to Index Buffer\n", .{});
            return;
        };

        var vertShader = assetManager.loadShader("assets/shaders/texture.vert", .Vertex) catch return;
        defer vertShader.release();

        var fragShader = assetManager.loadShader("assets/shaders/texture.frag", .Fragment) catch return;
        defer fragShader.release();

        var pipeline = blk: {
            var vertModule = VulkanShaderModule.new(&self.vulkanContext, vertShader.asset.spirvSize, vertShader.asset.spirvCode) catch return;
            defer vertModule.destroy(&self.vulkanContext);

            var fragModule = VulkanShaderModule.new(&self.vulkanContext, fragShader.asset.spirvSize, fragShader.asset.spirvCode) catch return;
            defer fragModule.destroy(&self.vulkanContext);

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
                descriptorSetGroup.layout.handle,
                modelDescriptorSetGroup.layout.handle,
            };

            break :blk VulkanPipeline.new(
                &self.vulkanContext,
                &self.renderPass,
                &vertModule,
                &fragModule,
                &attributes,
                &bindings,
                layouts,
            ) catch return;
        };
        defer pipeline.destroy(&self.vulkanContext);

        defer self.vulkanContext.device.wait();

        self.onCreate.dispatch(.{ .app = self });

        var time: f32 = GLFW.getTime();

        var frameIndex: u32 = 0;
        while (!self.window.shouldClose()) {
            GLFW.pollEvents();

            const newTime = GLFW.getTime();
            const deltaTime = newTime - time;
            time = newTime;

            self.onUpdate.dispatch(.{ .app = self, .deltaTime = deltaTime });

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
                beginInfo.framebuffer = self.framebuffers[imageIndex].handle;
                beginInfo.renderArea = .{
                    .offset = .{ .x = 0, .y = 0 },
                    .extent = .{ .width = self.swapchain.width, .height = self.swapchain.height },
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
                        descriptorSetGroup.sets[frameIndex].handle,
                        modelDescriptorSetGroup.sets[frameIndex].handle,
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

    fn recreateSwapchain(self: *Application) !void {
        var surfaceCapabilities: c.VkSurfaceCapabilitiesKHR = undefined;
        vkCheck(c.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(self.vulkanContext.device.physicalDevice, self.surface.handle, &surfaceCapabilities));
        if (surfaceCapabilities.currentExtent.width == 0 or surfaceCapabilities.currentExtent.height == 0) {
            return;
        }

        self.vulkanContext.device.wait();

        var oldSwapchain = self.swapchain;
        self.swapchain = try VulkanSwapchain.new(&self.vulkanContext, &self.surface, c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT, &oldSwapchain, self.allocator);
        oldSwapchain.destroy(&self.vulkanContext);

        self.renderPass.destroy(&self.vulkanContext);
        self.renderPass = try VulkanRenderPass.new(&self.vulkanContext, self.swapchain.format);

        for (0..self.framebuffers.len) |i| {
            self.framebuffers[i].destroy(&self.vulkanContext);
            self.depthbuffers[i].destroy(&self.vulkanContext);
        }
        self.allocator.free(self.framebuffers);
        self.allocator.free(self.depthbuffers);
        self.depthbuffers = try self.allocator.alloc(VulkanImage, self.swapchain.images.len);
        self.framebuffers = try self.allocator.alloc(VulkanFramebuffer, self.swapchain.images.len);

        for (0..self.framebuffers.len) |i| {
            self.depthbuffers[i] = try VulkanImage.new(
                &self.vulkanContext,
                &ImageData.empty(self.swapchain.width, self.swapchain.height, .Depth32),
                c.VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT,
            );
            const attachments = [_]c.VkImageView{
                self.swapchain.imageViews[i],
                self.depthbuffers[i].view,
            };
            self.framebuffers[i] = try VulkanFramebuffer.new(
                &self.vulkanContext,
                &self.renderPass,
                @intCast(attachments.len),
                &attachments,
                self.swapchain.width,
                self.swapchain.height,
            );
        }
    }
};
