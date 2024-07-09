#ifdef __cplusplus
	#pragma once
#endif

#include "game/graphics/common.inc.glsl"

BUFFER_REFERENCE_STRUCT_READONLY(16) PropellerData {
	aligned_float32_t radius;
	aligned_float32_t width;
	aligned_float32_t base;
	aligned_float32_t twist;
	aligned_float32_t pitch;
	aligned_float32_t roundedTips;
	aligned_float32_t speed;
	aligned_uint16_t flags;
	aligned_uint8_t blades;
	aligned_uint8_t _unused;
};
STATIC_ASSERT_ALIGNED16_SIZE(PropellerData, 32)
