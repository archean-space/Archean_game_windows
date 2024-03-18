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
	if (surface.renderableData != 0) {
		RenderableData data = RenderableData(surface.renderableData)[surface.geometryIndex];
		surface.metallic = 0; // mix(surface.metallic, data.pbrMetallic, data.pbrMix);
		surface.roughness = 0; // mix(surface.roughness, data.pbrRoughness, data.pbrMix);
		if (data.monitorIndex > 0) {
			vec4 tex = texture(nonuniformEXT(textures[data.monitorIndex]), surface.uv1);
			vec3 color = ReverseGamma(tex.rgb);
			surface.color = vec4((1-color)*(1-tex.a), tex.a);
			surface.emission = data.emission * color;
		} else {
			surface.color = vec4(0,0,0,1); // mix(surface.color, data.color, data.colorMix);
			surface.emission = data.emission;
		}
	}
}
