#define SHADER_RGEN
#include "../common.inc.glsl"

layout(location = 0) rayPayloadEXT RayPayload ray;
layout(location = 1) rayPayloadEXT RayShadowPayload shadowRay;

uint64_t startTime = clockARB();
uint stableSeed = InitRandomSeed(gl_LaunchIDEXT.x, gl_LaunchIDEXT.y);
uint coherentSeed = InitRandomSeed(uint(xenonRendererData.frameIndex),0);
uint temporalSeed = uint(int64_t(renderer.timestamp * 1000) % 1000000);
uint seed = InitRandomSeed(stableSeed, coherentSeed);
uint traceRayCount = 0;
uint glossyRayCount = 0;
uint nbDirectLights = 0;
float currentIOR = 1.0;
float ssao = 1;
float alpha = 0;

#define NB_LIGHTS 8
#define SORT_LIGHTS
#define EPSILON 0.0001
#define LIGHT_LUMINOSITY_VISIBLE_THRESHOLD 0.01

vec3 MapUVToSphere(vec2 uv) {
	uv += vec2(RandomFloat(coherentSeed), RandomFloat(coherentSeed)) / 100;
	float theta = 2.0 * 3.1415926 * uv.x;
	float phi = acos(2.0 * uv.y - 1.0);
	theta += RandomFloat(coherentSeed) * 0.01;
	phi += RandomFloat(coherentSeed) * 0.01;
	vec3 spherePoint;
	spherePoint.x = sin(phi) * cos(theta);
	spherePoint.y = sin(phi) * sin(theta);
	spherePoint.z = cos(phi);
	return normalize(spherePoint);
}

struct Reservoir {
	vec3 lightPos;
	vec3 lightColor;
	float lightPower;
	float lightRadius;
	float totalLightJuice;
};

void ReservoirMix(inout Reservoir res, in vec3 lightPos, in vec3 lightColor, in float lightPower, in float lightRadius) {
	if (lightPower <= 0) return;
	
	// If our reservoir is as empty as a politician's promise, grab this candidate outright.
	if (res.totalLightJuice == 0.0) {
		res.lightPos = lightPos;
		res.lightColor = lightColor;
		res.lightPower = lightPower;
		res.lightRadius = lightRadius;
		res.totalLightJuice = lightPower;
	} else {
		// Update the reservoir's total "light juice"
		float newTotal = res.totalLightJuice + lightPower;
		
		// Calculate the chance that this new candidate, which is hopefully not a total dud,
		// should replace our current favorite. Brighter (heavier) lights get a better shot.
		float replacementProb = lightPower / newTotal;
		
		// Roll the dice: if the random float is less than the replacement probability,
		// then this light gets a chance to steal the spotlight.
		if (RandomFloat(seed) < replacementProb) {
			res.lightPos = lightPos;
			res.lightColor = lightColor;
			res.lightPower = lightPower;
			res.lightRadius = lightRadius;
		}
		
		// Update our cumulative weight with the new candidate's intensity.
		res.totalLightJuice = newTotal;
	}
}

