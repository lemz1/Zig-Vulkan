const c = @cImport({
    @cInclude("stb_image/stb_image.h");
    @cInclude("vulkan/vulkan.h");
});

const ImageDataError = error{
    LoadImage,
    InvalidFormat,
};

pub const ImageFormat = enum(c.VkFormat) {
    RGBA8 = c.VK_FORMAT_R8G8B8A8_UNORM,
    RGBA32 = c.VK_FORMAT_R32G32B32A32_SFLOAT,
    Depth32 = c.VK_FORMAT_D32_SFLOAT,
};

pub const ImageData = struct {
    width: u32,
    height: u32,
    channels: u32,
    format: ImageFormat,
    size: usize,
    pixels: ?*anyopaque,

    pub fn empty(width: u32, height: u32, format: ImageFormat) ImageData {
        const channels: u32 = switch (format) {
            .RGBA8, .RGBA32 => 4,
            .Depth32 => 1,
        };

        const sizeOfPixel: u32 = switch (format) {
            .RGBA8 => @sizeOf(u8),
            .RGBA32, .Depth32 => @sizeOf(f32),
        };

        return .{
            .width = width,
            .height = height,
            .channels = channels,
            .format = format,
            .size = width * height * channels * sizeOfPixel,
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
            else => return ImageDataError.InvalidFormat,
        };

        if (pixels == null) {
            return ImageDataError.LoadImage;
        }

        const uWidth: u32 = @intCast(width);
        const uHeight: u32 = @intCast(height);

        const pixelSize: usize = switch (format) {
            .RGBA8 => @sizeOf(u8) * 4,
            .RGBA32, .Depth32 => @sizeOf(f32) * 4,
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
