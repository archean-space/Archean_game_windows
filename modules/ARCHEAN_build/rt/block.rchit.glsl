#define SHADER_RCHIT
#include "game/graphics/common.inc.glsl"

hitAttributeEXT vec2 hitAttribs;
vec3 barycentricCoords = vec3(1.0f - hitAttribs.x - hitAttribs.y, hitAttribs.x, hitAttribs.y);

#include "../Block.inc.glsl"

float SurfaceDetail(vec3 position) {
	return SimplexFractal(position, 6) * 0.5 + 0.5;
}

void main() {
	BlockColor blockMaterial = BlockColor(GEOMETRY.material.uv2)[gl_PrimitiveID];
	vec4 color;
	color.rgb = vec3(blockMaterial.r, blockMaterial.g, blockMaterial.b) / 255.0;
	color.a = (float(blockMaterial.a & 0xf) + 1) / 16.0;
	float roughness = float((blockMaterial.a >> 4) & 0x7) / 7.0;
	float metallic = float(blockMaterial.a >> 7);
	// surface.specular = step(0.1, surface.roughness) * (0.5 + surface.metallic * 0.5);
	
	vec3 normal = ComputeSurfaceNormal(barycentricCoords);
	float ior = 1.2;
	// vec2 uv1 = ComputeSurfaceUV1(barycentricCoords);
	// vec2 uv2 = ComputeSurfaceUV2(barycentricCoords);
	// float specular = step(0.1, roughness) * (0.5 + metallic * 0.5);
	
	AutoFlipNormal(normal, ior);
	MakeAimable(normal, vec2(0), 0);
	
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
