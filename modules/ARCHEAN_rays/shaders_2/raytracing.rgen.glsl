#define SHADER_RGEN
#include "../common.inc.glsl"

layout(location = 0) rayPayloadEXT RayPayload ray;
layout(location = 1) rayPayloadEXT RayShadowPayload shadowRay;

#define NB_LIGHTS 16
#define SORT_LIGHTS
#define EPSILON 0.0001
#define LIGHT_LUMINOSITY_VISIBLE_THRESHOLD 0.01

uint64_t startTime = clockARB();
uint stableSeed = InitRandomSeed(gl_LaunchIDEXT.x, gl_LaunchIDEXT.y);
uint coherentSeed = InitRandomSeed(uint(xenonRendererData.frameIndex),0);
uint temporalSeed = uint(int64_t(renderer.timestamp * 1000) % 1000000);
uint seed = InitRandomSeed(stableSeed, coherentSeed);
uint traceRayCount = 0;
uint nbDirectLights = 0;

vec3 GetDirectLighting(in vec3 worldPosition, in vec3 rayDirection, in vec3 normal, in vec3 albedo, in float referenceDistance, in float metallic, in float roughness, in float specular, in float specularHardness) {
	vec3 position = worldPosition + normal * referenceDistance * 0.001;
	vec3 directLighting = vec3(0);
	
	rayQueryEXT q;
	rayQueryInitializeEXT(q, tlas_lights, 0, 0xff, position, 0, vec3(0,1,0), 0);
	
	vec3 lightsDir[NB_LIGHTS];
	float lightsDistance[NB_LIGHTS];
	vec3 lightsColor[NB_LIGHTS];
	float lightsPower[NB_LIGHTS];
	float lightsRadius[NB_LIGHTS];
	// uint32_t lightsID[NB_LIGHTS];
	uint32_t nbLights = 0;
	
	while (rayQueryProceedEXT(q)) {
		mat4 lightTransform = mat4(rayQueryGetIntersectionObjectToWorldEXT(q, false));
		vec3 lightPosition = lightTransform[3].xyz;
		int lightID = rayQueryGetIntersectionInstanceIdEXT(q, false);
		vec3 relativeLightPosition = lightPosition - position;
		vec3 lightDir = normalize(relativeLightPosition);
		float nDotL = dot(normal, lightDir);
		LightSourceInstanceData lightSource = renderer.lightSources[lightID].instance;
		float distanceToLightSurface = length(relativeLightPosition) - abs(lightSource.innerRadius) - referenceDistance * EPSILON;
		if (distanceToLightSurface <= 0.001) {
			if (lightSource.innerRadius > 0) {
				directLighting += lightSource.color * lightSource.power;
			}
		} else if (nDotL > 0 && distanceToLightSurface < lightSource.maxDistance) {
			float penombra = 1;
			float surfaceArea = 4 * PI;
			if (lightSource.angle > 0) {
				surfaceArea = 2 * lightSource.angle;
				vec3 spotlightDirection = (lightTransform * vec4(lightSource.direction, 0)).xyz;
				float spotlightHalfAngle = lightSource.angle * 0.5;
				penombra = smoothstep(spotlightHalfAngle, spotlightHalfAngle * 0.8, acos(abs(dot(-lightDir, spotlightDirection))));
				if (penombra == 0) continue;
			}
			float effectiveLightIntensity = max(0, lightSource.power / (surfaceArea * distanceToLightSurface*distanceToLightSurface + 1) - LIGHT_LUMINOSITY_VISIBLE_THRESHOLD) * penombra;
			uint index = nbLights;
			#ifdef SORT_LIGHTS
				for (index = 0; index < nbLights; ++index) {
					if (effectiveLightIntensity > lightsPower[index]) {
						for (int i = min(NB_LIGHTS-1, int(nbLights)); i > int(index); --i) {
							lightsDir[i] = lightsDir[i-1];
							lightsDistance[i] = lightsDistance[i-1];
							lightsColor[i] = lightsColor[i-1];
							lightsPower[i] = lightsPower[i-1];
							lightsRadius[i] = lightsRadius[i-1];
							// lightsID[i] = lightsID[i-1];
						}
						break;
					}
				}
				if (index == NB_LIGHTS) continue;
			#endif
			lightsDir[index] = lightDir;
			lightsDistance[index] = distanceToLightSurface;
			lightsColor[index] = lightSource.color;
			lightsPower[index] = effectiveLightIntensity;
			lightsRadius[index] = abs(lightSource.innerRadius);
			// lightsID[index] = lightID;
			if (nbLights < NB_LIGHTS) ++nbLights;
			#ifndef /*NOT*/SORT_LIGHTS
				else {
					rayQueryTerminateEXT(q);
					break;
				}
			#endif
		}
	}
	
	nbDirectLights += nbLights;
	
	for (uint i = 0; i < nbLights; ++i) {
		vec3 shadowRayDir = lightsDir[i];
		bool isSunLight = lightsDistance[i] > 1e5; // 100 km
		
		// // Soft Shadows
		// vec2 rnd = vec2(RandomFloat(seed), RandomFloat(seed));
		// float pointRadius = lightsRadius[i] / lightsDistance[i] * rnd.x;
		// float pointAngle = rnd.y * 2.0 * PI;
		// vec2 diskPoint = vec2(pointRadius * cos(pointAngle), pointRadius * sin(pointAngle));
		// vec3 lightTangent = normalize(cross(shadowRayDir, normal));
		// vec3 lightBitangent = normalize(cross(lightTangent, shadowRayDir));
		// shadowRayDir = normalize(shadowRayDir + diskPoint.x * lightTangent + diskPoint.y * lightBitangent);
		
		if (dot(shadowRayDir, normal) > 0) {
			shadowRay.colorAttenuation = vec3(1);
			++traceRayCount;
			traceRayEXT(tlas, gl_RayFlagsNoOpaqueEXT | gl_RayFlagsSkipClosestHitShaderEXT, RAYTRACE_MASK_SOLID, 0/*rayType*/, 0/*nbRayTypes*/, 1/*missIndex*/, position, 0, shadowRayDir, lightsDistance[i] - EPSILON, 1);
			vec3 light = lightsColor[i] * lightsPower[i];
			float NdotL = clamp(dot(normal, shadowRayDir), 0, 1);
			vec3 diffuse = albedo * NdotL * (1 - metallic) * mix(0.5, 1, roughness);
			vec3 H = normalize(shadowRayDir - rayDirection);
			float NdotH = clamp(dot(normal, H), 0, 1);
			vec3 spec = pow(NdotH, specularHardness) * mix(vec3(1), albedo, metallic); // Fresnel is applied to specular from the caller
			directLighting += shadowRay.colorAttenuation * light * (diffuse + spec * specular);
		}
	}
	
	return directLighting;
}

