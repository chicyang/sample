.amdgcn_target "amdgcn-amd-amdhsa--gfx942"
.text
.protected MatMul
.globl MatMul
.p2align 8
.type MatMul,@function
.section .rodata,#alloc
.p2align 6
.amdhsa_kernel MatMul
  .amdhsa_user_sgpr_kernarg_segment_ptr 1
  .amdhsa_accum_offset 44 // accvgpr offset
  .amdhsa_next_free_vgpr 52 // vgprs
  .amdhsa_next_free_sgpr 32 // sgprs
  .amdhsa_group_segment_fixed_size 4096 // lds bytes
  .amdhsa_private_segment_fixed_size 0
  .amdhsa_system_sgpr_workgroup_id_x 1
  .amdhsa_system_sgpr_workgroup_id_y 1
  .amdhsa_system_sgpr_workgroup_id_z 1
  .amdhsa_system_vgpr_workitem_id 2
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
  - .address_space: global
    .offset: 16
    .size: 8
    .value_kind: global_buffer
  - .offset: 24
    .size: 4
    .value_kind: by_value
  - .offset: 28
    .size: 4
    .value_kind: by_value
  - .offset: 32
    .size: 4
    .value_kind: by_value
  - .offset: 36
    .size: 4
    .value_kind: by_value
  .group_segment_fixed_size: 4096
  .kernarg_segment_align: 8
  .kernarg_segment_size: 40
  .max_flat_workgroup_size: 256
  .name: MatMul
  .private_segment_fixed_size: 0
  .sgpr_count: 32
  .symbol: MatMul.kd
  .vgpr_count: 40
  .wavefront_size: 64
  .enable_vgpr_workitem_id: 2
amdhsa.version:
- 1
- 1

.end_amdgpu_metadata

.set vgprSerial,      0
.set vgprBaseOffset,  1  // in one warp
.set vgprIndexT,      2  // tile
.set vgprIndexU,      3  // unroll
.set vgprValueA,      4
.set vgprValueB,     12
.set vgprValueC,     20
.set vgprLDSAddrA,   28
.set vgprLDSAddrB,   30
.set vgprGLBOffset,  32
.set vgprGLBOffsetA, 34
.set vgprGLBOffsetB, 36
.set vgprWaveYIdx,   38
.set vgprWaveXIdx,   39
.set vgprTmp,        40
.set vgprTmp1,       41


.set sgprKernelArg,   0
.set sgprWorkGroup0,  2
.set sgprWorkGroup1,  3
.set sgprWorkGroup2,  4
.set sgprSizeM,       5
.set sgprSizeN,       6
.set sgprSizeK,       7
.set sgprAddressC,    8
.set sgprAddressA,   10
.set sgprAddressB,   12

.set sgprSrcA,       16
.set sgprSrcB,       20
.set sgprDstC,       24
.set sgprTmp,        28
.set sgprIterK,      30
.set sgprInnerIterK, 31

.set Srd127_96, 0x00020000


MatMul:
/* Load kernel args */
s_load_dwordx2 s[sgprAddressC:sgprAddressC+1], s[sgprKernelArg:sgprKernelArg+1], 0
s_load_dwordx2 s[sgprAddressA:sgprAddressA+1], s[sgprKernelArg:sgprKernelArg+1], 8
s_load_dwordx2 s[sgprAddressB:sgprAddressB+1], s[sgprKernelArg:sgprKernelArg+1], 16
s_load_dword s[sgprSizeM], s[sgprKernelArg:sgprKernelArg+1], 24 
s_load_dword s[sgprSizeN], s[sgprKernelArg:sgprKernelArg+1], 28
s_load_dword s[sgprSizeK], s[sgprKernelArg:sgprKernelArg+1], 32
s_load_dword s[sgprIterK], s[sgprKernelArg:sgprKernelArg+1], 36
s_waitcnt lgkmcnt(0)

/* init_param */
s_mul_i32 s[sgprTmp], s[sgprSizeK], s[sgprSizeM]
s_mov_b32 s[sgprSrcA+0], s[sgprAddressA+0]
s_mov_b32 s[sgprSrcA+1], s[sgprAddressA+1]
s_mov_b32 s[sgprSrcA+2], s[sgprTmp]
s_mov_b32 s[sgprSrcA+3], Srd127_96

s_mul_i32 s[sgprTmp], s[sgprSizeK], s[sgprSizeN]
s_mov_b32 s[sgprSrcB+0], s[sgprAddressB+0]
s_mov_b32 s[sgprSrcB+1], s[sgprAddressB+1]
s_mov_b32 s[sgprSrcB+2], s[sgprTmp]
s_mov_b32 s[sgprSrcB+3], Srd127_96

