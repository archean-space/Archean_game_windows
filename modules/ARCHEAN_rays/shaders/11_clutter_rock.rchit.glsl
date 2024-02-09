#define SHADER_RCHIT
#include "clutter_rock.common.inc.glsl"
#include "lighting.inc.glsl"

void main() {
	ray.hitDistance = gl_HitTEXT;
	ray.t2 = 0;
	ray.renderableIndex = gl_InstanceID;
	ray.geometryIndex = gl_GeometryIndexEXT;
	ray.primitiveIndex = gl_PrimitiveID;
	ray.ssao = 1;
	ray.color.a = 1;
	
	if (RAY_IS_SHADOW) {
		return;
	}
	
	vec3 localPos = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * gl_HitTEXT;
	vec3 pos = localPos - rockPos;
	float detailSize = GetDetailSize();
	vec2 e = vec2(epsilon,0);
	vec3 normal = normalize(vec3(
		Sdf(pos+e.xyy, detailSize, detailOctavesHighRes) - Sdf(pos-e.xyy, detailSize, detailOctavesHighRes),
		Sdf(pos+e.yxy, detailSize, detailOctavesHighRes) - Sdf(pos-e.yxy, detailSize, detailOctavesHighRes),
		Sdf(pos+e.yyx, detailSize, detailOctavesHighRes) - Sdf(pos-e.yyx, detailSize, detailOctavesHighRes)
	));
	uint seed_ = uint32_t(AABB.data);
	float rocky = pow(RandomFloat(seed_), 2);
	const vec3 sandColor = vec3(0.5, 0.4, 0.3);
	const vec3 rockColor = vec3(0.3);
	surface.color = vec4(mix(sandColor, rockColor, rocky), 1);
	surface.color.rgb *= mix(0.5, 1.0, pow(abs(FastSimplexFractal(localPos*255.658, detailOctavesTextures)) + (FastSimplexFractal(localPos*29.123, detailOctavesTextures)*0.5+0.5), 0.5));
	surface.color.rgb *= pow(normal.y * 0.5 + 0.5, 0.25);
	surface.normal = normal;
	surface.metallic = 0;
	surface.roughness = 1;
	surface.emission = vec3(0);
	surface.ior = 1.45;
	surface.specular = rocky*0.5;
	
	// Apply world space normal
	ray.normal = normalize(MODEL2WORLDNORMAL * surface.normal);
	
	// Reverse gamma
	surface.color.rgb = ReverseGamma(surface.color.rgb);
	
	MakeAimable();

	// Write Motion Vectors
	WriteMotionVectorsAndDepth(ray.renderableIndex, gl_WorldRayOriginEXT + gl_WorldRayDirectionEXT * gl_HitTEXT, gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * gl_HitTEXT, ray.hitDistance, false);
	
	// Apply Lighting
	ApplyDefaultLighting();
	
	// Debug Time
	if (xenonRendererData.config.debugViewMode == RENDERER_DEBUG_VIEWMODE_RAYHIT_TIME) {
		if (RAY_RECURSIONS == 0) WRITE_DEBUG_TIME
	}
}
