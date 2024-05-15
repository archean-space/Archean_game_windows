#define SHADER_RCHIT

#include "common.inc.glsl"
#include "lighting.inc.glsl"

hitAttributeEXT hit {
	float t2;
	VOXEL_INDEX_TYPE voxelIndex;
};

void main() {
	ray.hitDistance = -1;
	ray.renderableIndex = -1;
	
	bool rayIsShadow = RAY_IS_SHADOW;
	uint recursions = RAY_RECURSIONS;
	bool rayIsGi = RAY_IS_GI;
	// bool rayIsUnderWater = RAY_IS_UNDERWATER;
	
	vec3 worldPosition = gl_WorldRayOriginEXT + gl_WorldRayDirectionEXT * gl_HitTEXT;
	vec3 localPosition = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * gl_HitTEXT;
	
	uint8_t normalIndex = uint8_t(gl_HitKindEXT);
	if (normalIndex > 5) return;
	if (AABB.data == 0) return;
	ChunkVoxelData voxelData = ChunkVoxelData(AABB.data);
	
	// Prapare Surface
	voxelSurface.distance = gl_HitTEXT;
	voxelSurface.emission = vec3(0);
	voxelSurface.metallic = 0;
	voxelSurface.ior = 1.45;
	voxelSurface.diffuse = 1;
	voxelSurface.specular = 0;
	voxelSurface.voxelFace = normalIndex;
	voxelSurface.voxelFill = voxelData.fill[voxelIndex];
	voxelSurface.voxelData = voxelData.data[voxelIndex];
	voxelSurface.voxelIndex = uint16_t(voxelIndex);
	voxelSurface.chunkAddr = AABB.data;
	voxelSurface.color = vec4(vec3(0.5),1);
	voxelSurface.normal = BOX_NORMAL_DIRS[normalIndex];
	voxelSurface.geometryInfo = GEOMETRY.material;
	voxelSurface.renderableData = INSTANCE.data;
	if (dot(voxelSurface.normal, gl_WorldRayDirectionEXT) > 0) {
		voxelSurface.normal *= -1;
		voxelSurface.ior = 1.0 / voxelSurface.ior;
	}
	
	const ivec3 iPos = VoxelIndex_iPos(voxelIndex);
	voxelSurface.posInVoxel = localPosition - vec3(voxelData.aabbOffset + iPos) * voxelData.voxelSize;
	
	switch (int(normalIndex)) {
		case 0 : voxelSurface.uv = vec2(voxelSurface.posInVoxel.zy) * vec2(+1,-1) - vec2(VOXEL_GRID_OFFSET); break;
		case 1 : voxelSurface.uv = vec2(voxelSurface.posInVoxel.xz) * vec2(-1,-1) - vec2(VOXEL_GRID_OFFSET); break;
		case 2 : voxelSurface.uv = vec2(voxelSurface.posInVoxel.xy) * vec2(-1,-1) - vec2(VOXEL_GRID_OFFSET); break;
		case 3 : voxelSurface.uv = vec2(voxelSurface.posInVoxel.zy) * vec2(-1,-1) - vec2(VOXEL_GRID_OFFSET); break;
		case 4 : voxelSurface.uv = vec2(voxelSurface.posInVoxel.xz) * vec2(+1,+1) - vec2(VOXEL_GRID_OFFSET); break;
		case 5 : voxelSurface.uv = vec2(voxelSurface.posInVoxel.xy) * vec2(+1,-1) - vec2(VOXEL_GRID_OFFSET); break;
	}
	
	// Execute Surface Callable
	// if (OPTION_TEXTURES) {
		executeCallableEXT(GEOMETRY.material.surfaceIndex + uint32_t(voxelData.type[voxelIndex]), VOXEL_SURFACE_CALLABLE_PAYLOAD);
	// }
	
	if (rayIsShadow) {
		if (voxelSurface.color.a > 0.95) {
			ray.hitDistance = 0;
			ray.color.a = 1;
		} else {
			ray.color = voxelSurface.color;
			ray.hitDistance = gl_HitTEXT;
			ray.renderableIndex = -1;
			ray.t2 = t2;
		}
		return;
	}
	
	voxelSurface.normal = normalize(MODEL2WORLDNORMAL * voxelSurface.normal);
	
	VoxelSurface thisSurface = voxelSurface;
	float fresnel = Fresnel(normalize((renderer.viewMatrix * vec4(worldPosition, 1)).xyz), normalize(WORLD2VIEWNORMAL * thisSurface.normal), thisSurface.ior);
	
	// const vec3 rayOrigin = worldPosition + thisSurface.normal * 0.0001;
	// const vec3 facingWorldPosition = worldPosition + thisSurface.normal * 0.5;
	// const uint giIndex = GetGiIndex(facingWorldPosition, 0);
	// const uint giIndex1 = GetGiIndex(facingWorldPosition, 1);
	// seed += recursions * RAY_MAX_RECURSION;
	
	// if ((xenonRendererData.config.options & RENDER_OPTION_GROUND_TRUTH) != 0) {
	// 	// Path Tracing
	// 	const float bounce_probabilities = 0.333;
	// 	if (recursions < RAY_MAX_RECURSION && RandomFloat(seed) < bounce_probabilities) {
	// 		vec3 reflectDir = normalize(reflect(gl_WorldRayDirectionEXT, thisSurface.normal));
	// 		vec3 randomDir = normalize(RandomInUnitSphere(seed));
	// 		vec3 bounceDirection = normalize(mix(reflectDir, normalize(thisSurface.normal + randomDir), clamp(thisSurface.diffuse*thisSurface.diffuse, 0, 1)));
	// 		if (RandomFloat(seed) < thisSurface.specular * fresnel) {
	// 			// Specular Reflection
	// 			bounceDirection = reflectDir;
	// 		} else if (RandomFloat(seed) < thisSurface.metallic) {
	// 			// Metallic Reflection
	// 			bounceDirection = normalize(mix(reflectDir, bounceDirection, thisSurface.diffuse*thisSurface.diffuse));
	// 		} else if (RandomFloat(seed) > thisSurface.color.a) {
	// 			// Refraction
	// 			vec3 refractDir = gl_WorldRayDirectionEXT;
	// 			Refract(refractDir, thisSurface.normal, thisSurface.ior);
	// 			bounceDirection = normalize(mix(refractDir, bounceDirection, thisSurface.diffuse*thisSurface.diffuse));
	// 		}
	// 		RAY_RECURSION_PUSH
	// 			traceRayEXT(tlas, 0, 0xff, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, rayOrigin, xenonRendererData.config.zNear, bounceDirection, xenonRendererData.config.zFar, 0);
	// 		RAY_RECURSION_POP
	// 		ray.color.rgb /= mix(3.141592654, 1, thisSurface.metallic);
	// 	}
	// 	ray.color.rgb *= thisSurface.color.rgb;
	// 	ray.color.rgb /= bounce_probabilities;
	// } else if (recursions < RAY_MAX_RECURSION && LockAmbientLighting(giIndex)) {
	// 	vec3 bounceDirection = normalize(thisSurface.normal + RandomInUnitSphere(seed));
	// 	float nDotL = clamp(dot(thisSurface.normal, bounceDirection), 0, 1);
	// 	RAY_RECURSION_PUSH
	// 		RAY_GI_PUSH
	// 			traceRayEXT(tlas, 0, ~(RAYTRACE_MASK_HYDROSPHERE | RAYTRACE_MASK_CLUTTER), 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, facingWorldPosition, xenonRendererData.config.zNear, bounceDirection, 1000, 0);
	// 		RAY_GI_POP
	// 	RAY_RECURSION_POP
	// 	ray.color.rgb *= nDotL;
	// 	ray.color.rgb *= smoothstep(32, 0, ray.hitDistance);
	// 	WriteAmbientLighting(giIndex, facingWorldPosition, BOX_NORMAL_DIRS[normalIndex], ray.color.rgb);
	// 	UnlockAmbientLighting(giIndex);
	// }
	// if (!rayIsGi && (xenonRendererData.config.options & RENDER_OPTION_GROUND_TRUTH) == 0) {
	// 	ray.color.rgb = thisSurface.color.rgb * GetAmbientLighting(giIndex1, facingWorldPosition, thisSurface.posInVoxel, BOX_NORMAL_DIRS[normalIndex]);
	// }
	
	if (RAY_RECURSIONS < RAY_MAX_RECURSION) {
	
		// // Direct Lighting
		// vec3 color = ray.color.rgb;
		// ray.color = vec4(0);
		// vec3 sunDir = normalize(renderer.sunDir);
		// float nDotL = dot(thisSurface.normal, sunDir);
		// vec3 directLighting = vec3(0);
		// if (nDotL > 0) {
		// 	float shadowRayStart = xenonRendererData.config.zNear;
		// 	RAY_RECURSION_PUSH
		// 		RAY_SHADOW_PUSH
		// 			vec3 colorFilter = vec3(1);
		// 			float opacity = 0;
		// 			const float MAX_SHADOW_TRANSPARENCY_RAYS = 2;
		// 			for (int i = 0; i < MAX_SHADOW_TRANSPARENCY_RAYS; ++i) {
		// 				traceRayEXT(tlas, 0, ~(RAYTRACE_MASK_HYDROSPHERE | RAYTRACE_MASK_ATMOSPHERE), 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, rayOrigin, shadowRayStart, sunDir, xenonRendererData.config.zFar, 0);
		// 				if (ray.hitDistance == -1) {
		// 					// lit
		// 					if (rayIsGi) {
		// 						directLighting = pow(thisSurface.color.rgb * ray.color.rgb, vec3(0.25)) * 0.5;
		// 					} else {
		// 						directLighting = thisSurface.color.rgb * renderer.skyLightColor * nDotL;
		// 					}
		// 					directLighting *= colorFilter * (1 - clamp(opacity,0,1));
		// 					break;
		// 				} else {
		// 					colorFilter *= ray.color.rgb;
		// 					opacity += max(0.05, ray.color.a);
		// 					shadowRayStart = max(ray.hitDistance, ray.t2) * 1.001;
		// 				}
		// 				if (opacity > 0.95) break;
		// 			}
		// 		RAY_SHADOW_POP
		// 	RAY_RECURSION_POP
		// }
		
		// vec3 directLighting = GetBasicDirectLighting(thisSurface.worldPosition, thisSurface.normal);
		// ray.color.rgb *= directLighting;
		
		
		if (!rayIsGi) {
			
			// Metallic (Perfect Reflections)
			if (thisSurface.metallic + thisSurface.specular > 0) {
				vec3 color = ray.color.rgb;
				ray.color = vec4(0);
				vec3 reflectDir = normalize(reflect(gl_WorldRayDirectionEXT, thisSurface.normal));
				RAY_RECURSION_PUSH
					traceRayEXT(tlas, 0, 0xff, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, worldPosition, xenonRendererData.config.zNear, reflectDir, xenonRendererData.config.zFar, 0);
				RAY_RECURSION_POP
				ray.color.rgb = mix(color + ray.color.rgb * fresnel * thisSurface.specular, thisSurface.color.rgb*ray.color.rgb, thisSurface.metallic);
			}
			
			// Transparent (Refractions)
			if (thisSurface.color.a < 1) {
				vec3 rayDirection = gl_WorldRayDirectionEXT;
				if (Refract(rayDirection, thisSurface.normal, thisSurface.ior)) {
					const vec3  _invDir = 1.0 / (mat3(gl_WorldToObjectEXT) * normalize(rayDirection));
					const vec3  _tbot   = _invDir * (AABB_MIN - localPosition);
					const vec3  _ttop   = _invDir * (AABB_MAX - localPosition);
					const vec3  _tmax   = max(_ttop, _tbot);
					const vec3  _tmin   = min(_ttop, _tbot);
					const float t1      = max(_tmin.x, max(_tmin.y, _tmin.z));
					const float refracted_t2      = min(_tmax.x, min(_tmax.y, _tmax.z));
					vec3 t2Position = worldPosition + rayDirection * (refracted_t2 - t1);
					if (Refract(rayDirection, thisSurface.normal, 1.0/thisSurface.ior)) {
						RAY_RECURSION_PUSH
							traceRayEXT(tlas, 0, 0xff, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, t2Position, 0, rayDirection, xenonRendererData.config.zFar, 0);
						RAY_RECURSION_POP
						ray.color.rgb *= thisSurface.color.rgb * (1-thisSurface.color.a);
					}
				}
			}
		}
	}
	
	// Standard payload info
	ray.hitDistance = gl_HitTEXT;
	ray.aimID = gl_InstanceCustomIndexEXT;
	ray.renderableIndex = gl_InstanceID;
	ray.geometryIndex = gl_GeometryIndexEXT;
	ray.primitiveIndex = gl_PrimitiveID;
	ray.localPosition = localPosition;
	ray.worldPosition = worldPosition;
	ray.ssao = 1;
	ray.t2 = t2;
	
	// Opacity
	ray.color.a = thisSurface.color.a;
	
	// Emission
	ray.color.rgb += thisSurface.emission;
	
	// Normal
	ray.normal = thisSurface.normal;
	
	// Gi
	if (rayIsGi) {
		return;
	}

	// Overlays
	if (recursions == 0) {
		// Aim Wireframe
		if (renderer.aim.aimID == gl_InstanceCustomIndexEXT && renderer.aim.geometryIndex == gl_GeometryIndexEXT && renderer.aim.primitiveIndex == gl_PrimitiveID) {
			if (ivec3(round(renderer.aim.localPosition - renderer.aim.worldSpaceHitNormal*0.01)) == ivec3(round(ray.localPosition - ray.normal * 0.01))) {
				vec2 coord = abs(fract(thisSurface.uv) - 0.5);
				float thickness = renderer.wireframeThickness * xenonRendererData.config.renderScale * max(1, ray.hitDistance);
				float border = step(0.5-thickness, max(coord.x, coord.y));
				ray.color = vec4(mix(ray.color.rgb, renderer.wireframeColor.rgb, border), ray.color.a);
			}
		}
		const ivec2 imgCoords = ivec2(gl_LaunchIDEXT.xy);
		if (xenonRendererData.config.debugViewMode == RENDERER_DEBUG_VIEWMODE_UVS) {
			imageStore(img_normal_or_debug, imgCoords, vec4(thisSurface.uv, 0, 1));
		}
	}
	
	// Adjust normals
	const float bias = 0.002;
	float rDotN = dot(gl_WorldRayDirectionEXT, ray.normal);
	if (rDotN < 0.5 && rDotN > -bias) {
		vec3 tmp = normalize(cross(gl_WorldRayDirectionEXT, ray.normal));
		ray.normal = normalize(mix(-gl_WorldRayDirectionEXT, normalize(cross(-gl_WorldRayDirectionEXT, tmp)), 1.0-bias));
	}
	
	// Debug Time
	if (xenonRendererData.config.debugViewMode == RENDERER_DEBUG_VIEWMODE_RAYHIT_TIME) {
		if (recursions == 0) WRITE_DEBUG_TIME
	}
}
