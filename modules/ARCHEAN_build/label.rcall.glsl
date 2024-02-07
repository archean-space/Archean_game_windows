#extension GL_EXT_ray_tracing : require

#define SHADER_SURFACE
#include "game/graphics/common.inc.glsl"

void main() {
	// uint32_t color = uint32_t(surface.aabbData & 0xFFFFFFFF);
	// surface.color = vec4(
	// 	float(color & 0xFF),
	// 	float((color >> 8) & 0xFF),
	// 	float((color >> 16) & 0xFF),
	// 	float((color >> 24) & 0xFF)
	// ) / 255.0;
	// uint32_t tex = uint32_t(surface.aabbData >> 32) & 0xFFFF;
	// surface.roughness = float(uint32_t(surface.aabbData >> 48) & 0x7) / 7.0;
	// surface.metallic = float(uint32_t(surface.aabbData >> 51) & 0x1);
	// vec3 normal = vec3(
	// 	float(uint32_t(surface.aabbData >> 52) & 0x3) - 1.0,
	// 	float(uint32_t(surface.aabbData >> 54) & 0x3) - 1.0,
	// 	float(uint32_t(surface.aabbData >> 56) & 0x3) - 1.0
	// );
	
	// if (dot(normal, surface.normal) < 0.5) return;
	
	// vec3 pos = surface.localPosition;
	
	// GeometryData geometry = GeometryData(surface.geometries)[surface.geometryIndex];
	// if (uint64_t(geometry.aabbs) != 0) {
	// 	const vec3 aabb_min = vec3(geometry.aabbs[surface.primitiveIndex].aabb[0], geometry.aabbs[surface.primitiveIndex].aabb[1], geometry.aabbs[surface.primitiveIndex].aabb[2]);
	// 	const vec3 aabb_max = vec3(geometry.aabbs[surface.primitiveIndex].aabb[3], geometry.aabbs[surface.primitiveIndex].aabb[4], geometry.aabbs[surface.primitiveIndex].aabb[5]);
	// 	vec3 aabb_size = abs(aabb_max - aabb_min);
	// 	vec3 aabb_center = (aabb_max + aabb_min) * 0.5;
	// 	pos = (pos - aabb_center) / aabb_size * 2;
	// }
	
	// vec3 up = vec3(
	// 	float(uint32_t(surface.aabbData >> 58) & 0x3) - 1.0,
	// 	float(uint32_t(surface.aabbData >> 60) & 0x3) - 1.0,
	// 	float(uint32_t(surface.aabbData >> 62) & 0x3) - 1.0
	// );
	// vec3 right = cross(-normal, up);
	
	// vec2 uv = vec2(
	// 	dot(pos, right),
	// 	dot(pos, -up)
	// ) * 0.5 + 0.5;
	
	// surface.uv1 = uv;
	
	// vec4 texColor = texture(textures[tex], uv);
	// surface.color = texColor;
}
