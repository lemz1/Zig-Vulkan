const vulkan = @import("../vulkan.zig");
const util = @import("../util.zig");
const c = @cImport(@cInclude("vulkan/vulkan.h"));

const VulkanContext = vulkan.VulkanContext;
const VulkanImage = vulkan.VulkanImage;
const ImageData = util.ImageData;
const ImageFormat = util.ImageFormat;

pub const Image = struct {
    image: VulkanImage,

    pub fn new(vulkanContext: *const VulkanContext, path: []const u8, format: ImageFormat) !Image {
        var data = try ImageData.load(path, format);
        defer data.destroy();

        const image = try VulkanImage.new(
            vulkanContext,
            &data,
            c.VK_IMAGE_USAGE_SAMPLED_BIT | c.VK_IMAGE_USAGE_TRANSFER_DST_BIT,
        );

        try image.uploadData(
            vulkanContext,
            &data,
            c.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
            c.VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT,
        );

        return .{
            .image = image,
        };
    }

    pub fn destroy(self: *Image, vulkanContext: *const VulkanContext) void {
        self.image.destroy(vulkanContext);
    }
};
