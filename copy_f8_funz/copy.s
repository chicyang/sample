.amdgcn_target "amdgcn-amd-amdhsa--gfx942"
.text
.protected Copy
.globl Copy
.p2align 8
.type Copy,@function
.section .rodata,#alloc
.p2align 6
.amdhsa_kernel Copy
  .amdhsa_user_sgpr_kernarg_segment_ptr 1
  .amdhsa_accum_offset 8 // accvgpr offset
  .amdhsa_next_free_vgpr 8 // vgprs
  .amdhsa_next_free_sgpr 32 // sgprs
  .amdhsa_group_segment_fixed_size 32 // lds bytes
  .amdhsa_private_segment_fixed_size 0
  .amdhsa_system_sgpr_workgroup_id_x 1
  .amdhsa_system_sgpr_workgroup_id_y 1
  .amdhsa_system_sgpr_workgroup_id_z 1
  .amdhsa_system_vgpr_workitem_id 0
  .amdhsa_float_denorm_mode_32 3
  .amdhsa_float_denorm_mode_16_64 3
.end_amdhsa_kernel
.text

.amdgpu_metadata
---
amdhsa.kernels:
- .agpr_count: 0
  .args:
  - .address_space: global
    .offset: 0
    .size: 8
    .value_kind: global_buffer
  - .address_space: global
    .offset: 8
    .size: 8
    .value_kind: global_buffer
  - .offset: 16
    .size: 4
    .value_kind: by_value
  .group_segment_fixed_size: 16
  .kernarg_segment_align: 8
  .kernarg_segment_size: 32
  .max_flat_workgroup_size: 256
  .name: Copy
  .private_segment_fixed_size: 0
  .sgpr_count: 32
  .symbol: Copy.kd
  .vgpr_count: 8
  .wavefront_size: 64
amdhsa.version:
- 1
- 1

.end_amdgpu_metadata

.set vgprSerial, 0
.set vgprValue,  1
.set vgprOffset, 2
.set vgprTmp,    3

.set sgprKernelArg,   0
.set sgprWorkGroup0,  2
.set sgprWorkGroup1,  3
.set sgprWorkGroup2,  4
.set sgprSizeLength,  5
.set sgprAddressOut,  6
.set sgprAddressIn,   8
.set sgprSrc,        12
.set sgprDst,        16
.set sgprTmp,        20

.set Srd127_96, 0x00020000


Copy:
/* Load kernel args */
s_load_dwordx2 s[sgprAddressOut:sgprAddressOut+1], s[sgprKernelArg:sgprKernelArg+1], 0
s_load_dwordx2 s[sgprAddressIn:sgprAddressIn+1], s[sgprKernelArg:sgprKernelArg+1], 8
s_load_dword s[sgprSizeLength], s[sgprKernelArg:sgprKernelArg+1], 16
s_waitcnt lgkmcnt(0)


# s_mul_i32 s[sgprTmp], s[sgprWorkGroup0], s[sgprTmp]

/* init_param */
s_mov_b32 s[sgprSrc+0], s[sgprAddressIn+0]
s_mov_b32 s[sgprSrc+1], s[sgprAddressIn+1]
s_mov_b32 s[sgprSrc+2], s[sgprSizeLength]
s_mov_b32 s[sgprSrc+3], Srd127_96

s_mov_b32 s[sgprDst+0], s[sgprAddressOut+0]
s_mov_b32 s[sgprDst+1], s[sgprAddressOut+1]
s_mov_b32 s[sgprDst+2], s[sgprSizeLength]
s_mov_b32 s[sgprDst+3], Srd127_96

v_lshlrev_b32 v[vgprOffset], 0, v[vgprSerial]

buffer_load_ubyte v[vgprValue], v[vgprOffset], s[sgprSrc:sgprSrc+3], 0 offen offset:0
s_waitcnt vmcnt(0)

break:

buffer_store_byte v[vgprValue], v[vgprOffset], s[sgprDst:sgprDst+3], 0 offen offset:0
s_waitcnt vmcnt(0)

s_endpgm
.LCopy_end:
.size Copy, .LCopy_end - Copy
