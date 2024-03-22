#extension GL_EXT_ray_tracing : require

#define SHADER_SURFACE
#include "game/graphics/common.inc.glsl"

void main() {
	GeometryData geometry = GeometryData(surface.geometries)[surface.geometryIndex];
	if (uint64_t(geometry.aabbs) != 0) {
		const vec3 aabb_min = vec3(geometry.aabbs[surface.primitiveIndex].aabb[0], geometry.aabbs[surface.primitiveIndex].aabb[1], geometry.aabbs[surface.primitiveIndex].aabb[2]);
		const vec3 aabb_max = vec3(geometry.aabbs[surface.primitiveIndex].aabb[3], geometry.aabbs[surface.primitiveIndex].aabb[4], geometry.aabbs[surface.primitiveIndex].aabb[5]);
		vec3 aabb_size = abs(aabb_max - aabb_min);
		vec3 pos = (surface.localPosition - aabb_min) / aabb_size;
		surface.uv1 = step(0.5, pos.z) * vec2(pos.x, 1 - pos.y);
	}
	if (geometry.vertices != 0) {
		const vec3 aabb_min = vec3(
			VertexBuffer(geometry.vertices).vertices[0],
			VertexBuffer(geometry.vertices).vertices[1],
			VertexBuffer(geometry.vertices).vertices[2]
		);
		const vec3 aabb_max = vec3(
			VertexBuffer(geometry.vertices).vertices[6*3],
			VertexBuffer(geometry.vertices).vertices[6*3+1],
			VertexBuffer(geometry.vertices).vertices[6*3+2]
		);
		vec3 aabb_size = abs(aabb_max - aabb_min);
		vec3 pos = (surface.localPosition - aabb_min) / aabb_size;
		surface.uv1 = step(0.5, pos.z) * vec2(pos.x, 1 - pos.y);
	}
	if (surface.renderableData != 0) {
		RenderableData data = RenderableData(surface.renderableData)[surface.geometryIndex];
		surface.metallic = surface.metallic; // mix(surface.metallic, data.pbrMetallic, data.pbrMix);
		surface.roughness = surface.roughness; // mix(surface.roughness, data.pbrRoughness, data.pbrMix);
		if (data.monitorIndex > 0) {
			vec4 tex = texture(nonuniformEXT(textures[data.monitorIndex]), surface.uv1);
			surface.color = vec4(tex.rgb, max(1-length(tex.rgb), tex.a));
		} else {
			surface.color = surface.color; // mix(surface.color, data.color, data.colorMix);
		}
	}
}