s_mul_i32 s[sgprTmp], s[sgprSizeM], s[sgprSizeN]
s_lshl_b32 s[sgprTmp], s[sgprTmp], 2 // fp32: 4 bytes, total size = 4 * M * N
s_mov_b32 s[sgprDstC+0], s[sgprAddressC+0]
s_mov_b32 s[sgprDstC+1], s[sgprAddressC+1]
s_mov_b32 s[sgprDstC+2], s[sgprTmp]
s_mov_b32 s[sgprDstC+3], Srd127_96

v_and_b32 v[vgprIndexT], v[vgprSerial], 15
v_lshrrev_b32 v[vgprIndexU], 4, v[vgprSerial]
v_and_b32 v[vgprIndexU], v[vgprIndexU], 3

v_mul_u32_u24 v[vgprTmp], v[vgprIndexT], s[sgprSizeK]
v_mul_u32_u24 v[vgprBaseOffset], 8, v[vgprIndexU]
v_add_u32 v[vgprBaseOffset], v[vgprBaseOffset], v[vgprTmp]

// 4 wavefronts in one workgroup:
// 1st wavefront (WaveYIdx=0,WaveXIdx=0)
// 2nd wavefront (WaveYIdx=0,WaveXIdx=1)
// 3rd wavefront (WaveYIdx=1,WaveXIdx=0)
// 4th wavefront (WaveYIdx=1,WaveXIdx=1)
v_lshrrev_b32 v[vgprTmp], 6, v[vgprSerial]
v_and_b32 v[vgprWaveYIdx], 2, v[vgprTmp]
v_lshrrev_b32 v[vgprWaveYIdx], 1, v[vgprWaveYIdx]
v_and_b32 v[vgprWaveXIdx], 1, v[vgprTmp]

v_mul_u32_u24 v[vgprTmp], v[vgprWaveYIdx], 16
v_mul_u32_u24 v[vgprTmp], v[vgprTmp], s[sgprSizeK]
v_add_u32 v[vgprGLBOffset], v[vgprBaseOffset], v[vgprTmp]
v_mul_u32_u24 v[vgprTmp], v[vgprWaveXIdx], 2*16
v_add_u32 v[vgprGLBOffset], v[vgprGLBOffset], v[vgprTmp]

s_mul_i32 s[sgprTmp], s[sgprWorkGroup1], 2*16
s_mul_i32 s[sgprTmp], s[sgprTmp], s[sgprSizeK]
v_add_u32 v[vgprGLBOffsetA], v[vgprGLBOffset], s[sgprTmp]
s_mul_i32 s[sgprTmp], s[sgprWorkGroup0], 2*16
s_mul_i32 s[sgprTmp], s[sgprTmp], s[sgprSizeK]
v_add_u32 v[vgprGLBOffsetB], v[vgprGLBOffset], s[sgprTmp]

// init acc
v_accvgpr_write acc0, 0x0
v_accvgpr_write acc1, 0x0
v_accvgpr_write acc2, 0x0
v_accvgpr_write acc3, 0x0
s_branch outer_loop_K

update_offset:
v_add_u32 v[vgprGLBOffsetA], 64, v[vgprGLBOffsetA]
v_add_u32 v[vgprGLBOffsetB], 64, v[vgprGLBOffsetB]
s_barrier

outer_loop_K:
buffer_load_dwordx2 v[vgprValueA+0:vgprValueA+1], v[vgprGLBOffsetA], s[sgprSrcA:sgprSrcA+3], 0 offen offset:0 // one workgroup loads (m=32,k=64)
buffer_load_dwordx2 v[vgprValueB+0:vgprValueB+1], v[vgprGLBOffsetB], s[sgprSrcB:sgprSrcB+3], 0 offen offset:0 // one workgroup loads (n=32,k=64)
s_waitcnt vmcnt(0)

v_lshlrev_b32 v[vgprTmp], 3, v[vgprSerial]
ds_write_b64 v[vgprTmp], v[vgprValueA+0:vgprValueA+1] offset:0
ds_write_b64 v[vgprTmp], v[vgprValueB+0:vgprValueB+1] offset:0x800 //32*64=0x800
s_waitcnt lgkmcnt(0)
s_barrier

