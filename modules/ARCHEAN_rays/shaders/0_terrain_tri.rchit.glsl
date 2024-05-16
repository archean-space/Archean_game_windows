#define SHADER_RCHIT
#include "common.inc.glsl"
#include "lighting.inc.glsl"

hitAttributeEXT vec3 hitAttribs;

void main() {
	// Terrain is always fully opaque
	ray.hitDistance = gl_HitTEXT;
	ray.renderableIndex = gl_InstanceID;
	ray.geometryIndex = gl_GeometryIndexEXT;
	ray.primitiveIndex = gl_PrimitiveID;
	ray.t2 = 0;
	
	if (RAY_IS_SHADOW) {
		ray.color = vec4(vec3(0.5), 1);
		return;
	}
	
	uint rayRecursions = RAY_RECURSIONS;
	
	vec3 barycentricCoords = vec3(1.0f - hitAttribs.x - hitAttribs.y, hitAttribs.x, hitAttribs.y);
	surface.normal = ComputeSurfaceNormal(barycentricCoords);
	surface.color = ComputeSurfaceColor(barycentricCoords);
	surface.barycentricCoords = barycentricCoords;
	surface.distance = ray.hitDistance;
	surface.localPosition = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * gl_HitTEXT;
	surface.metallic = 0;
	surface.roughness = 1;
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
	
	ray.color.a = 1;
	
	if (renderer.terrain_detail > 0.4) {
		executeCallableEXT(GEOMETRY.material.surfaceIndex, SURFACE_CALLABLE_PAYLOAD);
	}
	
	// Debug UV1
	if (xenonRendererData.config.debugViewMode == RENDERER_DEBUG_VIEWMODE_UVS) {
		if (RAY_RECURSIONS == 0) imageStore(img_normal_or_debug, COORDS, vec4(surface.uv1, 0, 1));
		ray.normal = vec3(0);
		ray.color = vec4(0,0,0,1);
		return;
	}
	
	// Fix black specs caused by skirts
	if (dot(surface.normal, vec3(0,1,0)) < 0.15) surface.normal = vec3(0,1,0);

	// Apply world space normal
	ray.normal = normalize(MODEL2WORLDNORMAL * surface.normal);
	
	ray.ior = surface.ior;
	
	// Reverse gamma
	surface.color.rgb = ReverseGamma(surface.color.rgb);
	
	MakeAimable(ray.normal);

	// Write Motion Vectors
	WriteMotionVectorsAndDepth(ray.renderableIndex, gl_WorldRayOriginEXT + gl_WorldRayDirectionEXT * gl_HitTEXT, gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * gl_HitTEXT, ray.hitDistance, false);
	
	// Apply Lighting
	ApplyDefaultLighting();
	
	// Debug Time
	if (xenonRendererData.config.debugViewMode == RENDERER_DEBUG_VIEWMODE_RAYHIT_TIME) {
		if (rayRecursions == 0) WRITE_DEBUG_TIME
	}
}
