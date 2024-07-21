#define SHADER_RAHIT
#include "game/graphics/common.inc.glsl"

hitAttributeEXT vec2 hitAttribs;
vec3 barycentricCoords = vec3(1.0f - hitAttribs.x - hitAttribs.y, hitAttribs.x, hitAttribs.y);

void main() {
	vec4 color = ComputeSurfaceColor(barycentricCoords) * GEOMETRY.material.color;
	uint64_t instanceData = INSTANCE.data;
	if (instanceData != 0) {
		vec2 uv1 = ComputeSurfaceUV1(barycentricCoords);
		if (GEOMETRY.material.callableShader != 0) {
			uint64_t vertices = GEOMETRY.vertices;
			if (vertices != 0) {
				const vec3 aabb_min = vec3(
					VertexBuffer(vertices).vertices[0],
					VertexBuffer(vertices).vertices[1],
					VertexBuffer(vertices).vertices[2]
				);
				const vec3 aabb_max = vec3(
					VertexBuffer(vertices).vertices[6*3],
					VertexBuffer(vertices).vertices[6*3+1],
					VertexBuffer(vertices).vertices[6*3+2]
				);
				vec3 aabb_size = abs(aabb_max - aabb_min);
				vec3 localPosition = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * gl_HitTEXT;
				vec3 pos = (localPosition - aabb_min) / aabb_size;
				uv1 = pos.z > 0.5? vec2(pos.x, 1 - pos.y) : vec2(-1);
			}
		}
		RenderableData data = RenderableData(instanceData)[gl_GeometryIndexEXT];
		color = mix(color, data.color, data.colorMix);
		if (data.monitorIndex > 0) {
			vec4 tex = texture(textures[nonuniformEXT(data.monitorIndex)], uv1);
			color.a *= tex.a;
			color.rgb = mix(vec3(1), tex.rgb, color.a);
		}
	}
	if (color.a < 1) {
		RayTransparent(color.rgb * (1-color.a));
	} else {
		RayOpaque();
	}
}
