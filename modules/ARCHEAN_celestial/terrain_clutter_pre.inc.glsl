#ifdef __cplusplus
	#pragma once
#endif
#include "terrain.common.inc.glsl"

#define CLUTTER_COMPUTE_SIZE 200

PUSH_CONSTANT_STRUCT TerrainClutterPushConstant {
	aligned_f64vec3 topLeftPos;
	BUFFER_REFERENCE_ADDR(ChunkBuffer) chunk;
	aligned_f64vec3 topRightPos;
	BUFFER_REFERENCE_ADDR(AabbData) aabbData;
	aligned_f64vec3 bottomLeftPos;
	aligned_uint64_t celestial_configs;
	aligned_f64vec3 bottomRightPos;
	aligned_uint64_t clutterData;
};