void TraceFogRay(in vec3 rayOrigin, in vec3 rayDirection, in float maxDistance, inout vec3 colorFilter) {
	shadowRay.colorAttenuation = vec3(1);
	shadowRay.emission = vec3(0);
	shadowRay.hitDistance = maxDistance;
	++traceRayCount;
	traceRayEXT(tlas, gl_RayFlagsNoOpaqueEXT | gl_RayFlagsSkipClosestHitShaderEXT/*flags*/, RAYTRACE_MASK_FOG, 0/*rayType*/, 0/*nbRayTypes*/, 1/*missIndex*/, rayOrigin, 0, rayDirection, maxDistance, 1/*payloadIndex*/);
	if (dot(shadowRay.emission, shadowRay.emission) > 0) {
		imageStore(img_composite, COORDS, vec4(shadowRay.emission * colorFilter, 0) + imageLoad(img_composite, COORDS));
	}
	colorFilter *= shadowRay.colorAttenuation;
}

bool TraceGlossyRay(inout vec3 rayOrigin, inout vec3 rayDirection, inout vec3 colorFilter) {
	ray.renderableIndex = -1;
	++traceRayCount;
	traceRayEXT(tlas, gl_RayFlagsOpaqueEXT/*flags*/, RAYTRACE_MASK_SOLID, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, rayOrigin, 0, rayDirection, xenonRendererData.config.zFar, 0/*payloadIndex*/);
	if (ray.renderableIndex == -1) {
		TraceFogRay(rayOrigin, rayDirection, xenonRendererData.config.zFar, colorFilter);
		return false;
	}

	// We have hit a solid surface
	float ior = float(ray.ior) / 51;
	float roughness = float(ray.roughness) / 255;
	vec3 hitWorldPosition = rayOrigin + rayDirection * ray.hitDistance;
	vec3 hitLocalPosition = ray.localPosition;
	vec3 reflectionDir = normalize(reflect(rayDirection, ray.normal));
	vec3 rayColor = ray.color;
	vec3 rayNormal = ray.normal;
	float rayHitDistance = ray.hitDistance;
	
	vec3 color = rayColor * float(ray.surfaceFlags & RAY_SURFACE_EMISSIVE);
	float fresnel = Fresnel(rayDirection, rayNormal, ior);
	
	// Direct Lighting (shadows with diffuse and specular lighting)
	if (ray.surfaceFlags == RAY_SURFACE_DIFFUSE) {
		color += GetDirectLighting(hitWorldPosition, rayDirection, rayNormal, rayColor, rayHitDistance, float(ray.surfaceFlags & RAY_SURFACE_METALLIC), roughness, fresnel * (1-roughness), 8);
	}
	
	// Write color
	TraceFogRay(rayOrigin, rayDirection, rayHitDistance, colorFilter);
	color *= colorFilter;
	imageStore(img_composite, COORDS, vec4(color, 1) + imageLoad(img_composite, COORDS));
	
	if (float(ray.surfaceFlags & RAY_SURFACE_TRANSPARENT) != 0) {
		// Refractions
		rayDirection = refract(rayDirection, rayNormal, 1.0/ior);
		if (dot(rayDirection, rayDirection) == 0) {
			rayDirection = reflectionDir;
		}
	} else if ((ray.surfaceFlags & RAY_SURFACE_METALLIC) != 0) {
		// Metallic reflections
		rayDirection = reflectionDir;
	} else {
		return false;
	}
	colorFilter *= rayColor * 0.8/*bounce attenuation*/;
	rayOrigin = hitWorldPosition + rayDirection * EPSILON;
	return true;
}

