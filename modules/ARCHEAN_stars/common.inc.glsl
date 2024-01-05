#include "game/graphics/common.inc.glsl"

PUSH_CONSTANT_STRUCT StarsPushConstant {
	aligned_f32mat4 viewMatrix;
	aligned_int32_t nbStars;
	aligned_float32_t contrast;
};
