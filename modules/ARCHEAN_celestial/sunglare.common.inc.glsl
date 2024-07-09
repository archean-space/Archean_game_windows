#include "game/graphics/common.inc.glsl"

BUFFER_REFERENCE_STRUCT_WRITEONLY(4) SunGlareBrightness {
	aligned_float32_t brightness;
};

PUSH_CONSTANT_STRUCT SunglarePushConstant {
	aligned_f32mat4 viewMatrix;
	SunData sunData;
	BUFFER_REFERENCE_ADDR(SunGlareBrightness) brightnessBuffer;
	aligned_float32_t brightness;
};