vec3 GetDirectLighting(in vec3 worldPosition, in vec3 rayDirection, in vec3 normal, in vec3 albedo, in float metallic, in float roughness, in float specular, in float specularHardness) {
	if ((renderer.options & RENDERER_OPTION_DIRECT_LIGHTING) == 0) return vec3(0);
	
	float referenceDistance = length(worldPosition - inverse(renderer.viewMatrix)[3].xyz);
	float epsilonDistance = EPSILON * max(1, referenceDistance);
	vec3 position = worldPosition + normal * epsilonDistance;
	vec3 directLighting = vec3(0);
	
	rayQueryEXT q;
	rayQueryInitializeEXT(q, tlas_lights, 0, 0xff, position, 0, vec3(0,1,0), 0);
	
	Reservoir res[2];
	for (int i = 0; i < 2; ++i) {
		res[i].totalLightJuice = 0;
	}
	
	while (rayQueryProceedEXT(q)) {
		++nbDirectLights;
		mat4 lightTransform = mat4(rayQueryGetIntersectionObjectToWorldEXT(q, false));
		vec3 lightPosition = lightTransform[3].xyz;
		int lightID = rayQueryGetIntersectionInstanceIdEXT(q, false);
		vec3 relativeLightPosition = lightPosition - position;
		vec3 lightDir = normalize(relativeLightPosition);
		float nDotL = dot(normal, lightDir);
		LightSourceInstanceData lightSource = renderer.lightSources[lightID].instance;
		float distanceToLightSurface = length(relativeLightPosition) - abs(lightSource.innerRadius);
		if (distanceToLightSurface < epsilonDistance) {
			if (lightSource.innerRadius > 0) {
				if (lightSource.angle == 0 || dot(normal, (mat3(lightTransform) * lightSource.direction)) > 0.01) {
					directLighting += lightSource.color * lightSource.power;
				}
			}
		} else if (nDotL > 0 && distanceToLightSurface < lightSource.maxDistance) {
			float penombra = 1;
			float surfaceArea = 4 * PI;
			if (lightSource.angle > 0) {
				surfaceArea = 2 * lightSource.angle;
				vec3 spotlightDirection = (lightTransform * vec4(lightSource.direction, 0)).xyz;
				float spotlightHalfAngle = lightSource.angle * 0.5;
				penombra = smoothstep(spotlightHalfAngle, spotlightHalfAngle * 0.8, acos(dot(-lightDir, spotlightDirection)));
				if (penombra == 0) continue;
			}
			float effectiveLightIntensity = max(0, lightSource.power / (surfaceArea * distanceToLightSurface*distanceToLightSurface + 1) - LIGHT_LUMINOSITY_VISIBLE_THRESHOLD) * penombra;
			int reservoirIndex = lightSource.power > renderer.lightReservoirSunPowerThreshold ? 0 : 1;
			ReservoirMix(res[reservoirIndex], lightPosition, lightSource.color, effectiveLightIntensity, abs(lightSource.innerRadius));
		}
	}
	
	for (int reservoirIndex = 0; reservoirIndex < 2; ++reservoirIndex) {
		if (res[reservoirIndex].totalLightJuice > 0) {
			vec3 relativeLightPosition = res[reservoirIndex].lightPos - position;
			vec3 shadowRayDir = normalize(relativeLightPosition);
			
			if (dot(shadowRayDir, normal) > 0) {
				float distanceToLightSurface = length(relativeLightPosition) - res[reservoirIndex].lightRadius;
				
				// Soft Shadows
				vec2 rnd = vec2(RandomFloat(seed), RandomFloat(seed));
				float pointRadius = res[reservoirIndex].lightRadius / distanceToLightSurface * rnd.x;
				float pointAngle = rnd.y * 2.0 * PI;
				vec2 diskPoint = vec2(pointRadius * cos(pointAngle), pointRadius * sin(pointAngle));
				vec3 lightTangent = normalize(cross(shadowRayDir, normal));
				vec3 lightBitangent = normalize(cross(lightTangent, shadowRayDir));
				shadowRayDir = normalize(shadowRayDir + diskPoint.x * lightTangent + diskPoint.y * lightBitangent);
				
				shadowRay.colorAttenuation = vec3(1);
				shadowRay.hitDistance = distanceToLightSurface - epsilonDistance;
				shadowRay.rayFlags = 0u;
				++traceRayCount;
				// if (dot(res[reservoirIndex].lightPos, res[reservoirIndex].lightPos) > dot(position, position)) {
				// 	traceRayEXT(tlas, gl_RayFlagsNoOpaqueEXT | gl_RayFlagsSkipClosestHitShaderEXT, RAYTRACE_MASK_TERRAIN|RAYTRACE_MASK_ENTITY|RAYTRACE_MASK_CLUTTER|RAYTRACE_MASK_LIQUID, 0/*rayType*/, 0/*nbRayTypes*/, 1/*missIndex*/, position, 0, shadowRayDir, shadowRay.hitDistance, 1);
				// } else {
				// 	traceRayEXT(tlas, gl_RayFlagsNoOpaqueEXT | gl_RayFlagsSkipClosestHitShaderEXT, RAYTRACE_MASK_TERRAIN|RAYTRACE_MASK_ENTITY|RAYTRACE_MASK_CLUTTER|RAYTRACE_MASK_LIQUID, 0/*rayType*/, 0/*nbRayTypes*/, 1/*missIndex*/, res[reservoirIndex].lightPos, res[reservoirIndex].lightRadius, -shadowRayDir, shadowRay.hitDistance, 1);
				// }
				if (dot(res[reservoirIndex].lightPos, res[reservoirIndex].lightPos) > dot(position, position)) {
					traceRayEXT(tlas, gl_RayFlagsNoOpaqueEXT | gl_RayFlagsSkipClosestHitShaderEXT | gl_RayFlagsTerminateOnFirstHitEXT | gl_RayFlagsCullBackFacingTrianglesEXT, RAYTRACE_MASK_TERRAIN, 0/*rayType*/, 0/*nbRayTypes*/, 1/*missIndex*/, position, 0, shadowRayDir, shadowRay.hitDistance, 1);
					traceRayEXT(tlas, gl_RayFlagsNoOpaqueEXT | gl_RayFlagsSkipClosestHitShaderEXT, RAYTRACE_MASK_ENTITY|RAYTRACE_MASK_CLUTTER|RAYTRACE_MASK_LIQUID, 0/*rayType*/, 0/*nbRayTypes*/, 1/*missIndex*/, position, 0, shadowRayDir, shadowRay.hitDistance, 1);
				} else {
					traceRayEXT(tlas, gl_RayFlagsNoOpaqueEXT | gl_RayFlagsSkipClosestHitShaderEXT | gl_RayFlagsTerminateOnFirstHitEXT | gl_RayFlagsCullBackFacingTrianglesEXT, RAYTRACE_MASK_TERRAIN, 0/*rayType*/, 0/*nbRayTypes*/, 1/*missIndex*/, res[reservoirIndex].lightPos, res[reservoirIndex].lightRadius, -shadowRayDir, shadowRay.hitDistance, 1);
					traceRayEXT(tlas, gl_RayFlagsNoOpaqueEXT | gl_RayFlagsSkipClosestHitShaderEXT, RAYTRACE_MASK_ENTITY|RAYTRACE_MASK_CLUTTER|RAYTRACE_MASK_LIQUID, 0/*rayType*/, 0/*nbRayTypes*/, 1/*missIndex*/, res[reservoirIndex].lightPos, res[reservoirIndex].lightRadius, -shadowRayDir, shadowRay.hitDistance, 1);
				}
				vec3 light = res[reservoirIndex].lightColor * res[reservoirIndex].totalLightJuice;
				float NdotL = clamp(dot(normal, shadowRayDir), 0, 1);
				vec3 diffuse = albedo * NdotL * (1 - metallic) * mix(0.5, 1, roughness);
				vec3 H = normalize(shadowRayDir - rayDirection);
				float NdotH = clamp(dot(normal, H), 0, 1);
				vec3 spec = pow(NdotH, specularHardness) * mix(vec3(1), albedo, metallic); // Fresnel is applied to specular from the caller
				directLighting += shadowRay.colorAttenuation * light * (diffuse + spec * specular);
			}
		}
	}
	
	return directLighting;
}

