const std = @import("std");
const spvc = @import("../spvc.zig");
const c = @cImport(@cInclude("spirv_cross_c.h"));

const SPVCCompiler = spvc.SPVCCompiler;

const spvcCheck = @import("base.zig").spvcCheck;

pub const SPVCBaseType = enum(c.spvc_basetype) {
    Unknown = c.SPVC_BASETYPE_UNKNOWN,
    Void = c.SPVC_BASETYPE_VOID,
    Boolean = c.SPVC_BASETYPE_BOOLEAN,
    Int8 = c.SPVC_BASETYPE_INT8,
    UInt8 = c.SPVC_BASETYPE_UINT8,
    Int16 = c.SPVC_BASETYPE_INT16,
    UInt16 = c.SPVC_BASETYPE_UINT16,
    Int32 = c.SPVC_BASETYPE_INT32,
    UInt32 = c.SPVC_BASETYPE_UINT32,
    Int64 = c.SPVC_BASETYPE_INT64,
    UInt64 = c.SPVC_BASETYPE_UINT64,
    AtomicCounter = c.SPVC_BASETYPE_ATOMIC_COUNTER,
    Float16 = c.SPVC_BASETYPE_FP16,
    Float32 = c.SPVC_BASETYPE_FP32,
    Float64 = c.SPVC_BASETYPE_FP64,
    Struct = c.SPVC_BASETYPE_STRUCT,
    Image = c.SPVC_BASETYPE_IMAGE,
    SampledImage = c.SPVC_BASETYPE_SAMPLED_IMAGE,
    Sampler = c.SPVC_BASETYPE_SAMPLER,
    AccelerationStructure = c.SPVC_BASETYPE_ACCELERATION_STRUCTURE,
    IntMax = c.SPVC_BASETYPE_INT_MAX,
};

pub const SPVCType = struct {
    handle: c.spvc_type,

    pub fn new(compiler: *const SPVCCompiler, typeId: c.spvc_type_id) !SPVCType {
        const @"type" = c.spvc_compiler_get_type_handle(compiler.handle, typeId) orelse return error.GetSPVCType;
        return .{
            .handle = @"type",
        };
    }

    pub fn getBaseType(self: *const SPVCType) SPVCBaseType {
        return @enumFromInt(c.spvc_type_get_basetype(self.handle));
    }

    pub fn getVectorSize(self: *const SPVCType) u32 {
        return c.spvc_type_get_vector_size(self.handle);
    }

    pub fn getNumDimensions(self: *const SPVCType) u32 {
        return c.spvc_type_get_num_array_dimensions(self.handle);
    }

    pub fn getDimensions(self: *const SPVCType, dimension: u32) u32 {
        return c.spvc_type_get_array_dimension(self.handle, dimension);
    }
};
