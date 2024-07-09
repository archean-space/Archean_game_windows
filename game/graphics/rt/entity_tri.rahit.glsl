#define SHADER_RAHIT
#include "game/graphics/common.inc.glsl"

hitAttributeEXT vec2 hitAttribs;
vec3 barycentricCoords = vec3(1.0f - hitAttribs.x - hitAttribs.y, hitAttribs.x, hitAttribs.y);

void main() {
	vec4 color = ComputeSurfaceColor(barycentricCoords) * GEOMETRY.material.color;
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
