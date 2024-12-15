const std = @import("std");
const vulkan = @import("../vulkan.zig");
const util = @import("../util.zig");
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
const GLSLangShaderStage = glslang.GLSLangShaderStage;
const RuntimeShader = glslang.RuntimeShader;
const SPVCContext = spvc.SPVCContext;

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
                image.destroy(self.manager.vulkanContext);
            },
            .pipeline => |*pipeline| {
                pipeline.destroy(self.manager.vulkanContext);
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
    vulkanContext: *const VulkanContext,
    spvcContext: *const SPVCContext,
    assets: StringHashMap(AssetEntry),

    allocator: Allocator,

    pub fn new(vulkanContext: *const VulkanContext, spvcContext: *const SPVCContext, allocator: Allocator) AssetManager {
        return .{
            .vulkanContext = vulkanContext,
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
            try self.assets.put(
                path,
                .{
                    .manager = self,
                    .asset = .{
                        .image = try Image.new(self.vulkanContext, path, .RGBA8),
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
                            self.vulkanContext,
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
