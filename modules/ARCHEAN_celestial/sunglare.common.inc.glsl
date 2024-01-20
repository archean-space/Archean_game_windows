#include "game/graphics/common.inc.glsl"

BUFFER_REFERENCE_STRUCT_WRITEONLY(4) SunGlareBrightness {
	float brightness;
};

PUSH_CONSTANT_STRUCT SunglarePushConstant {
	aligned_f32mat4 viewMatrix;
	SunData sunData;
	BUFFER_REFERENCE_ADDR(SunGlareBrightness) brightnessBuffer;
	float brightness;
};
