#ifdef __cplusplus
	#pragma once
#endif

// Up to 32 flags
#define PIPE_FLAG_BOX			(1u << 0)
#define PIPE_FLAG_CAPSULE		(1u << 1)
#define PIPE_FLAG_STRIPES		(1u << 2)
#define PIPE_FLAG_CHROME		(1u << 3)
#define PIPE_FLAG_GLOSSY		(1u << 5)
#define PIPE_FLAG_FLEXIBLE		(1u << 6)
#define PIPE_FLAG_METAL			(1u << 7)

// Per frame
#define VOXELS_X 3
#define VOXELS_Y 3
#define VOXELS_Z 3
#define VOXELS_HD 4
#define VOXELS_PER_FRAME (VOXELS_X*VOXELS_Y*VOXELS_Z)

#define VOXEL_INDEX(x,y,z) (x + z*VOXELS_X + y*VOXELS_X*VOXELS_Z)
#define VOXEL_INDEX_HD(x,y,z) (uint8_t(x) | (uint8_t(z) << 2) | (uint8_t(y) << 4))

#ifdef __cplusplus
	#define VOXEL_FULL 0xffffffffffffffffull
#else
	#define VOXEL_FULL 0xfffffffffffffffful
#endif

BUFFER_REFERENCE_STRUCT(8) VolumeData {
	aligned_uint64_t occupancy[VOXELS_PER_FRAME];
};

#ifdef GLSL
	bool IsValidVoxel(in ivec3 iPos) {
		if (iPos.x < 0 || iPos.y < 0 || iPos.z < 0) return false;
		if (iPos.x >= VOXELS_X || iPos.y >= VOXELS_Y || iPos.z >= VOXELS_Z) return false;
		return true;
	}
	bool IsValidVoxelHD(in ivec3 iPos) {
		if (iPos.x < 0 || iPos.y < 0 || iPos.z < 0) return false;
		if (iPos.x >= 4 || iPos.y >= 4 || iPos.z >= 4) return false;
		return true;
	}
#endif

#ifdef __cplusplus
	#include "Frame.h"
	using Voxels = std::unordered_map<Frame::ID_t, std::array<uint64_t, VOXELS_PER_FRAME>>;
#endif
