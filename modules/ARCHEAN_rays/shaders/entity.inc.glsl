#include "lighting.inc.glsl"

void main() {
	uint rayRecursions = RAY_RECURSIONS;
	
	ray.hitDistance = gl_HitTEXT;
	ray.renderableIndex = gl_InstanceID;
	ray.geometryIndex = gl_GeometryIndexEXT;
	ray.primitiveIndex = gl_PrimitiveID;
	ray.t2 = 0;
	
	ENTITY_COMPUTE_SURFACE
	
	surface.distance = ray.hitDistance;
	surface.localPosition = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * gl_HitTEXT;
	surface.metallic = GEOMETRY.material.metallic;
	surface.roughness = GEOMETRY.material.roughness;
	surface.emission = GEOMETRY.material.emission;
	surface.ior = 1.5;
	surface.renderableData = INSTANCE.data;
	surface.renderableIndex = gl_InstanceID;
	surface.geometryIndex = gl_GeometryIndexEXT;
	surface.primitiveIndex = gl_PrimitiveID;
	surface.geometries = uint64_t(INSTANCE.geometries);
	surface.geometryInfoData = GEOMETRY.material.data;
	surface.geometryUv1Data = GEOMETRY.material.uv1;
	surface.geometryUv2Data = GEOMETRY.material.uv2;
	surface.uv1 = vec2(0);
	surface.specular = step(0.1, surface.roughness) * (0.5 + surface.metallic * 0.5);
	
	// if (OPTION_TEXTURES) {
		executeCallableEXT(GEOMETRY.material.surfaceIndex, SURFACE_CALLABLE_PAYLOAD);
	// }
	
	#ifdef ENTITY_AFTER_SURFACE
		ENTITY_AFTER_SURFACE
	#endif
	
	// Debug UV1
	if (xenonRendererData.config.debugViewMode == RENDERER_DEBUG_VIEWMODE_UVS) {
		if (!RAY_IS_SHADOW && rayRecursions == 0) imageStore(img_normal_or_debug, COORDS, vec4(surface.uv1, 0, 1));
		ray.normal = vec3(0);
		ray.color = vec4(0,0,0,1);
		return;
	}
	
	ray.normal = normalize(MODEL2WORLDNORMAL * surface.normal);
	ray.ior = surface.ior;
	
	if (RAY_IS_SHADOW) {
		ray.color = surface.color;
		return;
	}
	
	// Aim
	if (rayRecursions < 2) {
		if (COORDS == ivec2(gl_LaunchSizeEXT.xy) / 2) {
			if (surface.renderableData != 0 && renderer.aim.monitorIndex == 0) {
				renderer.aim.uv = surface.uv1;
				renderer.aim.monitorIndex = RenderableData(surface.renderableData)[nonuniformEXT(surface.geometryIndex)].monitorIndex;
			}
		}
		MakeAimable();
	}

	// Write Motion Vectors
	WriteMotionVectorsAndDepth(ray.renderableIndex, gl_WorldRayOriginEXT + gl_WorldRayDirectionEXT * gl_HitTEXT, surface.localPosition, ray.hitDistance, false);
	
	if (surface.color.a < 1.0) {
		ray.color = surface.color;
		return;
	}
	
	// Apply Lighting
	ApplyDefaultLighting();
	
	// Glossy surfaces
	if (surface.metallic == 0.0 && surface.roughness == 0.0) {
		ray.color.a = 2.0;
	}
	
	// Debug Time
	if (xenonRendererData.config.debugViewMode == RENDERER_DEBUG_VIEWMODE_RAYHIT_TIME) {
		if (RAY_RECURSIONS == 0) WRITE_DEBUG_TIME
	}
}
