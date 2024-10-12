#define SHADER_RCHIT
#include "game/graphics/common.inc.glsl"

hitAttributeEXT vec2 hitAttribs;
vec3 barycentricCoords = vec3(1.0f - hitAttribs.x - hitAttribs.y, hitAttribs.x, hitAttribs.y);

struct Surface {
	vec3 in_pos_out_uv;
	uint8_t rayFlags;
};
layout(location = 0) callableDataEXT Surface surface;

float SurfaceDetail(vec3 position) {
	return SimplexFractal(position, 6) * 0.5 + 0.5;
}

void main() {
	vec3 localPosition = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * gl_HitTEXT;
	vec4 color = ComputeSurfaceColor(barycentricCoords) * GEOMETRY.material.color;
	vec3 normal = ComputeSurfaceNormal(barycentricCoords);
	float metallic = GEOMETRY.material.metallic;
	float roughness = GEOMETRY.material.roughness;
	vec3 emission = GEOMETRY.material.emission;
	float ior = 1.5;
	vec2 uv1 = ComputeSurfaceUV1(barycentricCoords);
	
	AutoFlipNormal(normal, ior);
	
	RAY_SURFACE_DIFFUSE;
	
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
			
			// Callable
			surface.in_pos_out_uv = (localPosition - aabb_min) / aabb_size;
			surface.rayFlags = RAY_SURFACE_DIFFUSE;
			executeCallableEXT(GEOMETRY.material.callableShader, 0);
			uv1.xy = surface.in_pos_out_uv.xy;
			
			RenderableData data = RenderableData(INSTANCE.data)[gl_GeometryIndexEXT];
			if (data.monitorIndex > 0) {
				if ((surface.rayFlags & RAY_SURFACE_TRANSPARENT) != 0) {
					color.rgb = vec3(1);
				} else {
					MakeAimable(normal, uv1, data.monitorIndex);
					vec4 tex = texture(textures[nonuniformEXT(data.monitorIndex)], uv1);
					color.rgb = ReverseGamma(tex.rgb);
					if (tex.a < 1) {
						surface.rayFlags = RAY_SURFACE_TRANSPARENT;
						color.rgb = vec3(mix(vec3(1), tex.rgb, tex.a));
					}
					if ((surface.rayFlags & RAY_SURFACE_EMISSIVE) != 0) {
						color.rgb *= data.emission / GetCurrentExposure();
					}
				}
			} else {
				MakeAimable(normal, uv1, 0);
			}
			
			RayHit(
				/*albedo*/		color.rgb,
				/*normal*/		normal,
				/*distance*/	gl_HitTEXT,
				/*roughness*/	roughness,
				/*ior*/			ior,
				surface.rayFlags
			);
		}
	} else {
		HandleDefaultInstanceData(INSTANCE.data, color, normal, metallic, roughness, ior, emission, uv1);
		HandleDefaultMaterialData(GEOMETRY.material.data, color, normal, metallic, roughness, ior, emission, uv1);
		// Rough metal
		if (metallic > 0 && roughness > 0) {
			vec3 scale = vec3(8);
			if (abs(dot(normal, vec3(1,0,0))) < 0.4) scale.x = 100;
			else if (abs(dot(normal, vec3(0,1,0))) < 0.4) scale.y = 100;
			else if (abs(dot(normal, vec3(0,0,1))) < 0.4) scale.z = 100;
			vec3 oldNormal = normal;
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
	
}
