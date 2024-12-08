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

const Asset = union(enum) {
    image: VulkanImage,
    shader: RuntimeShader,
};

var data = struct {
    initialized: bool = false,
    ctx: *const VulkanContext = undefined,
    assets: StringHashMap(Asset) = undefined,
}{};

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

        var it = data.assets.valueIterator();
        while (it.next()) |asset| {
            switch (asset.*) {
                .image => |*image| {
                    image.destroy(&data.ctx.device);
                },
                .shader => |*shader| {
                    shader.destroy();
                },
            }
        }

        data.assets.deinit();

        data.initialized = true;
    }

    pub fn loadImage(path: []const u8, format: ImageFormat) !*const VulkanImage {
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

            try data.assets.put(path, .{ .image = image });
            break :blk data.assets.getPtr(path);
        };
        return &asset.?.image;
    }

    pub fn loadShader(path: []const u8, stage: GLSLangShaderStage) !*const RuntimeShader {
        const asset = data.assets.getPtr(path) orelse blk: {
            try data.assets.put(path, .{
                .shader = try RuntimeShader.fromFile(path, stage, data.ctx.allocator),
            });
            break :blk data.assets.getPtr(path);
        };
        return &asset.?.shader;
    }
};