bool TraceSolidRay(inout vec3 rayOrigin, inout vec3 rayDirection, inout vec3 colorFilter) {
	ray.renderableIndex = -1;
	++traceRayCount;
	traceRayEXT(tlas, gl_RayFlagsOpaqueEXT/*flags*/, RAYTRACE_MASK_SOLID, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, rayOrigin, xenonRendererData.config.zNear, rayDirection, xenonRendererData.config.zFar, 0/*payloadIndex*/);
	int hitRenderableIndex = ray.renderableIndex;
	
	if (hitRenderableIndex == -1) {
		// First ray hit nothing
		if (imageLoad(img_motion, COORDS).w == 0) {
			imageStore(img_depth, COORDS, vec4(0));
			imageStore(img_motion, COORDS, vec4(0));
		}
		TraceFogRay(rayOrigin, rayDirection, xenonRendererData.config.zFar, colorFilter);
	} else {
		// We have hit a solid surface
		float ior = float(ray.ior) / 51;
		float roughness = float(ray.roughness) / 255;
		vec3 hitWorldPosition = rayOrigin + rayDirection * ray.hitDistance;
		vec3 hitLocalPosition = ray.localPosition;
		vec3 reflectionDir = normalize(reflect(rayDirection, ray.normal));
		vec3 rayColor = ray.color;
		vec3 rayNormal = ray.normal;
		float ssao = 1;
		uint8_t raySurfaceFlags = ray.surfaceFlags;
		float rayHitDistance = ray.hitDistance;
		
		// Write Motion Vectors
		if (imageLoad(img_motion, COORDS).w == 0) {
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
			imageStore(img_normal_or_debug, COORDS, vec4(rayNormal, ssao));
		}
		
		vec3 color = rayColor * float(raySurfaceFlags & RAY_SURFACE_EMISSIVE);
		float fresnel = Fresnel(rayDirection, rayNormal, ior);
		
		// Direct Lighting (shadows with diffuse and specular lighting)
		if (raySurfaceFlags == RAY_SURFACE_DIFFUSE/* || ray.surfaceFlags == RAY_SURFACE_TRANSPARENT*/) {
			color += GetDirectLighting(hitWorldPosition, rayDirection, rayNormal, rayColor, rayHitDistance, float(raySurfaceFlags & RAY_SURFACE_METALLIC), roughness, fresnel * (1-roughness), 8);
		}
		
		// Glossy reflections
		if (ray.roughness == 0) {
			vec3 reflectionOrigin = hitWorldPosition + rayNormal * EPSILON;
			vec3 reflectionDirection = reflectionDir;
			vec3 reflectionColorFilter = fresnel * colorFilter;
			for (int i = 0; i < 5; i++) {
				if (!TraceGlossyRay(reflectionOrigin, reflectionDirection, reflectionColorFilter)) break;
			}
		}
		
		// Fog
		TraceFogRay(rayOrigin, rayDirection, rayHitDistance, colorFilter);
		
		// Write color
		color *= colorFilter;
		imageStore(img_composite, COORDS, vec4(color, 1) + imageLoad(img_composite, COORDS));
		
		if (float(raySurfaceFlags & RAY_SURFACE_TRANSPARENT) != 0) {
			// Refractions
			rayDirection = refract(rayDirection, rayNormal, 1.0/ior);
			if (dot(rayDirection, rayDirection) == 0) {
				rayDirection = reflectionDir;
			}
		} else if ((raySurfaceFlags & RAY_SURFACE_METALLIC) != 0) {
			// Metallic reflections
			rayDirection = reflectionDir;
		} else {
			return false;
		}
		colorFilter *= rayColor * 0.8/*bounce attenuation*/;
		rayOrigin = hitWorldPosition + rayDirection * EPSILON;
	}
	
	return hitRenderableIndex != -1;
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
	vec3 colorFilter = vec3(renderer.globalLightingFactor * renderer.globalLightingFactor);
	
	ray.renderableIndex = -1;
	ray.rayFlags = uint8_t(0);
	
	if (isMiddleOfScreen) {
		ray.rayFlags |= RAY_FLAG_AIM;
		renderer.aim.aimID = 0;
		renderer.aim.monitorIndex = 0;
		renderer.aim.hitDistance = 1e100;
	}
	
	imageStore(img_composite, COORDS, vec4(0));
	if (xenonRendererData.config.debugViewMode != 0) {
		imageStore(img_normal_or_debug, COORDS, vec4(0));
	}
	
	if (xenonRendererData.config.debugViewMode > RENDERER_DEBUG_VIEWMODE_TEST) {
		ray.renderableIndex = -1;
		ray.normal = vec3(0);
		traceRayEXT(tlas, gl_RayFlagsOpaqueEXT/*flags*/, RAYTRACE_MASK_SOLID, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, rayOrigin, xenonRendererData.config.zNear, rayDirection, xenonRendererData.config.zFar, 0/*payloadIndex*/);
		imageStore(img_normal_or_debug, COORDS, vec4(ray.normal, 1));
	} else {
		// Trace Rays
		for (int i = 0; i < 20; i++) {
			if (!TraceSolidRay(rayOrigin, rayDirection, colorFilter)) break;
		}
	}
	
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
			break;
		case RENDERER_DEBUG_VIEWMODE_ALPHA:
			imageStore(img_normal_or_debug, COORDS, vec4(HeatmapClamped(pow(imageLoad(img_resolved, COORDS).a, xenonRendererData.config.debugViewScale)), 1));
			break;
		case RENDERER_DEBUG_VIEWMODE_TEST:
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
