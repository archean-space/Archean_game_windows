#define SHADER_RCHIT
#include "common.inc.glsl"

hitAttributeEXT vec2 hitAttribs;

void main() {
	if (RAY_IS_SHADOW) {
		ray.t1 = gl_HitTEXT;
		ray.transmittance = vec3(0);
		return;
	}
	
	vec3 barycentricCoords = vec3(1.0f - hitAttribs.x - hitAttribs.y, hitAttribs.x, hitAttribs.y);
	surface.normal = ComputeSurfaceNormal(barycentricCoords);
	surface.color = ComputeSurfaceColor(barycentricCoords);
	surface.barycentricCoords = barycentricCoords;
	surface.distance = gl_HitTEXT;
	surface.localPosition = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * gl_HitTEXT;
	surface.metallic = 0;
	surface.roughness = 0.5;
	surface.emission = vec3(0);
	surface.ior = 1.45;
	surface.renderableData = INSTANCE.data;
	surface.aabbData = 0;
	surface.renderableIndex = gl_InstanceID;
	surface.geometryIndex = gl_GeometryIndexEXT;
	surface.primitiveIndex = gl_PrimitiveID;
	surface.geometries = uint64_t(INSTANCE.geometries);
	surface.geometryInfoData = GEOMETRY.material.data;
	surface.geometryUv1Data = GEOMETRY.material.uv1;
	surface.geometryUv2Data = GEOMETRY.material.uv2;
	surface.uv1 = vec2(0);
	surface.specular = 0;
	
	// executeCallableEXT(GEOMETRY.material.surfaceIndex, SURFACE_CALLABLE_PAYLOAD);
	
	// Fix black specs caused by skirts
	if (dot(surface.normal, vec3(0,1,0)) < 0.15) surface.normal = vec3(0,1,0);

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
	if (xenonRendererData.config.debugViewMode == RENDERER_DEBUG_VIEWMODE_UVS) {
		imageStore(img_normal_or_debug, COORDS, vec4(surface.uv1, 0, 1));
	}
}
