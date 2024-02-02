#define SHADER_RCHIT
#include "common.inc.glsl"
#include "lighting.inc.glsl"

hitAttributeEXT vec3 hitAttribs;

void main() {
	
	// ray.hitDistance = gl_HitTEXT;
	// ray.aimID = gl_InstanceCustomIndexEXT;
	// ray.renderableIndex = gl_InstanceID;
	// ray.geometryIndex = gl_GeometryIndexEXT;
	// ray.primitiveIndex = gl_PrimitiveID;
	// ray.localPosition = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * gl_HitTEXT;
	// ray.worldPosition = gl_WorldRayOriginEXT + gl_WorldRayDirectionEXT * gl_HitTEXT;
	// ray.t2 = 0;
	// ray.ssao = 0.75;
	
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
	
	// // Terrain is always fully opaque
	// ray.color.a = 1;
	
	// if (RAY_IS_SHADOW) {
	// 	return;
	// }
	
	// if (OPTION_TEXTURES) {
		executeCallableEXT(GEOMETRY.material.surfaceIndex, SURFACE_CALLABLE_PAYLOAD);
	// }
	
	// // Debug UV1
	// if (xenonRendererData.config.debugViewMode == RENDERER_DEBUG_VIEWMODE_UVS) {
	// 	if (RAY_RECURSIONS == 0) imageStore(img_normal_or_debug, COORDS, vec4(surface.uv1, 0, 1));
	// 	ray.normal = vec3(0);
	// 	ray.color = vec4(0,0,0,1);
	// 	return;
	// }
	
	// Fix black specs caused by skirts
	if (dot(surface.normal, vec3(0,1,0)) < 0.15) surface.normal = vec3(0,1,0);

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
