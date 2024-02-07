#extension GL_EXT_ray_tracing : require

#define SHADER_SURFACE
#include "game/graphics/common.inc.glsl"
// #include "xenon/renderer/shaders/perlint.inc.glsl"

float SurfaceDetail(vec3 position) {
	return SimplexFractal(position, 5) * 0.5 + 0.5;
}

void main() {

	// surface.metallic = 1;
	// surface.roughness = 1;
	// surface.color.rgb = vec3(0.3, 0.3, 0.3);
	// surface.specular = 1;

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
}
