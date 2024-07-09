#ifdef __cplusplus
	#pragma once
#endif
#include "terrain.common.inc.glsl"

#define COMPUTE_SIZE_X 16
#define COMPUTE_SIZE_Y 16

BUFFER_REFERENCE_STRUCT(4) TerrainVertexBuffer {
	aligned_float32_t vertex;
};

BUFFER_REFERENCE_STRUCT(4) TerrainNormalBuffer {
	aligned_float32_t normal;
};

BUFFER_REFERENCE_STRUCT(4) TerrainColorBuffer {
	aligned_u8vec4 color;
};

BUFFER_REFERENCE_STRUCT(4) TerrainUvBuffer {
	aligned_f32vec2 uv;
};

PUSH_CONSTANT_STRUCT TerrainChunkPushConstant {
	BUFFER_REFERENCE_ADDR(ChunkBuffer) chunk;
	BUFFER_REFERENCE_ADDR(TerrainVertexBuffer) vertices;
	BUFFER_REFERENCE_ADDR(TerrainNormalBuffer) normals;
	BUFFER_REFERENCE_ADDR(TerrainColorBuffer) colors;
	BUFFER_REFERENCE_ADDR(TerrainUvBuffer) uvs;
	aligned_uint64_t celestial_configs;
};
