#define SHADER_RCHIT
#include "game/graphics/common.inc.glsl"

hitAttributeEXT vec2 hitAttribs;
vec3 barycentricCoords = vec3(1.0f - hitAttribs.x - hitAttribs.y, hitAttribs.x, hitAttribs.y);

float SurfaceDetail(vec3 position) {
	return SimplexFractal(position, 6) * 0.5 + 0.5;
}

void main() {
	vec4 color = ComputeSurfaceColor(barycentricCoords) * GEOMETRY.material.color;
	vec3 normal = ComputeSurfaceNormal(barycentricCoords);
	float metallic = GEOMETRY.material.metallic;
	float roughness = GEOMETRY.material.roughness;
	vec3 emission = GEOMETRY.material.emission;
	float ior = 1.5;
	vec2 uv1 = ComputeSurfaceUV1(barycentricCoords);
	// vec2 uv2 = ComputeSurfaceUV2(barycentricCoords);
	// float specular = step(0.1, roughness) * (0.5 + metallic * 0.5);
	
	AutoFlipNormal(normal, ior);
	HandleDefaultInstanceData(INSTANCE.data, color, normal, metallic, roughness, ior, emission, uv1);
	HandleDefaultMaterialData(GEOMETRY.material.data, color, normal, metallic, roughness, ior, emission, uv1);
	
	// Rough metal
	if (metallic > 0 && roughness > 0) {
		vec3 scale = vec3(8);
		if (abs(dot(normal, vec3(1,0,0))) < 0.4) scale.x = 100;
		else if (abs(dot(normal, vec3(0,1,0))) < 0.4) scale.y = 100;
		else if (abs(dot(normal, vec3(0,0,1))) < 0.4) scale.z = 100;
		vec3 oldNormal = normal;
		vec3 localPosition = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * gl_HitTEXT;
		APPLY_NORMAL_BUMP_NOISE(SurfaceDetail, localPosition * scale, normal, roughness * 0.005)
		color.rgb *= pow(dot(oldNormal, normal), 100);
	}
	
	if (dot(emission, emission) > 0) {
		uint8_t flags = RAY_SURFACE_EMISSIVE;
		if (color.a < 0) flags |= RAY_SURFACE_TRANSPARENT;
		RayHit(
			/*albedo*/		emission,
			/*normal*/		normal,
			/*distance*/	gl_HitTEXT,
			/*roughness*/	roughness,
			/*ior*/			ior,
			flags
		);
	} else {
		uint8_t flags = RAY_SURFACE_DIFFUSE;
		if (metallic > 0) flags |= RAY_SURFACE_METALLIC;
		else if (color.a < 1) {
			flags |= RAY_SURFACE_TRANSPARENT;
			color.rgb *= 1 - color.a;
		}
		RayHit(
			/*albedo*/		color.rgb,
			/*normal*/		normal,
			/*distance*/	gl_HitTEXT,
			/*roughness*/	roughness,
			/*ior*/			ior,
			flags
		);
	}
	
}