void TraceFogRay(in vec3 rayOrigin, in vec3 rayDirection, in float maxDistance, inout vec3 colorFilter) {
	shadowRay.colorAttenuation = vec3(1);
	shadowRay.emission = vec3(0);
	shadowRay.hitDistance = maxDistance;
	shadowRay.rayFlags = SHADOW_RAY_FLAG_EMISSION;
	++traceRayCount;
	traceRayEXT(tlas, gl_RayFlagsNoOpaqueEXT | gl_RayFlagsSkipClosestHitShaderEXT/*flags*/, RAYTRACE_MASK_LIQUID, 0/*rayType*/, 0/*nbRayTypes*/, 1/*missIndex*/, rayOrigin, EPSILON * 100, rayDirection, maxDistance, 1/*payloadIndex*/);
	++traceRayCount;
	traceRayEXT(tlas, gl_RayFlagsNoOpaqueEXT | gl_RayFlagsSkipClosestHitShaderEXT/*flags*/, RAYTRACE_MASK_FOG /*| RAYTRACE_MASK_VOLUME*/, 0/*rayType*/, 0/*nbRayTypes*/, 1/*missIndex*/, rayOrigin, EPSILON * 100, rayDirection, maxDistance, 1/*payloadIndex*/);
	if (dot(shadowRay.emission, shadowRay.emission) > 0) {
		imageStore(img_composite, COORDS, vec4(shadowRay.emission * colorFilter, 0) + imageLoad(img_composite, COORDS));
	}
	colorFilter *= shadowRay.colorAttenuation;
}

vec3 TraceAmbientLighting(in vec3 surfaceWorldPosition, in vec3 rayNormal, inout vec3 albedo) {
	if ((renderer.options & RENDERER_OPTION_RT_AMBIENT_LIGHTING) == 0) return albedo * 0.01 / GetCurrentExposure();

	float ambientFactor = 1;
	if (renderer.ambientOcclusionSamples > 0) {
		const float maxAmbientDistance = renderer.ambientOcclusionSamples * 10;
		float avgHitDistance = 0;
		for (int i = 0; i < renderer.ambientOcclusionSamples; ++i) {
			shadowRay.hitDistance = maxAmbientDistance;
			vec3 rayDirection = normalize(RandomInUnitHemiSphere(seed, rayNormal));
			traceRayEXT(tlas, gl_RayFlagsNoOpaqueEXT | gl_RayFlagsSkipClosestHitShaderEXT/*flags*/, RAYTRACE_MASK_TERRAIN|RAYTRACE_MASK_ENTITY|RAYTRACE_MASK_CLUTTER, 0/*rayType*/, 0/*nbRayTypes*/, 1/*missIndex*/, surfaceWorldPosition + rayNormal * EPSILON, 0, rayDirection, maxAmbientDistance, 1/*payloadIndex*/);
			avgHitDistance += shadowRay.hitDistance;
		}
		ambientFactor = pow(clamp(avgHitDistance / maxAmbientDistance / renderer.ambientOcclusionSamples, 0, 1), 2);
	}
	
	// Ambient lighting
	shadowRay.colorAttenuation = vec3(1);
	shadowRay.emission = vec3(0);
	shadowRay.hitDistance = 100000;
	shadowRay.rayFlags = SHADOW_RAY_FLAG_EMISSION;
	++traceRayCount;
	vec3 bounceDirection = normalize(RandomInUnitHemiSphere(seed, rayNormal));
	traceRayEXT(tlas, gl_RayFlagsNoOpaqueEXT | gl_RayFlagsSkipClosestHitShaderEXT/*flags*/, RAYTRACE_MASK_FOG|RAYTRACE_MASK_TERRAIN, 0/*rayType*/, 0/*nbRayTypes*/, 1/*missIndex*/, surfaceWorldPosition + rayNormal * EPSILON, 0, bounceDirection, shadowRay.hitDistance, 1/*payloadIndex*/);
	vec3 ambient = shadowRay.emission * 0.1;
	shadowRay.rayFlags = 0;
	shadowRay.hitDistance = 0;
	++traceRayCount;
	traceRayEXT(tlas, gl_RayFlagsNoOpaqueEXT | gl_RayFlagsSkipClosestHitShaderEXT/*flags*/, RAYTRACE_MASK_LIQUID, 0/*rayType*/, 0/*nbRayTypes*/, 1/*missIndex*/, surfaceWorldPosition, 0, bounceDirection, 0, 1/*payloadIndex*/);
	return pow(ambient, vec3(0.5)) * albedo * shadowRay.colorAttenuation * ambientFactor;
}

