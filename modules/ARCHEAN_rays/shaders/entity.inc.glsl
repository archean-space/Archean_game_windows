void main() {
	ENTITY_COMPUTE_SURFACE
	
	surface.distance = gl_HitTEXT;
	surface.localPosition = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * gl_HitTEXT;
	surface.metallic = GEOMETRY.material.metallic;
	surface.roughness = GEOMETRY.material.roughness;
	surface.emission = GEOMETRY.material.emission;
	surface.ior = 1.45;
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
	
	//executeCallableEXT(GEOMETRY.material.surfaceIndex, SURFACE_CALLABLE_PAYLOAD);
	
	#ifdef ENTITY_AFTER_SURFACE
		ENTITY_AFTER_SURFACE
	#endif
	
	// Ray Payload
	ray.albedo = surface.color.rgb * surface.color.a;
	ray.t1 = gl_HitTEXT;
	ray.normal = normalize(MODEL2WORLDNORMAL * surface.normal);
	ray.t2 = 0;
	ray.emission = surface.emission;
	ray.transmittance = surface.color.rgb * (1 - surface.color.a);
	ray.ior = surface.ior;
	ray.reflectance = step(0.999, (1 - surface.metallic) * (1 - surface.roughness));
	ray.metallic = surface.metallic;
	ray.roughness = surface.roughness;
	ray.specular = surface.specular;
	ray.localPosition = surface.localPosition;
	ray.renderableIndex = gl_InstanceID;

	if (RAY_IS_SHADOW) {
		return;
	}
	
	// Aim
	if (COORDS == ivec2(gl_LaunchSizeEXT.xy) / 2) {
		if (surface.renderableData != 0 && renderer.aim.monitorIndex == 0) {
			renderer.aim.uv = surface.uv1;
			renderer.aim.monitorIndex = RenderableData(surface.renderableData)[nonuniformEXT(surface.geometryIndex)].monitorIndex;
		}
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
