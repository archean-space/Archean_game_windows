#extension GL_EXT_ray_tracing : require

#define SHADER_SURFACE
#include "game/graphics/common.inc.glsl"

void main() {
	uint32_t color = uint32_t(surface.aabbData & 0xFFFFFFFF);
	uint32_t flags = uint32_t(surface.aabbData >> 32);
	
	surface.color = vec4(
		float(color & 0xFF),
		float((color >> 8) & 0xFF),
		float((color >> 16) & 0xFF),
		float((color >> 24) & 0xFF)
	) / 255.0;
	
	if ((flags & PIPE_FLAG_STRIPES) != 0) {
		float f = fract(surface.localPosition.x + surface.localPosition.y + surface.localPosition.z);
		surface.color = vec4(mix(surface.color.rgb, surface.color.rgb * 0.02, step(0.5,f)), surface.color.a);
	}
	
	if ((flags & PIPE_FLAG_CHROME) != 0) {
		surface.metallic = 1;
		surface.roughness = 0;
	} else if ((flags & PIPE_FLAG_GLOSSY) != 0) {
		surface.metallic = 0;
		surface.roughness = 0;
	}
}
