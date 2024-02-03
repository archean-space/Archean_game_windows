#define SHADER_RCHIT
#include "clutter_rock.common.inc.glsl"

void main() {
	vec3 localPosition = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * gl_HitTEXT;
	
	if (RAY_IS_SHADOW) {
		ray.t1 = gl_HitTEXT;
		ray.transmittance = vec3(0);
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
	
	// Reverse gamma
	surface.color.rgb = ReverseGamma(surface.color.rgb);
	
	// Ray Payload
	ray.albedo = surface.color.rgb;
	ray.t1 = gl_HitTEXT;
	ray.normal = normalize(MODEL2WORLDNORMAL * surface.normal);
	ray.t2 = 0;
	ray.emission = surface.emission;
	ray.transmittance = vec3(0);
	ray.ior = surface.ior;
	ray.reflectance = 0;
	ray.metallic = surface.metallic;
	ray.roughness = surface.roughness;
	ray.specular = surface.specular;
	ray.localPosition = surface.localPosition;
	ray.renderableIndex = gl_InstanceID;
	
	// Aim
	if (COORDS == ivec2(gl_LaunchSizeEXT.xy) / 2) {
		if (renderer.aim.aimID == 0) {
			renderer.aim.uv = surface.uv1;
			renderer.aim.localPosition = ray.localPosition;
			renderer.aim.geometryIndex = gl_GeometryIndexEXT;
			renderer.aim.aimID = gl_InstanceCustomIndexEXT;
			renderer.aim.worldSpaceHitNormal = ray.normal;
			renderer.aim.primitiveIndex = gl_PrimitiveID;
			renderer.aim.worldSpacePosition = gl_WorldRayOriginEXT + gl_WorldRayDirectionEXT * gl_HitTEXT;
			renderer.aim.hitDistance = ray.t1;
			renderer.aim.color = surface.color;
			renderer.aim.viewSpaceHitNormal = normalize(WORLD2VIEWNORMAL * ray.normal);
			renderer.aim.tlasInstanceIndex = gl_InstanceID;
		}
	}
	
	// Debug
	DEBUG_RAY_HIT_TIME
}
