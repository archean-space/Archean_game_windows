#define SHADER_RCHIT
#include "game/graphics/common.inc.glsl"

float SurfaceDetail(vec3 position) {
	return SimplexFractal(position, 5) * 0.5 + 0.5;
}

void main() {

	vec4 color = vec4(0.1, 0.1, 0.1, 1);
	vec3 normal = ComputeSurfaceNormal(gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * gl_HitTEXT);

	MakeAimable(normal, vec2(0), 0);
	
	// Rough metal
	vec3 scale = vec3(2);
	if (abs(dot(normal, vec3(1,0,0))) < 0.4) scale.x = 400;
	else if (abs(dot(normal, vec3(0,1,0))) < 0.4) scale.y = 400;
	else if (abs(dot(normal, vec3(0,0,1))) < 0.4) scale.z = 400;
	vec3 oldNormal = normal;
	vec3 localPosition = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * gl_HitTEXT;
	APPLY_NORMAL_BUMP_NOISE(SurfaceDetail, localPosition * scale, normal, 0.009)
	color.rgb *= pow(dot(oldNormal, normal), 500);
	
	RayHit(
		/*albedo*/		color.rgb,
		/*normal*/		normal,
		/*distance*/	gl_HitTEXT,
		/*roughness*/	1,
		/*ior*/			1.5,
		/*flags*/ RAY_SURFACE_DIFFUSE|RAY_SURFACE_METALLIC
	);
	
}
