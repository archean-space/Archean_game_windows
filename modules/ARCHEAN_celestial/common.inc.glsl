#ifdef __cplusplus
	#pragma once
#endif

#include "game/graphics/common.inc.glsl"

struct SunData {
	aligned_f32vec3 position;
	aligned_float32_t radius;
	aligned_f32vec3 color;
	aligned_float32_t temperature;
};
STATIC_ASSERT_ALIGNED16_SIZE(SunData, 32)

BUFFER_REFERENCE_STRUCT_READONLY(16) AtmosphereData {
	aligned_f32vec4 rayleigh;
	aligned_f32vec4 mie;
	aligned_float32_t innerRadius;
	aligned_float32_t outerRadius;
	aligned_float32_t g;
	aligned_float32_t temperature;
	aligned_f32vec3 _unused;
	aligned_int32_t nbSuns;
	SunData suns[2];
};
STATIC_ASSERT_ALIGNED16_SIZE(AtmosphereData, 128)

BUFFER_REFERENCE_STRUCT_READONLY(16) WaterData {
	aligned_f64vec3 center;
	aligned_float64_t radius;
};
STATIC_ASSERT_ALIGNED16_SIZE(WaterData, 32)
