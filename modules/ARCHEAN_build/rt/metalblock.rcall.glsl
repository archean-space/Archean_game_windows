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

float SurfaceDetail(vec3 position) {
	return SimplexFractal(position, 6) * 0.5 + 0.5;
}

void main() {
	if (surface.roughness > 0) {
		vec3 scale = vec3(8);
		if (abs(dot(surface.normal, vec3(1,0,0))) < 0.4) scale.x = 100;
		else if (abs(dot(surface.normal, vec3(0,1,0))) < 0.4) scale.y = 100;
		else if (abs(dot(surface.normal, vec3(0,0,1))) < 0.4) scale.z = 100;
		vec3 oldNormal = surface.normal;
		APPLY_NORMAL_BUMP_NOISE(SurfaceDetail, surface.pos * scale, surface.normal, surface.roughness * 0.005)
		surface.color.rgb *= pow(dot(oldNormal, surface.normal), 100);
	}
}
