const std = @import("std");
const vulkan = @import("../vulkan.zig");
const util = @import("../util.zig");
const glslang = @import("../glslang.zig");
const c = @cImport(@cInclude("vulkan/vulkan.h"));

const Allocator = std.mem.Allocator;
const StringHashMap = std.hash_map.StringHashMap;
const ImageData = util.ImageData;
const ImageFormat = util.ImageFormat;
const VulkanContext = vulkan.VulkanContext;
const VulkanImage = vulkan.VulkanImage;
const GLSLangShaderStage = glslang.GLSLangShaderStage;
const RuntimeShader = glslang.RuntimeShader;

var data = struct {
    initialized: bool = false,
    ctx: *const VulkanContext = undefined,
    assets: StringHashMap(Asset) = undefined,
}{};

const AssetType = union(enum) {
    image: VulkanImage,
    shader: RuntimeShader,
};

const Asset = struct {
    refCount: usize = 1,
    asset: AssetType,

    pub fn release(self: *Asset) void {
        self.refCount -= 1;

        if (self.refCount > 0) {
            return;
        }

        switch (self.asset) {
            .image => |*image| {
                image.destroy(&data.ctx.device);
            },
            .shader => |*shader| {
                shader.destroy();
            },
        }
    }
};

pub const AssetManager = struct {
    pub fn init(ctx: *const VulkanContext) void {
        if (data.initialized) {
            return;
        }

        data.ctx = ctx;
        data.assets = StringHashMap(Asset).init(ctx.allocator);

        data.initialized = true;
    }

    pub fn deinit() void {
        if (!data.initialized) {
            return;
        }

        clearAllAssets();

        data.assets.deinit();

        data.initialized = false;
    }

    pub fn clearUnusedAssets() void {
        var assetsToRemove = std.ArrayList(*[]const u8).init(data.ctx.allocator);
        defer assetsToRemove.deinit();

        var it = data.assets.iterator();
        while (it.next()) |asset| {
            if (asset.value_ptr.refCount > 1) {
                continue;
            }

            asset.value_ptr.release();
            assetsToRemove.append(asset.key_ptr) catch {};
        }

        for (assetsToRemove.items) |item| {
            _ = data.assets.remove(item.*);
        }
    }

    pub fn clearAllAssets() void {
        var it = data.assets.valueIterator();
        while (it.next()) |asset| {
            asset.release();
        }

        data.assets.clearAndFree();
    }

    pub fn loadImage(path: []const u8, format: ImageFormat) !*Asset {
        const asset = data.assets.getPtr(path) orelse blk: {
            var imageData = try ImageData.load(path, format);
            defer imageData.destroy();

            const image = try VulkanImage.new(
                &data.ctx.device,
                &imageData,
                c.VK_IMAGE_USAGE_SAMPLED_BIT | c.VK_IMAGE_USAGE_TRANSFER_DST_BIT,
            );

            try image.uploadData(
                &data.ctx.device,
                &imageData,
                c.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
                c.VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT,
            );

            try data.assets.put(
                path,
                .{
                    .asset = .{
                        .image = image,
                    },
                },
            );
            break :blk data.assets.getPtr(path);
        };
        asset.?.refCount += 1;
        return asset.?;
    }

    pub fn loadShader(path: []const u8, stage: GLSLangShaderStage) !*Asset {
        const asset = data.assets.getPtr(path) orelse blk: {
            try data.assets.put(
                path,
                .{
                    .asset = .{
                        .shader = try RuntimeShader.fromFile(path, stage, data.ctx.allocator),
                    },
                },
            );
            break :blk data.assets.getPtr(path);
        };
        asset.?.refCount += 1;
        return asset.?;
    }
};