bool TraceGlossyRay(inout vec3 rayOrigin, inout vec3 rayDirection, inout vec3 colorFilter) {
	uint rayMask = RAYTRACE_MASK_SOLID;
	if ((ray.rayFlags & RAY_FLAG_FLUID) == 0) {
		rayMask |= RAYTRACE_MASK_LIQUID;
	}
	ray.renderableIndex = -1;
	ray.surfaceFlags = uint8_t(0);
	++traceRayCount;
	traceRayEXT(tlas, gl_RayFlagsOpaqueEXT/*flags*/, rayMask, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, rayOrigin, 0, rayDirection, xenonRendererData.config.zFar, 0/*payloadIndex*/);
	int hitRenderableIndex = ray.renderableIndex;
	
	if (hitRenderableIndex == -1) {
		// First ray hit nothing
		TraceFogRay(rayOrigin, rayDirection, xenonRendererData.config.zFar, colorFilter);
		return false;
	} else {
		// Fix Z fighting with interior faces of glass
		if (ray.ior == 0) {
			RayPayload originalRay = ray;
			float epsilon = clamp(EPSILON * originalRay.hitDistance, EPSILON, 0.1);
			++traceRayCount;
			ray.renderableIndex = -1;
			ray.surfaceFlags = uint8_t(0);
			traceRayEXT(tlas, gl_RayFlagsCullBackFacingTrianglesEXT|gl_RayFlagsOpaqueEXT/*flags*/, RAYTRACE_MASK_SOLID, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, rayOrigin, originalRay.hitDistance - epsilon, rayDirection, originalRay.hitDistance + epsilon, 0/*payloadIndex*/);
			if (ray.renderableIndex == -1) {
				ray = originalRay;
			} else {
				hitRenderableIndex = ray.renderableIndex;
			}
		}
		
		// We have hit a solid surface
		float ior = 1;
		float roughness = float(ray.roughness) / 255;
		float metallic = float(ray.surfaceFlags & RAY_SURFACE_METALLIC);
		vec3 hitWorldPosition = rayOrigin + rayDirection * ray.hitDistance;
		vec3 hitLocalPosition = ray.localPosition;
		vec3 rayNormal = ray.normal;
		vec3 reflectionDir = normalize(reflect(rayDirection, rayNormal));
		vec3 rayColor = ray.color;
		uint8_t raySurfaceFlags = ray.surfaceFlags;
		float rayHitDistance = ray.hitDistance;
		
		vec3 color = rayColor * float(raySurfaceFlags & RAY_SURFACE_EMISSIVE);
		float fresnel = Fresnel(rayDirection, rayNormal, ior);
		
		// Direct Lighting (shadows with diffuse and specular lighting)
		if (raySurfaceFlags == 0/*RAY_SURFACE_DIFFUSE*/ || (roughness > 0 && metallic == 1)) {
			color += GetDirectLighting(hitWorldPosition, rayDirection, rayNormal, rayColor, metallic, roughness, mix(fresnel*fresnel, 1.0, metallic), mix(64, 8, metallic));
			color += TraceAmbientLighting(hitWorldPosition, rayNormal, rayColor);
		}
		
		// Fog
		TraceFogRay(rayOrigin, rayDirection, rayHitDistance, colorFilter);
		
		// Write color
		color *= colorFilter;
		imageStore(img_composite, COORDS, vec4(color, 0) + imageLoad(img_composite, COORDS));
		
		if ((raySurfaceFlags & RAY_SURFACE_TRANSPARENT) != 0) {
			// Refractions
		} else if (metallic != 0 && roughness == 0) {
			// Metallic reflections
			rayDirection = reflectionDir;
		} else {
			return false;
		}
		colorFilter *= rayColor * 0.5/*bounce attenuation*/;
		rayOrigin = hitWorldPosition + rayDirection * EPSILON;
		return true;
	}
}

