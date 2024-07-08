#define SHADER_RCHIT
#include "game/graphics/common.inc.glsl"

void main() {
	uint64_t aabbData = AABB.data;
	uint32_t ucolor = uint32_t(aabbData & 0xFFFFFFFF);
	vec4 color = vec4(
		float(ucolor & 0xFF),
		float((ucolor >> 8) & 0xFF),
		float((ucolor >> 16) & 0xFF),
		float((ucolor >> 24) & 0xFF)
	) / 255.0;
	uint32_t tex = uint32_t(aabbData >> 32) & 0xFFFF;
	float roughness = 1;// float(uint32_t(aabbData >> 48) & 0x7) / 7.0;
	float metallic = 0;// float(uint32_t(aabbData >> 51) & 0x1);
	vec3 normal = vec3(
		float(uint32_t(aabbData >> 52) & 0x3) - 1.0,
		float(uint32_t(aabbData >> 54) & 0x3) - 1.0,
		float(uint32_t(aabbData >> 56) & 0x3) - 1.0
	);
	
	vec3 surfaceNormal = ComputeSurfaceNormal(gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * gl_HitTEXT);
	if (dot(normal, surfaceNormal) > 0.5) {
	
		vec3 pos = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * gl_HitTEXT;
		
		GeometryData geometry = INSTANCE.geometries[gl_GeometryIndexEXT];
		if (uint64_t(geometry.aabbs) != 0) {
			const vec3 aabb_min = vec3(geometry.aabbs[gl_PrimitiveID].aabb[0], geometry.aabbs[gl_PrimitiveID].aabb[1], geometry.aabbs[gl_PrimitiveID].aabb[2]);
			const vec3 aabb_max = vec3(geometry.aabbs[gl_PrimitiveID].aabb[3], geometry.aabbs[gl_PrimitiveID].aabb[4], geometry.aabbs[gl_PrimitiveID].aabb[5]);
			vec3 aabb_size = abs(aabb_max - aabb_min);
			vec3 aabb_center = (aabb_max + aabb_min) * 0.5;
			pos = (pos - aabb_center) / aabb_size * 2;
		}
		
		vec3 up = vec3(
			float(uint32_t(aabbData >> 58) & 0x3) - 1.0,
			float(uint32_t(aabbData >> 60) & 0x3) - 1.0,
			float(uint32_t(aabbData >> 62) & 0x3) - 1.0
		);
		vec3 right = cross(-normal, up);
		
		vec2 uv = vec2(
			dot(pos, right),
			dot(pos, -up)
		) * 0.5 + 0.5;
		
		color *= texture(textures[tex], uv);
		
		MakeAimable(normal, uv, 0);
	
	} else {
		normal = surfaceNormal;
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
		/*ior*/			1.2,
		flags
	);
}
