#define SHADER_RCHIT
#include "game/graphics/common.inc.glsl"
#include "../Block.inc.glsl"

hitAttributeEXT vec2 hitAttribs;
vec3 barycentricCoords = vec3(1.0f - hitAttribs.x - hitAttribs.y, hitAttribs.x, hitAttribs.y);

struct Surface {
	vec3 pos;
	float ior;
	vec4 color;
	vec3 normal;
	float roughness;
};
layout(location = 0) callableDataEXT Surface surface;

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
	vec3 normal = ComputeSurfaceNormal(barycentricCoords);
	float ior = 1.2;
	
	AutoFlipNormal(normal, ior);
	MakeAimable(normal, vec2(0), 0);
	
	if (GEOMETRY.material.callableShader != 0) {
		surface.pos = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * gl_HitTEXT;
		surface.ior = ior;
		surface.color = color;
		surface.normal = normal;
		surface.roughness = roughness;
		executeCallableEXT(GEOMETRY.material.callableShader, 0);
		ior = surface.ior;
		color = surface.color;
		normal = surface.normal;
		roughness = surface.roughness;
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
