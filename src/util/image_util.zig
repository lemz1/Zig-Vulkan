const c = @cImport({
    @cInclude("stb_image/stb_image.h");
    @cInclude("vulkan/vulkan.h");
});

const ImageDataError = error{
    LoadImage,
};

pub const ImageFormat = enum(c.VkFormat) {
    RGBA8 = c.VK_FORMAT_R8G8B8A8_UNORM,
    RGBA32 = c.VK_FORMAT_R32G32B32A32_SFLOAT,
};

pub const ImageData = struct {
    width: u32,
    height: u32,
    channels: u32,
    format: ImageFormat,
    size: usize,
    pixels: ?*anyopaque,

    pub fn empty(width: u32, height: u32, format: ImageFormat) ImageData {
        return .{
            .width = width,
            .height = height,
            .channels = 4,
            .format = format,
            .size = width * height * 4 * switch (format) {
                .RGBA8 => @sizeOf(u8),
                .RGBA32 => @sizeOf(f32),
            },
            .pixels = null,
        };
    }

    pub fn load(path: []const u8, format: ImageFormat) !ImageData {
        var width: i32 = undefined;
        var height: i32 = undefined;
        var channels: i32 = undefined;
        const pixels: ?*anyopaque = switch (format) {
            .RGBA8 => c.stbi_load(path.ptr, &width, &height, &channels, 4),
            .RGBA32 => c.stbi_loadf(path.ptr, &width, &height, &channels, 4),
        };

        if (pixels == null) {
            return ImageDataError.LoadImage;
        }

        const uWidth: u32 = @intCast(width);
        const uHeight: u32 = @intCast(height);

        const pixelSize: usize = switch (format) {
            .RGBA8 => @sizeOf(u8) * 4,
            .RGBA32 => @sizeOf(f32) * 4,
        };
        const size: usize = uWidth * uHeight * pixelSize;

        return .{
            .width = uWidth,
            .height = uHeight,
            .channels = 4,
            .format = format,
            .size = size,
            .pixels = pixels,
        };
    }

    pub fn destroy(self: *ImageData) void {
        if (self.pixels != null) {
            c.stbi_image_free(self.pixels.?);
        }
    }
};
