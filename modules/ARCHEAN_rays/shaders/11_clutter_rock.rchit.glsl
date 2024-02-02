#define SHADER_RCHIT
#include "clutter_rock.common.inc.glsl"
#include "lighting.inc.glsl"

void main() {
	// ray.hitDistance = gl_HitTEXT;
	// ray.t2 = 0;
	// ray.aimID = gl_InstanceCustomIndexEXT;
	// ray.renderableIndex = gl_InstanceID;
	// ray.geometryIndex = gl_GeometryIndexEXT;
	// ray.primitiveIndex = gl_PrimitiveID;
	vec3 localPosition = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * gl_HitTEXT;
	// ray.worldPosition = gl_WorldRayOriginEXT + gl_WorldRayDirectionEXT * gl_HitTEXT;
	// ray.ssao = 1;
	// ray.color.a = 1;
	
	if (RAY_IS_SHADOW) {
		ray.albedo = vec3(0);
		ray.t1 = gl_HitTEXT;
		ray.normal = vec3(0);
		ray.t2 = 0;
		ray.emission = vec3(0);
		ray.mask = 0;
		ray.transmittance = vec3(0);
		ray.ior = 0;
		ray.reflectance = 0;
		ray.metallic = 0;
		ray.roughness = 0;
		ray.specular = 0;
		ray.localPosition = localPosition;
		ray.renderableIndex = gl_InstanceID;
		return;
	}
	
	vec3 pos = localPosition - rockPos;
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
	surface.localPosition = localPosition;
	surface.color = vec4(mix(sandColor, rockColor, rocky), 1);
	surface.color.rgb *= mix(0.5, 1.0, pow(abs(FastSimplexFractal(localPosition*255.658, detailOctavesTextures)) + (FastSimplexFractal(localPosition*29.123, detailOctavesTextures)*0.5+0.5), 0.5));
	surface.color.rgb *= pow(normal.y * 0.5 + 0.5, 0.25);
	surface.normal = normal;
	surface.metallic = 0;
	surface.roughness = 1;
	surface.emission = vec3(0);
	surface.ior = 1.45;
	surface.specular = rocky*0.5;
	
	// // Apply world space normal
	// ray.normal = normalize(MODEL2WORLDNORMAL * surface.normal);
	
	// Reverse gamma
	surface.color.rgb = ReverseGamma(surface.color.rgb);
	
	// // // Apply Lighting
	// // ApplyDefaultLighting();
	
	// // Store albedo and roughness (may remove this in the future)
	// if (RAY_RECURSIONS == 0) {
	// 	imageStore(img_primary_albedo_roughness, COORDS, vec4(surface.color.rgb, surface.roughness));
	// }
	
	ray.albedo = surface.color.rgb;
	ray.t1 = gl_HitTEXT;
	ray.normal = normalize(MODEL2WORLDNORMAL * surface.normal);
	ray.t2 = 0;
	ray.emission = surface.emission;
	ray.mask = 0;
	ray.transmittance = vec3(0);
	ray.ior = surface.ior;
	ray.reflectance = 0;
	ray.metallic = surface.metallic;
	ray.roughness = surface.roughness;
	ray.specular = surface.specular;
	ray.localPosition = surface.localPosition;
	ray.renderableIndex = gl_InstanceID;
}
