const c = @cImport(@cInclude("vulkan/vulkan.h"));

pub const VulkanQueue = struct {
    queue: c.VkQueue,
    familyIndex: u32,
};
