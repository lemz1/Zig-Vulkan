const std = @import("std");
const spvc = @import("../spvc.zig");
const c = @cImport(@cInclude("spirv_cross_c.h"));

const SPVCContext = spvc.SPVCContext;
const SPVCParsedIR = spvc.SPVCParsedIR;

pub const SPVCDecoration = enum(c.SpvDecoration) {
    RelaxedPrecision = c.SpvDecorationRelaxedPrecision,
    SpecId = c.SpvDecorationSpecId,
    Block = c.SpvDecorationBlock,
    BufferBlock = c.SpvDecorationBufferBlock,
    RowMajor = c.SpvDecorationRowMajor,
    ColMajor = c.SpvDecorationColMajor,
    ArrayStride = c.SpvDecorationArrayStride,
    MatrixStride = c.SpvDecorationMatrixStride,
    GLSLShared = c.SpvDecorationGLSLShared,
    GLSLPacked = c.SpvDecorationGLSLPacked,
    CPacked = c.SpvDecorationCPacked,
    BuiltIn = c.SpvDecorationBuiltIn,
    NoPerspective = c.SpvDecorationNoPerspective,
    Flat = c.SpvDecorationFlat,
    Patch = c.SpvDecorationPatch,
    Centroid = c.SpvDecorationCentroid,
    Sample = c.SpvDecorationSample,
    Invariant = c.SpvDecorationInvariant,
    Restrict = c.SpvDecorationRestrict,
    Aliased = c.SpvDecorationAliased,
    Volatile = c.SpvDecorationVolatile,
    Constant = c.SpvDecorationConstant,
    Coherent = c.SpvDecorationCoherent,
    NonWritable = c.SpvDecorationNonWritable,
    NonReadable = c.SpvDecorationNonReadable,
    Uniform = c.SpvDecorationUniform,
    UniformId = c.SpvDecorationUniformId,
    SaturatedConversion = c.SpvDecorationSaturatedConversion,
    Stream = c.SpvDecorationStream,
    Location = c.SpvDecorationLocation,
    Component = c.SpvDecorationComponent,
    Index = c.SpvDecorationIndex,
    Binding = c.SpvDecorationBinding,
    DescriptorSet = c.SpvDecorationDescriptorSet,
    Offset = c.SpvDecorationOffset,
    XfbBuffer = c.SpvDecorationXfbBuffer,
    XfbStride = c.SpvDecorationXfbStride,
    FuncParamAttr = c.SpvDecorationFuncParamAttr,
    FPRoundingMode = c.SpvDecorationFPRoundingMode,
    FPFastMathMode = c.SpvDecorationFPFastMathMode,
    LinkageAttributes = c.SpvDecorationLinkageAttributes,
    NoContraction = c.SpvDecorationNoContraction,
    InputAttachmentIndex = c.SpvDecorationInputAttachmentIndex,
    Alignment = c.SpvDecorationAlignment,
    MaxByteOffset = c.SpvDecorationMaxByteOffset,
    AlignmentId = c.SpvDecorationAlignmentId,
    MaxByteOffsetId = c.SpvDecorationMaxByteOffsetId,
    NoSignedWrap = c.SpvDecorationNoSignedWrap,
    NoUnsignedWrap = c.SpvDecorationNoUnsignedWrap,
    WeightTextureQCOM = c.SpvDecorationWeightTextureQCOM,
    BlockMatchTextureQCOM = c.SpvDecorationBlockMatchTextureQCOM,
    BlockMatchSamplerQCOM = c.SpvDecorationBlockMatchSamplerQCOM,
    ExplicitInterpAMD = c.SpvDecorationExplicitInterpAMD,
    PerVertexKHR = c.SpvDecorationPerVertexKHR,
    NonUniform = c.SpvDecorationNonUniform,
    RestrictPointer = c.SpvDecorationRestrictPointer,
    AliasedPointer = c.SpvDecorationAliasedPointer,
    SIMTCallINTEL = c.SpvDecorationSIMTCallINTEL,
    ReferencedIndirectlyINTEL = c.SpvDecorationReferencedIndirectlyINTEL,
    ClobberINTEL = c.SpvDecorationClobberINTEL,
    SideEffectsINTEL = c.SpvDecorationSideEffectsINTEL,
    VectorComputeVariableINTEL = c.SpvDecorationVectorComputeVariableINTEL,
    FuncParamIOKindINTEL = c.SpvDecorationFuncParamIOKindINTEL,
    VectorComputeFunctionINTEL = c.SpvDecorationVectorComputeFunctionINTEL,
    StackCallINTEL = c.SpvDecorationStackCallINTEL,
    GlobalVariableOffsetINTEL = c.SpvDecorationGlobalVariableOffsetINTEL,
    CounterBuffer = c.SpvDecorationCounterBuffer,
    UserSemantic = c.SpvDecorationUserSemantic,
    UserTypeGOOGLE = c.SpvDecorationUserTypeGOOGLE,
    FunctionRoundingModeINTEL = c.SpvDecorationFunctionRoundingModeINTEL,
    FunctionDenormModeINTEL = c.SpvDecorationFunctionDenormModeINTEL,
    RegisterINTEL = c.SpvDecorationRegisterINTEL,
    MemoryINTEL = c.SpvDecorationMemoryINTEL,
    NumbanksINTEL = c.SpvDecorationNumbanksINTEL,
    BankwidthINTEL = c.SpvDecorationBankwidthINTEL,
    MaxPrivateCopiesINTEL = c.SpvDecorationMaxPrivateCopiesINTEL,
    SinglepumpINTEL = c.SpvDecorationSinglepumpINTEL,
    DoublepumpINTEL = c.SpvDecorationDoublepumpINTEL,
    MaxReplicatesINTEL = c.SpvDecorationMaxReplicatesINTEL,
    SimpleDualPortINTEL = c.SpvDecorationSimpleDualPortINTEL,
    MergeINTEL = c.SpvDecorationMergeINTEL,
    BankBitsINTEL = c.SpvDecorationBankBitsINTEL,
    ForcePow2DepthINTEL = c.SpvDecorationForcePow2DepthINTEL,
    BurstCoalesceINTEL = c.SpvDecorationBurstCoalesceINTEL,
    CacheSizeINTEL = c.SpvDecorationCacheSizeINTEL,
    DontStaticallyCoalesceINTEL = c.SpvDecorationDontStaticallyCoalesceINTEL,
    PrefetchINTEL = c.SpvDecorationPrefetchINTEL,
    StallEnableINTEL = c.SpvDecorationStallEnableINTEL,
    FuseLoopsInFunctionINTEL = c.SpvDecorationFuseLoopsInFunctionINTEL,
    AliasScopeINTEL = c.SpvDecorationAliasScopeINTEL,
    NoAliasINTEL = c.SpvDecorationNoAliasINTEL,
    BufferLocationINTEL = c.SpvDecorationBufferLocationINTEL,
    IOPipeStorageINTEL = c.SpvDecorationIOPipeStorageINTEL,
    FunctionFloatingPointModeINTEL = c.SpvDecorationFunctionFloatingPointModeINTEL,
    SingleElementVectorINTEL = c.SpvDecorationSingleElementVectorINTEL,
    VectorComputeCallableFunctionINTEL = c.SpvDecorationVectorComputeCallableFunctionINTEL,
    MediaBlockIOINTEL = c.SpvDecorationMediaBlockIOINTEL,
    Max = c.SpvDecorationMax,
};

pub const SPVCCompiler = struct {
    handle: c.spvc_compiler,

    pub fn new(context: *const SPVCContext, parsedIR: *const SPVCParsedIR) !SPVCCompiler {
        var compiler: c.spvc_compiler = undefined;
        switch (c.spvc_context_create_compiler(context.handle, c.SPVC_BACKEND_NONE, parsedIR.handle, c.SPVC_CAPTURE_MODE_TAKE_OWNERSHIP, &compiler)) {
            c.SPVC_SUCCESS => {},
            else => {
                std.debug.print("[SPIRV-Cross] Could not create Compiler\n", .{});
                return error.CreateSPVCCompiler;
            },
        }

        return .{
            .handle = compiler,
        };
    }

    pub fn getDecoration(self: *const SPVCCompiler, id: u32, decoration: SPVCDecoration) u32 {
        return c.spvc_compiler_get_decoration(self.handle, id, @intFromEnum(decoration));
    }
};
