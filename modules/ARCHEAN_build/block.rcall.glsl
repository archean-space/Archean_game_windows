#extension GL_EXT_ray_tracing : require

#define SHADER_SURFACE
#include "game/graphics/common.inc.glsl"
#include "Block.inc.glsl"

void main() {
	BlockColor color = BlockColor(surface.geometryUv2Data)[surface.primitiveIndex];
	surface.color.rgb = vec3(color.r, color.g, color.b) / 255.0;
	surface.color.a = (float(color.a & 0xf) + 1) / 16.0;
	surface.roughness = float((color.a >> 4) & 0x7) / 7.0;
	surface.metallic = float(color.a >> 7);
	surface.specular = step(0.1, surface.roughness) * (0.5 + surface.metallic * 0.5);
}