bool TraceSolidRay(inout vec3 rayOrigin, inout vec3 rayDirection, inout vec3 colorFilter) {
	uint rayMask = RAYTRACE_MASK_SOLID | RAYTRACE_MASK_VOLUME;
	if ((ray.rayFlags & RAY_FLAG_FLUID) == 0) {
		rayMask |= RAYTRACE_MASK_LIQUID;
	}
	ray.renderableIndex = -1;
	ray.surfaceFlags = uint8_t(0);
	++traceRayCount;
	traceRayEXT(tlas, gl_RayFlagsOpaqueEXT/*flags*/, rayMask, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, rayOrigin, 0, rayDirection, xenonRendererData.config.zFar, 0/*payloadIndex*/);
	if ((ray.rayFlags & RAY_FLAG_CULL_WATER) != 0) {
		ray.rayFlags &= ~RAY_FLAG_CULL_WATER;
		rayMask = RAYTRACE_MASK_SOLID;
		ray.renderableIndex = -1;
		ray.surfaceFlags = uint8_t(0);
		++traceRayCount;
		traceRayEXT(tlas, gl_RayFlagsOpaqueEXT/*flags*/, rayMask, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, rayOrigin, 0, rayDirection, xenonRendererData.config.zFar, 0/*payloadIndex*/);
	}
	int hitRenderableIndex = ray.renderableIndex;
	
	if (hitRenderableIndex == -1) {
		// First ray hit nothing
		TraceFogRay(rayOrigin, rayDirection, xenonRendererData.config.zFar, colorFilter);
		return false;
	} else {
		// Fix Z fighting with interior faces of glass
		if (ray.ior == 0) {
			ray.ior = uint8_t(51);
			RayPayload originalRay = ray;
			float epsilon = clamp(EPSILON * originalRay.hitDistance, EPSILON, 0.1);
			ray.renderableIndex = -1;
			ray.surfaceFlags = uint8_t(0);
			++traceRayCount;
			traceRayEXT(tlas, gl_RayFlagsCullBackFacingTrianglesEXT|gl_RayFlagsOpaqueEXT/*flags*/, RAYTRACE_MASK_SOLID, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, rayOrigin, originalRay.hitDistance - epsilon, rayDirection, originalRay.hitDistance + epsilon, 0/*payloadIndex*/);
			if (ray.renderableIndex == -1) {
				ray = originalRay;
			} else {
				hitRenderableIndex = ray.renderableIndex;
			}
		}
		
		// We have hit a solid surface
		float ior = float(ray.ior) / 51;
		float roughness = float(ray.roughness) / 255;
		float metallic = float(ray.surfaceFlags & RAY_SURFACE_METALLIC);
		vec3 hitWorldPosition = rayOrigin + rayDirection * ray.hitDistance;
		vec3 hitLocalPosition = ray.localPosition;
		vec3 rayNormal = ray.normal;
		vec3 reflectionDir = normalize(reflect(rayDirection, rayNormal));
		vec3 refractionDir = refract(rayDirection, rayNormal, currentIOR/ior);
		vec3 rayColor = ray.color;
		uint8_t raySurfaceFlags = ray.surfaceFlags;
		float rayHitDistance = ray.hitDistance;
		bool isTransparent = (raySurfaceFlags & RAY_SURFACE_TRANSPARENT) != 0;
		bool isLiquid = (ray.rayFlags & RAY_FLAG_FLUID) != 0;
		
		// Write Motion Vectors
		bool depthWritten = false;
		if (imageLoad(img_motion, COORDS).w == 0) {
			if (!isTransparent || dot(refractionDir, rayDirection) < 0.5) {
				if (!isLiquid) {
					mat4 mvp = xenonRendererData.config.projectionMatrix * renderer.viewMatrix * mat4(transpose(renderer.tlasInstances[hitRenderableIndex].transform));
					renderer.mvpBuffer[hitRenderableIndex].mvp = mvp;
					renderer.realtimeBuffer[hitRenderableIndex].mvpFrameIndex = xenonRendererData.frameIndex;
					vec4 ndc = mvp * vec4(hitLocalPosition, 1);
					ndc /= ndc.w;
					mat4 mvpHistory;
					if (renderer.realtimeBufferHistory[hitRenderableIndex].mvpFrameIndex == xenonRendererData.frameIndex - 1) {
						mvpHistory = renderer.mvpBufferHistory[hitRenderableIndex].mvp;
					} else {
						mvpHistory = renderer.reprojectionMatrix * mvp;
					}
					vec4 ndc_history = mvpHistory * vec4(hitLocalPosition, 1);
					ndc_history /= ndc_history.w;
					vec3 motion = ndc_history.xyz - ndc.xyz;
					imageStore(img_motion, COORDS, vec4(motion, rayHitDistance));
					vec4 clipSpace = mat4(xenonRendererData.config.projectionMatrix) * mat4(renderer.viewMatrix) * vec4(hitWorldPosition, 1);
					float depth = clamp(clipSpace.z / clipSpace.w, 0, 1);
					imageStore(img_depth, COORDS, vec4(depth));
					depthWritten = true;
				}
				imageStore(img_diffuse_albedo, COORDS, vec4(ray.color, 0));
			}
		}
		
		vec3 color = rayColor * float(raySurfaceFlags & RAY_SURFACE_EMISSIVE);
		float fresnel = Fresnel(rayDirection, rayNormal, ior);
		
		// Direct Lighting (shadows with diffuse and specular lighting)
		if (raySurfaceFlags == 0/*RAY_SURFACE_DIFFUSE*/ || (roughness > 0 && metallic == 1)) {
			color += GetDirectLighting(hitWorldPosition, rayDirection, rayNormal, rayColor, metallic, roughness, mix(fresnel*fresnel, 1.0, metallic), mix(64, 8, metallic));
			color += TraceAmbientLighting(hitWorldPosition, rayNormal, rayColor);
		} else if (raySurfaceFlags == RAY_SURFACE_TRANSPARENT && ior > 1) {
			color += GetDirectLighting(hitWorldPosition, rayDirection, rayNormal, vec3(0), 0, 1, fresnel*fresnel, 64);
		}
		
		// Fog
		TraceFogRay(rayOrigin, rayDirection, rayHitDistance, colorFilter);
		float transparency = max(colorFilter.x, max(colorFilter.y, colorFilter.z));
		alpha += (isTransparent && !isLiquid)? (1.01 - transparency) : 1;
		ssao *= clamp(transparency, 0, 1);
		
		// Glossy reflections
		if (roughness == 0 && ior > 1) {
			bool shouldAim = (ray.rayFlags & RAY_FLAG_AIM) != 0;
			ray.rayFlags &= ~RAY_FLAG_AIM;
			vec3 reflectionOrigin = hitWorldPosition + rayNormal * EPSILON * max(rayHitDistance, 1);
			vec3 reflectionDirection = reflectionDir;
			vec3 reflectionColorFilter = fresnel * colorFilter;
			bool reflections = (renderer.options & (isLiquid? RENDERER_OPTION_WATER_REFLECTIONS : RENDERER_OPTION_GLASS_REFLECTIONS)) != 0;
			if (++glossyRayCount < 3 && (reflections || !isTransparent)) {
				for (int i = 0; i < 3; i++) {
					if (!TraceGlossyRay(reflectionOrigin, reflectionDirection, reflectionColorFilter)) break;
				}
			} else if (isLiquid) {
				TraceFogRay(reflectionOrigin, reflectionDirection, xenonRendererData.config.zFar, reflectionColorFilter);
			}
			ray.rayFlags &= ~RAY_FLAG_FLUID;
			if (shouldAim) ray.rayFlags |= RAY_FLAG_AIM;
		}
		
		// Write color
		color *= colorFilter;
		imageStore(img_composite, COORDS, vec4(color, alpha) + imageLoad(img_composite, COORDS));
		
		// SSAO
		if (depthWritten) {
			imageStore(img_normal_or_debug, COORDS, vec4(rayNormal, ssao));
		}
		
		if (isTransparent) {
			// Refraction
			bool refraction = (renderer.options & (isLiquid? RENDERER_OPTION_WATER_REFRACTION : RENDERER_OPTION_GLASS_REFRACTION)) != 0;
			if (refraction || (isLiquid && ior < 1)) {
				rayDirection = refractionDir;
				if (dot(rayDirection, rayDirection) == 0) {
					rayDirection = reflectionDir;
					rayOrigin = hitWorldPosition + rayNormal * EPSILON * max(rayHitDistance * 0.01, 1);
					alpha = 1;
				} else {
					currentIOR = ior;
					rayOrigin = hitWorldPosition - rayNormal * EPSILON * max(rayHitDistance * 0.01, 1);
				}
			} else {
				rayOrigin = hitWorldPosition - rayNormal * EPSILON * max(rayHitDistance * 0.01, 1);
			}
		} else if (metallic != 0 && roughness == 0) {
			// Metallic reflections
			rayDirection = reflectionDir;
			rayOrigin = hitWorldPosition + rayNormal * EPSILON * max(rayHitDistance, 1);
			alpha = 1;
		} else {
			return false;
		}
		colorFilter *= rayColor * 0.9/*bounce attenuation*/;
		rayOrigin += rayDirection * EPSILON;
		return true;
	}
}

