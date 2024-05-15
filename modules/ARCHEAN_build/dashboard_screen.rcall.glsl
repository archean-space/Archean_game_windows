#extension GL_EXT_ray_tracing : require

#define SHADER_SURFACE
#include "game/graphics/common.inc.glsl"

void main() {
	GeometryData geometry = GeometryData(surface.geometries)[surface.geometryIndex];
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
		surface.uv1 = vec2(pos.x, 1 - pos.y);
		if (pos.z > 0.01) {
			surface.color = vec4(1,1,1,0);
			surface.metallic = 0;
			surface.roughness = 0;
			return;
		}
	}
	if (surface.renderableData != 0) {
		RenderableData data = RenderableData(surface.renderableData)[surface.geometryIndex];
		surface.metallic = 0; // mix(surface.metallic, data.pbrMetallic, data.pbrMix);
		surface.roughness = 0; // mix(surface.roughness, data.pbrRoughness, data.pbrMix);
		if (data.monitorIndex > 0) {
			vec4 tex = texture(textures[nonuniformEXT(data.monitorIndex)], surface.uv1);
			vec3 color = ReverseGamma(tex.rgb);
			surface.color = vec4((1-color)*(1-tex.a), tex.a);
			surface.emission = data.emission * color;
			surface.emission /= GetCurrentExposure();
		} else {
			surface.color = vec4(0,0,0,1); // mix(surface.color, data.color, data.colorMix);
			surface.emission = data.emission;
		}
	}
}