inner_loop_K_init:
s_movk_i32 s[sgprInnerIterK], 1
v_and_b32 v[vgprTmp1], 63, v[vgprSerial]
v_mul_u32_u24 v[vgprTmp1], 8, v[vgprTmp1]
v_mul_u32_u24 v[vgprTmp], 64*16, v[vgprWaveYIdx]
v_add_u32 v[vgprLDSAddrA], v[vgprTmp], v[vgprTmp1]
v_mul_u32_u24 v[vgprTmp], 64*16, v[vgprWaveXIdx]
v_add_u32 v[vgprLDSAddrB], v[vgprTmp], v[vgprTmp1]
s_branch inner_loop_K

update_inner_loop_K:
s_add_u32 s[sgprInnerIterK], s[sgprInnerIterK], 1
v_add_u32 v[vgprLDSAddrA], 32*16, v[vgprLDSAddrA]
v_add_u32 v[vgprLDSAddrB], 32*16, v[vgprLDSAddrB]

inner_loop_K:
ds_read_b64 v[vgprValueA+0:vgprValueA+1], v[vgprLDSAddrA] offset:0
ds_read_b64 v[vgprValueB+0:vgprValueB+1], v[vgprLDSAddrB] offset:0x800
s_waitcnt lgkmcnt(0)

v_mfma_f32_16x16x32_fp8_fp8 acc[0:3], v[vgprValueB+0:vgprValueB+1], v[vgprValueA+0:vgprValueA+1], acc[0:3]

// check condiction
s_cmp_le_i32 s[sgprInnerIterK], 1
s_cbranch_scc1 update_inner_loop_K

s_sub_u32 s[sgprIterK], s[sgprIterK], s[sgprInnerIterK]
// check condiction
s_cmp_gt_i32 s[sgprIterK], 1
s_cbranch_scc1 update_offset

s_nop 7
v_accvgpr_read_b32 v[vgprValueC+0], acc0
v_accvgpr_read_b32 v[vgprValueC+1], acc1
v_accvgpr_read_b32 v[vgprValueC+2], acc2
v_accvgpr_read_b32 v[vgprValueC+3], acc3
s_nop 7

v_and_b32 v[vgprIndexU], v[vgprSerial], 15
v_lshrrev_b32 v[vgprIndexT], 4, v[vgprSerial]
v_and_b32 v[vgprIndexT], v[vgprIndexT], 3
v_lshlrev_b32 v[vgprIndexT], 2, v[vgprIndexT]
v_mul_u32_u24 v[vgprBaseOffset], v[vgprIndexT], s[sgprSizeM]
v_add_u32 v[vgprBaseOffset], v[vgprBaseOffset], v[vgprIndexU]

v_mul_u32_u24 v[vgprTmp], v[vgprWaveYIdx], 16
v_add_u32 v[vgprBaseOffset], v[vgprBaseOffset], v[vgprTmp]
v_mul_u32_u24 v[vgprTmp], v[vgprWaveXIdx], 16
v_mul_u32_u24 v[vgprTmp], v[vgprTmp], s[sgprSizeM]
v_add_u32 v[vgprBaseOffset], v[vgprBaseOffset], v[vgprTmp]

s_mul_i32 s[sgprTmp], s[sgprWorkGroup0], s[sgprSizeM]
s_add_i32 s[sgprTmp], s[sgprTmp], s[sgprWorkGroup1]
s_mul_i32 s[sgprTmp], s[sgprTmp], 32
v_add_u32 v[vgprBaseOffset], v[vgprBaseOffset], s[sgprTmp]

v_lshlrev_b32 v[vgprBaseOffset], 2, v[vgprBaseOffset] //fp32: 4 bytes

v_lshlrev_b32 v[vgprTmp], 2, s[sgprSizeM]
buffer_store_dword v[vgprValueC+0], v[vgprBaseOffset], s[sgprDstC:sgprDstC+3], 0 offen offset:0
v_add_u32 v[vgprBaseOffset], v[vgprBaseOffset], v[vgprTmp]
buffer_store_dword v[vgprValueC+1], v[vgprBaseOffset], s[sgprDstC:sgprDstC+3], 0 offen offset:0
v_add_u32 v[vgprBaseOffset], v[vgprBaseOffset], v[vgprTmp]
buffer_store_dword v[vgprValueC+2], v[vgprBaseOffset], s[sgprDstC:sgprDstC+3], 0 offen offset:0
v_add_u32 v[vgprBaseOffset], v[vgprBaseOffset], v[vgprTmp]
buffer_store_dword v[vgprValueC+3], v[vgprBaseOffset], s[sgprDstC:sgprDstC+3], 0 offen offset:0
s_waitcnt vmcnt(0)

s_endpgm
.LMatMul_end:
.size MatMul, .LMatMul_end - MatMul
