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
    manager: *const AssetManager,
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
                image.destroy(self.manager.vulkanContext);
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

pub const AssetManager = struct {
    vulkanContext: *const VulkanContext = undefined,
    assets: StringHashMap(AssetEntry) = undefined,

    allocator: Allocator,

    pub fn new(vulkanContext: *const VulkanContext, allocator: Allocator) AssetManager {
        return .{
            .vulkanContext = vulkanContext,
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

    pub fn loadImage(self: *AssetManager, path: []const u8, format: ImageFormat) !AssetHandle(VulkanImage) {
        const entry = self.assets.getPtr(path) orelse blk: {
            var imageData = try ImageData.load(path, format);
            defer imageData.destroy();

            const image = try VulkanImage.new(
                self.vulkanContext,
                &imageData,
                c.VK_IMAGE_USAGE_SAMPLED_BIT | c.VK_IMAGE_USAGE_TRANSFER_DST_BIT,
            );

            try image.uploadData(
                self.vulkanContext,
                &imageData,
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
        return AssetHandle(VulkanImage).new(entry.?, &entry.?.asset.image);
    }

    pub fn loadShader(self: *AssetManager, path: []const u8, stage: GLSLangShaderStage) !AssetHandle(RuntimeShader) {
        const entry = self.assets.getPtr(path) orelse blk: {
            try self.assets.put(
                path,
                .{
                    .manager = self,
                    .asset = .{
                        .shader = try RuntimeShader.fromFile(path, stage, self.allocator),
                    },
                },
            );
            break :blk self.assets.getPtr(path);
        };
        return AssetHandle(RuntimeShader).new(entry.?, &entry.?.asset.shader);
    }
};
