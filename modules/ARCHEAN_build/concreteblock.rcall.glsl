#extension GL_EXT_ray_tracing : require

#define SHADER_SURFACE
#include "game/graphics/common.inc.glsl"
#include "Block.inc.glsl"

float SurfaceDetail(vec3 position) {
	return SimplexFractal(position, 6) * 0.5 + 0.5;
}

float RoughColorDetail(in vec3 pos) {
	return (SimplexFractal(pos, 3) + SimplexFractal(pos * 2, 3)) * 0.5;
}

void main() {
	BlockColor color = BlockColor(surface.geometryUv2Data)[nonuniformEXT(surface.primitiveIndex)];
	surface.color.rgb = vec3(color.r, color.g, color.b) / 255.0;
	surface.color.a = (float(color.a & 0xf) + 1) / 16.0;
	surface.roughness = float((color.a >> 4) & 0x7) / 7.0;
	surface.metallic = float(color.a >> 7);
	surface.specular = step(0.1, surface.roughness) * (0.5 + surface.metallic * 0.5);

	APPLY_NORMAL_BUMP_NOISE(SurfaceDetail, surface.localPosition, surface.normal, surface.roughness * 0.01)
	surface.color.rgb *= pow(clamp(RoughColorDetail(surface.localPosition * 64) + 1, 0.1, 1), 0.25);
}
