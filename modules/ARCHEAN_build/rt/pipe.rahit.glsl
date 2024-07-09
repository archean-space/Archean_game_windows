#define SHADER_RAHIT
#include "game/graphics/common.inc.glsl"
#include "../common.inc.glsl"

void main() {
	
	vec4 color = GEOMETRY.material.color;

	uint32_t ucolor = uint32_t(AABB.data & 0xFFFFFFFF);
	uint32_t flags = uint32_t(AABB.data >> 32);
	
	color *= vec4(
		float(ucolor & 0xFF),
		float((ucolor >> 8) & 0xFF),
		float((ucolor >> 16) & 0xFF),
		float((ucolor >> 24) & 0xFF)
	) / 255.0;
	
	if ((flags & PIPE_FLAG_STRIPES) != 0) {
		vec3 localPosition = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * gl_HitTEXT;
		float f = fract(localPosition.x + localPosition.y + localPosition.z);
		color = vec4(mix(color.rgb, color.rgb * 0.02, step(0.5,f)), color.a);
	}
	
	if (color.a < 1) {
		RayTransparent(color.rgb * (1 - color.a));
	} else {
		RayOpaque();
	}
}
