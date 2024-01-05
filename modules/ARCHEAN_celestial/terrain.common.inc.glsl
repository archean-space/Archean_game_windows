#ifdef __cplusplus
	#pragma once
#endif
#include "game/graphics/common.inc.glsl"

#define Color 0
#define Height 2
#define Specular 4

#define NEAR_TEXTURE_SPAN_METERS 4.0
#define FAR_TEXTURE_SPAN_METERS 64.0

#define SMOOTH_SHADING_TRIANGLE_SIZE_THRESHOLD 0.5

// #define TERRAIN_MESH_GENERATE_SMOOTH_NORMALS

#define TERRAIN_FEATURE_LAVA 1
#define TERRAIN_FEATURE_VOLCANO 2
#define TERRAIN_FEATURE_WAVY_SAND 3

BUFFER_REFERENCE_STRUCT(4) TerrainSplatBuffer {
	u8vec4 splat;
};

BUFFER_REFERENCE_STRUCT(4) TemperatureBuffer {
	float temperature;
};

BUFFER_REFERENCE_STRUCT(16) ChunkBuffer {
	aligned_f64mat4 transform;
	aligned_f64mat4 inverseTransform;
	aligned_u32vec4 tex;
	aligned_float32_t skirtOffset;
	aligned_float32_t triangleSize;
	aligned_int32_t topSign;
	aligned_int32_t rightSign;
	aligned_float32_t chunkSize;
	aligned_uint32_t vertexSubdivisions;
	BUFFER_REFERENCE_ADDR(TerrainSplatBuffer) splats;
	aligned_f64vec2 uvOffset;
	aligned_float64_t uvMult;
	aligned_float64_t planetFaceSize;
	aligned_f32vec4 texHeightDisplacement;
	aligned_f32vec4 texBumpNormalDisplacement;
	BUFFER_REFERENCE_ADDR(TemperatureBuffer) temperature;
};
