#define SHADER_RCALL
#include "game/graphics/common.inc.glsl"
#include "../Block.inc.glsl"

struct Surface {
	vec3 pos;
	float ior;
	vec4 color;
	vec3 normal;
	float roughness;
};
layout(location = 0) callableDataInEXT Surface surface;

// float SurfaceDetail(vec3 position) {
// 	return SimplexFractal(position, 6) * 0.5 + 0.5;
// }

float RoughColorDetail(in vec3 pos) {
	return (SimplexFractal(pos, 3) + SimplexFractal(pos * 2, 3)) * 0.5;
}

void main() {
	// APPLY_NORMAL_BUMP_NOISE(SurfaceDetail, surface.pos, surface.normal, surface.roughness * 0.01)
	surface.color.rgb *= pow(clamp(RoughColorDetail(surface.pos * 64) + 1, 0.1, 1), 0.25);
}
