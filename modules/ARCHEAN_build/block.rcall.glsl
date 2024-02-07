#extension GL_EXT_ray_tracing : require

#define SHADER_SURFACE
#include "game/graphics/common.inc.glsl"
#include "Block.inc.glsl"

float SurfaceDetail(vec3 position) {
	return SimplexFractal(position, 5) * 0.5 + 0.5;
}

void main() {
	// BlockColor color = BlockColor(surface.geometryUv2Data)[nonuniformEXT(surface.primitiveIndex)];
	// surface.color.rgb = vec3(color.r, color.g, color.b) / 255.0;
	// surface.color.a = (float(color.a & 0xf) + 1) / 16.0;
	// surface.roughness = float((color.a >> 4) & 0x7) / 7.0;
	// surface.metallic = float(color.a >> 7);
	
	// surface.specular = step(0.1, surface.roughness) * (0.5 + surface.metallic * 0.5);
	
	// // Rough metal
	// if (surface.metallic > 0 && surface.roughness > 0) {
	// 	vec3 scale = vec3(2);
	// 	if (abs(dot(surface.normal, vec3(1,0,0))) < 0.4) scale.x = 400;
	// 	else if (abs(dot(surface.normal, vec3(0,1,0))) < 0.4) scale.y = 400;
	// 	else if (abs(dot(surface.normal, vec3(0,0,1))) < 0.4) scale.z = 400;
	// 	vec3 oldNormal = surface.normal;
	// 	APPLY_NORMAL_BUMP_NOISE(SurfaceDetail, surface.localPosition * scale, surface.normal, surface.roughness * 0.009)
	// 	surface.color.rgb *= pow(dot(oldNormal, surface.normal), 500);
	// }
	
	// // Glass
	// if (surface.color.a < 0.99) {
	// 	surface.ior = 1.02;
	// 	surface.specular = 0.5;
	// }
}