void main() {
	// Initialize first ray
	const ivec2 pixelInMiddleOfScreen = ivec2(gl_LaunchSizeEXT.xy) / 2;
	const bool isMiddleOfScreen = (COORDS == pixelInMiddleOfScreen);
	const mat4 projMatrix = isMiddleOfScreen? mat4(xenonRendererData.config.projectionMatrix) : mat4(xenonRendererData.config.projectionMatrixWithTAA);
	const vec2 pixelCenter = vec2(gl_LaunchIDEXT.xy) + vec2(0.5);
	const vec2 screenSize = vec2(gl_LaunchSizeEXT.xy);
	const vec2 uv = pixelCenter/screenSize;
	const vec3 initialRayPosition = inverse(renderer.viewMatrix)[3].xyz;
	const vec3 viewDir = normalize(vec4(inverse(projMatrix) * vec4(uv*2-1, 1, 1)).xyz);
	const vec3 initialRayDirection = normalize(VIEW2WORLDNORMAL * viewDir);
	vec3 rayDirection = initialRayDirection;
	vec3 rayOrigin = initialRayPosition;
	vec3 colorFilter = vec3(1);
	
	ray.renderableIndex = -1;
	ray.rayFlags = uint8_t(0);
	
	if (isMiddleOfScreen) {
		ray.rayFlags |= RAY_FLAG_AIM;
		renderer.aim.aimID = 0;
		renderer.aim.monitorIndex = 0;
		renderer.aim.hitDistance = 1e100;
	}
	
	// Clear images
	imageStore(img_composite, COORDS, vec4(0));
	imageStore(img_depth, COORDS, vec4(0));
	imageStore(img_normal_or_debug, COORDS, vec4(0));
	imageStore(img_diffuse_albedo, COORDS, vec4(0));
	imageStore(img_specular_albedo, COORDS, vec4(0));
	imageStore(img_dlss_mask, COORDS, vec4(0)); // this seems to not really matter at all
	
	// Clear motion vectors/depth
	vec4 ndc = vec4(uv * 2 - 1, 0, 1);
	vec4 ndc_history = renderer.reprojectionMatrix * ndc;
	ndc_history /= ndc_history.w;
	vec3 motion = ndc_history.xyz - ndc.xyz;
	imageStore(img_depth, COORDS, vec4(0));
	imageStore(img_motion, COORDS, vec4(motion, 0));
	
	// Trace Rays
	if (xenonRendererData.config.debugViewMode > RENDERER_DEBUG_VIEWMODE_TEST) {
		ray.renderableIndex = -1;
		ray.surfaceFlags = uint8_t(0);
		ray.normal = vec3(0);
		traceRayEXT(tlas, gl_RayFlagsOpaqueEXT/*flags*/, RAYTRACE_MASK_SOLID|RAYTRACE_MASK_LIQUID, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, rayOrigin, xenonRendererData.config.zNear, rayDirection, xenonRendererData.config.zFar, 0/*payloadIndex*/);
		imageStore(img_normal_or_debug, COORDS, vec4(ray.normal, 1));
	} else {
		for (int i = 0; i < max(1, renderer.rays_max_bounces); i++) {
			if (!TraceSolidRay(rayOrigin, rayDirection, colorFilter)) break;
		}
		if (renderer.globalLightingFactor < 1) {
			vec4 composite = imageLoad(img_composite, COORDS);
			imageStore(img_composite, COORDS, vec4(composite.rgb * renderer.globalLightingFactor*renderer.globalLightingFactor, mix(1, composite.a, renderer.globalLightingFactor)));
		}
	}
	
	// Trace environment audio
	const int MAX_AUDIO_BOUNCE = 1;
	const uvec2 environment_audio_trace_size = uvec2(200, 200);
	vec4 testcolor = vec4(0);
	if (gl_LaunchIDEXT.x < environment_audio_trace_size.x && gl_LaunchIDEXT.y < environment_audio_trace_size.y && xenonRendererData.config.debugViewMode <= RENDERER_DEBUG_VIEWMODE_TEST) {
		testcolor.a = 1;
		vec3 rayDir = inverse(mat3(renderer.viewMatrix)) * MapUVToSphere(vec2(gl_LaunchIDEXT) / vec2(environment_audio_trace_size));
		rayOrigin = initialRayPosition;
		int envAudioBounce = 0;
		float audible = 1.0;
		bool insideVolume = false;
		
		do {
			// Volume
			if (!insideVolume) {
				rayQueryEXT rq;
				rayQueryInitializeEXT(rq, tlas, gl_RayFlagsTerminateOnFirstHitEXT, RAYTRACE_MASK_VOLUME, rayOrigin, 0, rayDir, 0);
				if (rayQueryProceedEXT(rq)) {
					insideVolume = true;
				}
			}
			
			ray.hitDistance = -1;
			ray.renderableIndex = -1;
			ray.hitDistance = ENVIRONMENT_AUDIO_MAX_DISTANCE;
			traceRayEXT(tlas, gl_RayFlagsCullBackFacingTrianglesEXT|gl_RayFlagsOpaqueEXT/*flags*/, insideVolume? RAYTRACE_MASK_ENTITY : (RAYTRACE_MASK_TERRAIN | RAYTRACE_MASK_ENTITY | RAYTRACE_MASK_LIQUID) /*rayMask*/, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, rayOrigin, 0.0, rayDir, ENVIRONMENT_AUDIO_MAX_DISTANCE, 0/*payloadIndex*/);
			
			// Plasma
			if (!insideVolume) {
				rayQueryEXT rq;
				rayQueryInitializeEXT(rq, tlas, gl_RayFlagsNoOpaqueEXT, RAYTRACE_MASK_FOG, rayOrigin, 0, rayDir, ray.hitDistance);
				while (rayQueryProceedEXT(rq)) {
					int renderableIndex = rayQueryGetIntersectionInstanceIdEXT(rq, false);
					renderer.environmentAudio.audibleRenderables[renderableIndex].audible = max(renderer.environmentAudio.audibleRenderables[renderableIndex].audible, audible);
				}
			}
			
			if (ray.renderableIndex == -1) {
				testcolor.rgb = vec3(0);
				atomicAdd(renderer.environmentAudio.miss, 1);
				break;
			} else {
				uint hitMask = renderer.tlasInstances[ray.renderableIndex].instanceCustomIndex_and_mask >> 24;
				if (hitMask == RAYTRACE_MASK_TERRAIN) {
					atomicAdd(renderer.environmentAudio.terrain, 1);
					testcolor.rgb = mix(testcolor.rgb, vec3(1,0,0), audible);
					break;
				}
				else if (hitMask == RAYTRACE_MASK_ENTITY) {
					renderer.environmentAudio.audibleRenderables[ray.renderableIndex].audible = max(renderer.environmentAudio.audibleRenderables[ray.renderableIndex].audible, audible);
					atomicAdd(renderer.environmentAudio.object, 1);
					testcolor.rgb = mix(testcolor.rgb, vec3(0,1,0), audible);
					if (envAudioBounce++ == MAX_AUDIO_BOUNCE) {
						break;
					}
					rayOrigin += rayDir * ray.hitDistance + ray.normal * EPSILON;
					rayDir = reflect(rayDir, ray.normal);
					audible *= 0.5;
				}
				else if (hitMask == RAYTRACE_MASK_LIQUID && !insideVolume) {
					atomicAdd(renderer.environmentAudio.hydrosphere, 1);
					renderer.environmentAudio.hydrosphereDistance = atomicMin(renderer.environmentAudio.hydrosphereDistance, int(ray.hitDistance * 100));
					testcolor.rgb = mix(testcolor.rgb, vec3(0,0,1), audible);
					break;
				} else {
					break;
				}
			}
		} while (true);
	}
	
	// Debug Views
	switch (xenonRendererData.config.debugViewMode) {
		default:
		case RENDERER_DEBUG_VIEWMODE_NONE:
		case RENDERER_DEBUG_VIEWMODE_SSAO:
		case RENDERER_DEBUG_VIEWMODE_NORMALS_WORLDSPACE:
			// Handled from inside the ray loop
			break;
		case RENDERER_DEBUG_VIEWMODE_RAYGEN_TIME:
			imageStore(img_normal_or_debug, COORDS, vec4(HeatmapClamped(float(float(clockARB() - startTime) / (10000000 * xenonRendererData.config.debugViewScale))), 1));
			break;
		case RENDERER_DEBUG_VIEWMODE_TRACE_RAY_COUNT:
			imageStore(img_normal_or_debug, COORDS, vec4(traceRayCount > 0? HeatmapClamped(xenonRendererData.config.debugViewScale * traceRayCount / 8) : vec3(0), 1));
			break;
		case RENDERER_DEBUG_VIEWMODE_DIRECT_LIGHTS:
			imageStore(img_normal_or_debug, COORDS, vec4(HeatmapClamped(float(nbDirectLights) / float(NB_LIGHTS)), 1));
			break;
		case RENDERER_DEBUG_VIEWMODE_ENVIRONMENT_AUDIO:
			imageStore(img_normal_or_debug, COORDS, testcolor);
			break;
		case RENDERER_DEBUG_VIEWMODE_ALPHA:
			imageStore(img_normal_or_debug, COORDS, vec4(HeatmapClamped(pow(imageLoad(img_resolved, COORDS).a, xenonRendererData.config.debugViewScale)), 1));
			break;
		case RENDERER_DEBUG_VIEWMODE_TEST:
			// /* Depth */ imageStore(img_normal_or_debug, COORDS, vec4(HeatmapClamped(pow(imageLoad(img_depth, COORDS).r, xenonRendererData.config.debugViewScale)), 1));
			// /* Motion */ imageStore(img_normal_or_debug, COORDS, vec4(abs(imageLoad(img_motion, COORDS).rgb) * xenonRendererData.config.debugViewScale, 1));
			// /* Normal */ imageStore(img_normal_or_debug, COORDS, vec4(imageLoad(img_normal_or_debug, COORDS).rgb, 1));
			// /* Roughness */ imageStore(img_normal_or_debug, COORDS, vec4(vec3(imageLoad(img_normal_or_debug, COORDS).a), 1));
			/* Diffuse Albedo */ imageStore(img_normal_or_debug, COORDS, vec4(pow(imageLoad(img_diffuse_albedo, COORDS).rgb, vec3(xenonRendererData.config.debugViewScale)), 1));
			// /* Sspecular Albedo */ imageStore(img_normal_or_debug, COORDS, vec4(pow(imageLoad(img_specular_albedo, COORDS).rgb, vec3(xenonRendererData.config.debugViewScale)), 1));
			break;
		case RENDERER_DEBUG_VIEWMODE_DISTANCE:
			if (ray.renderableIndex == -1) break;
			imageStore(img_normal_or_debug, COORDS, vec4(HeatmapClamped(pow(ray.hitDistance / 1000 * xenonRendererData.config.debugViewScale, 0.4)), 1));
			break;
		case RENDERER_DEBUG_VIEWMODE_NORMALS_VIEWSPACE:
			if (ray.renderableIndex == -1) break;
			imageStore(img_normal_or_debug, COORDS, vec4(max(vec3(0), normalize(WORLD2VIEWNORMAL * ray.normal)), 1));
			break;
		case RENDERER_DEBUG_VIEWMODE_NORMALS_WORLDSPACE_INVERTED:
			if (ray.renderableIndex == -1) break;
			imageStore(img_normal_or_debug, COORDS, vec4(max(vec3(0), -ray.normal), 1));
			break;
	}
}
