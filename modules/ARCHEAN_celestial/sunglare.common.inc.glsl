#include "game/graphics/common.inc.glsl"

PUSH_CONSTANT_STRUCT SunglarePushConstant {
	aligned_f32mat4 viewMatrix;
	SunData sunData;
};
