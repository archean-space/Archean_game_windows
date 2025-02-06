#define SHADER_RCALL
#include "game/graphics/common.inc.glsl"

struct Surface {
	vec3 in_pos_out_uv;
	uint8_t rayFlags;
};
layout(location = 0) callableDataInEXT Surface surface;

void main() {
	vec3 pos = surface.in_pos_out_uv;
	surface.in_pos_out_uv.xy = vec2(pos.x, 1 - pos.y);
	if (pos.z > 0.01) {
		surface.rayFlags = RAY_SURFACE_EMISSIVE;
	} else {
		surface.rayFlags = RAY_SURFACE_DIFFUSE;
	}
	if (pos.x < 0.001 || pos.y < 0.001 || pos.x > 0.999 || pos.y > 0.999) {
		surface.in_pos_out_uv.xy = vec2(-1);
	}
}
