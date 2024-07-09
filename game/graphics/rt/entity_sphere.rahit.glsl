#define SHADER_RAHIT
#include "game/graphics/common.inc.glsl"

void main() {
	vec4 color = ComputeSurfaceColor(vec3(0)) * GEOMETRY.material.color;
	uint64_t instanceData = INSTANCE.data;
	uint64_t geometryMaterialData = GEOMETRY.material.data;
	if (instanceData != 0) {
		RenderableData data = RenderableData(instanceData)[gl_GeometryIndexEXT];
		color = mix(color, data.color, data.colorMix);
	}
	if (color.a < 1) {
		RayTransparent(color.rgb * (1 - color.a));
	} else {
		RayOpaque();
	}
}
