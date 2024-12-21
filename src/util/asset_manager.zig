const std = @import("std");
const vulkan = @import("../vulkan.zig");
const util = @import("../util.zig");
const gpu = @import("../gpu.zig");
const graphics = @import("../graphics.zig");
const glslang = @import("../glslang.zig");
const spvc = @import("../spvc.zig");
const c = @cImport(@cInclude("vulkan/vulkan.h"));

const Allocator = std.mem.Allocator;
const StringHashMap = std.hash_map.StringHashMap;
const Image = graphics.Image;
const Pipeline = graphics.Pipeline;
const VulkanContext = vulkan.VulkanContext;
const VulkanRenderPass = vulkan.VulkanRenderPass;
const VulkanCommandBuffer = vulkan.VulkanCommandBuffer;
const GLSLangShaderStage = glslang.GLSLangShaderStage;
const RuntimeShader = glslang.RuntimeShader;
const SPVCContext = spvc.SPVCContext;
const ImageData = util.ImageData;
const GPUAllocator = gpu.GPUAllocator;

const AssetEntry = struct {
    manager: *const AssetManager,
    refCount: usize = 1,
    asset: union(enum) {
        image: Image,
        pipeline: Pipeline,
    },

    pub fn release(self: *AssetEntry) void {
        self.refCount -= 1;

        if (self.refCount > 0) {
            return;
        }

        switch (self.asset) {
            .image => |*image| {
                image.destroy(self.manager.gpuAllocator);
            },
            .pipeline => |*pipeline| {
                pipeline.destroy(self.manager.gpuAllocator.context);
            },
        }
    }
};

fn AssetHandle(comptime T: type) type {
    return struct {
        entry: *AssetEntry,
        asset: *T,

        pub fn new(entry: *AssetEntry, asset: *T) @This() {
            entry.refCount += 1;
            return .{
                .entry = entry,
                .asset = asset,
            };
        }

        pub fn release(self: *@This()) void {
            self.entry.release();
        }
    };
}

pub const AssetManager = struct {
    gpuAllocator: *GPUAllocator,
    spvcContext: *const SPVCContext,
    assets: StringHashMap(AssetEntry),

    allocator: Allocator,

    pub fn new(gpuAllocator: *GPUAllocator, spvcContext: *const SPVCContext, allocator: Allocator) AssetManager {
        return .{
            .gpuAllocator = gpuAllocator,
            .spvcContext = spvcContext,
            .assets = StringHashMap(AssetEntry).init(allocator),

            .allocator = allocator,
        };
    }

    pub fn destroy(self: *AssetManager) void {
        self.clearAllAssets();

        self.assets.deinit();
    }

    pub fn clearAllAssets(self: *AssetManager) void {
        var it = self.assets.valueIterator();
        while (it.next()) |entry| {
            entry.release();
        }
        self.assets.clearAndFree();
    }

    pub fn clearUnusedAssets(self: *AssetManager) void {
        var assetsToRemove = std.ArrayList(*[]const u8).init(self.allocator);

        var it = self.assets.iterator();
        while (it.next()) |entry| {
            if (entry.value_ptr.refCount > 1) {
                continue;
            }

            entry.value_ptr.release();
            assetsToRemove.append(entry.key_ptr) catch {};
        }

        for (assetsToRemove.items) |item| {
            self.assets.remove(item.*);
        }
    }

    pub fn loadImage(self: *AssetManager, path: []const u8) !AssetHandle(Image) {
        const entry = self.assets.getPtr(path) orelse blk: {
            var data = try ImageData.load(path, .RGBA8);
            defer data.destroy();

            const image = try Image.new(
                self.gpuAllocator,
                &data,
                c.VK_IMAGE_USAGE_SAMPLED_BIT | c.VK_IMAGE_USAGE_TRANSFER_DST_BIT,
            );
            try image.uploadData(
                self.gpuAllocator,
                &data,
                c.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
                c.VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT,
            );

            try self.assets.put(
                path,
                .{
                    .manager = self,
                    .asset = .{
                        .image = image,
                    },
                },
            );
            break :blk self.assets.getPtr(path);
        };
        return AssetHandle(Image).new(entry.?, &entry.?.asset.image);
    }

    pub fn loadGraphicsPipeline(self: *AssetManager, renderPass: *const VulkanRenderPass, path: []const u8) !AssetHandle(Pipeline) {
        const entry = self.assets.getPtr(path) orelse blk: {
            const vertexShader = try std.fmt.allocPrint(self.allocator, "{s}.vert", .{path});
            defer self.allocator.free(vertexShader);

            const fragmentShader = try std.fmt.allocPrint(self.allocator, "{s}.frag", .{path});
            defer self.allocator.free(fragmentShader);

            try self.assets.put(
                path,
                .{
                    .manager = self,
                    .asset = .{
                        .pipeline = try Pipeline.graphicsPipeline(
                            self.gpuAllocator.context,
                            self.spvcContext,
                            renderPass,
                            vertexShader,
                            fragmentShader,
                            self.allocator,
                        ),
                    },
                },
            );
            break :blk self.assets.getPtr(path);
        };
        return AssetHandle(Pipeline).new(entry.?, &entry.?.asset.pipeline);
    }
};
