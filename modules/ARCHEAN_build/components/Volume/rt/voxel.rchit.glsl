#define SHADER_RCHIT
#include "game/graphics/common.inc.glsl"
#include "../../../common.inc.glsl"

void main() {
	ray.rayFlags |= RAY_FLAG_CULL_WATER;
}
