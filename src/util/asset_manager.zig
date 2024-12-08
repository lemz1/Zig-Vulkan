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

const AssetEntry = struct {
    refCount: usize = 1,
    asset: union(enum) {
        image: VulkanImage,
        shader: RuntimeShader,
    },

    pub fn release(self: *AssetEntry) void {
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

var data = struct {
    initialized: bool = false,
    ctx: *const VulkanContext = undefined,
    assets: StringHashMap(AssetEntry) = undefined,
}{};

pub const AssetManager = struct {
    pub fn init(ctx: *const VulkanContext) void {
        if (data.initialized) {
            return;
        }

        data.ctx = ctx;
        data.assets = StringHashMap(AssetEntry).init(ctx.allocator);

        data.initialized = true;
    }

    pub fn deinit() void {
        if (!data.initialized) {
            return;
        }

        clearAllAssets();

        data.assets.deinit();

        data.initialized = true;
    }

    pub fn clearAllAssets() void {
        var it = data.assets.valueIterator();
        while (it.next()) |entry| {
            entry.release();
        }
        data.assets.clearAndFree();
    }

    pub fn clearUnusedAssets() void {
        var assetsToRemove = std.ArrayList(*[]const u8).init(data.ctx.allocator);

        var it = data.assets.iterator();
        while (it.next()) |entry| {
            if (entry.value_ptr.refCount > 1) {
                continue;
            }

            entry.value_ptr.release();
            assetsToRemove.append(entry.key_ptr) catch {};
        }

        for (assetsToRemove.items) |item| {
            data.assets.remove(item.*);
        }
    }

    pub fn loadImage(path: []const u8, format: ImageFormat) !AssetHandle(VulkanImage) {
        const entry = data.assets.getPtr(path) orelse blk: {
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
        return AssetHandle(VulkanImage).new(entry.?, &entry.?.asset.image);
    }

    pub fn loadShader(path: []const u8, stage: GLSLangShaderStage) !AssetHandle(RuntimeShader) {
        const entry = data.assets.getPtr(path) orelse blk: {
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
        return AssetHandle(RuntimeShader).new(entry.?, &entry.?.asset.shader);
    }
};
