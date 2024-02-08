#define SHADER_RGEN
#include "common.inc.glsl"

layout(location = 0) rayPayloadEXT RayPayload ray;
layout(location = 1) rayPayloadEXT RayPayload glassReflectionRay;

#include "lighting.inc.glsl"
// GetDirectLighting(ray.worldPosition, gl_WorldRayDirectionEXT, ray.normal, albedo, gl_HitTEXT, surface.metallic, surface.roughness, surface.specular)

vec3 mapToSphere(vec2 uv) {
	// uv += vec2(RandomFloat(coherentSeed), RandomFloat(coherentSeed)) / 100;
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

void main() {
	const ivec2 pixelInMiddleOfScreen = ivec2(gl_LaunchSizeEXT.xy) / 2;
	const bool isMiddleOfScreen = (COORDS == pixelInMiddleOfScreen);
	const vec2 pixelCenter = vec2(gl_LaunchIDEXT.xy) + vec2(0.5);
	const vec2 screenSize = vec2(gl_LaunchSizeEXT.xy);
	const vec2 uv = pixelCenter/screenSize;
	const vec3 initialRayPosition = inverse(renderer.viewMatrix)[3].xyz;
	const mat4 projMatrix = isMiddleOfScreen? mat4(xenonRendererData.config.projectionMatrix) : mat4(xenonRendererData.config.projectionMatrixWithTAA);
	vec3 viewDir = normalize(vec4(inverse(projMatrix) * vec4(uv*2-1, 1, 1)).xyz);
	
	if (isMiddleOfScreen) {
		renderer.aim.monitorIndex = 0;
	}
	
	// Warp drive
	if (renderer.warp > 0) {
		const float centerFactor = length((pixelCenter/screenSize-0.5) * vec2(screenSize.x / screenSize.y, 1));
		viewDir.xy = mix(viewDir.xy, viewDir.xy * pow(clamp(centerFactor, 0.08, 1), 2) , renderer.warp);
	}
	
	vec3 initialRayDirection = normalize(VIEW2WORLDNORMAL * viewDir);
	
	imageStore(rtPayloadImage, COORDS, u8vec4(0));
	imageStore(img_primary_albedo_roughness, COORDS, u8vec4(0));
	if (xenonRendererData.config.debugViewMode != 0) {
		imageStore(img_normal_or_debug, COORDS, vec4(0));
	}
	
	ray.hitDistance = -1;
	ray.t2 = 0;
	ray.normal = vec3(0);
	ray.color = vec4(0);
	ray.ssao = 0;
	vec3 rayOrigin = initialRayPosition;
	vec3 glassTint = vec3(1);
	vec3 glassSpecular = vec3(0);
	float ssao = 1;
	float transparency = 1.0;
	bool glassReflection = false;
	vec3 glassReflectionOrigin;
	vec3 glassReflectionDirection;
	float glassReflectionStrength;
	vec4 color = vec4(0);
	ray.plasma = vec4(0);
	uint primaryRayMask = RAYTRACE_MASK_TERRAIN|RAYTRACE_MASK_ENTITY|RAYTRACE_MASK_ATMOSPHERE|RAYTRACE_MASK_HYDROSPHERE|RAYTRACE_MASK_CLUTTER|RAYTRACE_MASK_PLASMA;
	if (xenonRendererData.config.debugViewMode == RENDERER_DEBUG_VIEWMODE_GI_LIGHTS) {
		primaryRayMask |= RAYTRACE_MASK_LIGHT;
	}
	do {
		traceRayEXT(tlas, /*gl_RayFlagsCullBackFacingTrianglesEXT|*/gl_RayFlagsOpaqueEXT/*flags*/, primaryRayMask, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, rayOrigin, renderer.cameraZNear, initialRayDirection, xenonRendererData.config.zFar, 0/*payloadIndex*/);
		// Aim
		if (transparency == 1 && isMiddleOfScreen) {
			renderer.aim.localPosition = ray.localPosition;
			renderer.aim.geometryIndex = ray.geometryIndex;
			renderer.aim.aimID = ray.aimID;
			renderer.aim.worldSpaceHitNormal = ray.normal;
			renderer.aim.primitiveIndex = ray.primitiveIndex;
			renderer.aim.worldSpacePosition = ray.worldPosition;
			renderer.aim.hitDistance = ray.hitDistance;
			renderer.aim.color = ray.color;
			renderer.aim.viewSpaceHitNormal = normalize(WORLD2VIEWNORMAL * ray.normal);
			renderer.aim.tlasInstanceIndex = ray.renderableIndex;
		}
		ray.color.rgb *= clamp(transparency, 0.0, 1.0) * glassTint;
		ray.plasma.rgb *= clamp(transparency, 0.0, 1.0) * glassTint;
		ssao *= ray.ssao;
		if (ray.hitDistance == -1) {
			break;
		}
		ssao *= ray.color.a;
		vec3 tint = ray.color.rgb;
		transparency *= min(0.95, 1.0 - clamp(ray.color.a, 0, 1));
		glassTint *= tint;
		rayOrigin += initialRayDirection * ray.hitDistance;
		// Reflections on Glass
		if ((renderer.options & RENDERER_OPTION_GLASS_REFLECTIONS) != 0 && !glassReflection && ray.color.a != 1.0 && ray.hitDistance > 0.0 && ray.hitDistance < ATMOSPHERE_RAY_MIN_DISTANCE && dot(ray.normal, initialRayDirection) < 0.0) {
			glassReflection = true;
			glassReflectionStrength = Fresnel(normalize((renderer.viewMatrix * vec4(ray.worldPosition, 1)).xyz), normalize(WORLD2VIEWNORMAL * ray.normal), 1.15);
			glassReflectionOrigin = ray.worldPosition + ray.normal * max(2.0, ray.hitDistance) * EPSILON * 10;
			glassReflectionDirection = reflect(initialRayDirection, ray.normal);
		}
		float rDotN = dot(initialRayDirection, ray.normal);
		// Specular/Shadows on Glass
		if ((renderer.options & RENDERER_OPTION_DIRECT_LIGHTING) != 0 && ray.color.a < 1.0 && rDotN < 0) {
			RayPayload originalRay = ray;
			glassSpecular += GetDirectLighting(originalRay.worldPosition, initialRayDirection, originalRay.normal, vec3(0), originalRay.hitDistance, 0, 0, 0.5);
			ray = originalRay;
		}
		// Refraction on Glass
		if ((renderer.options & RENDERER_OPTION_GLASS_REFRACTION) != 0 && ray.color.a < 1.0) {
			vec3 originalRayDirection = initialRayDirection;
			float ior = 1.5;
			// if (rDotN < 0) ior = 1.0 / ior;
			// initialRayDirection = refract(initialRayDirection, sign(rDotN) * -ray.normal, ior);
			Refract(initialRayDirection, sign(rDotN) * -ray.normal, ior);
			if (dot(initialRayDirection, initialRayDirection) == 0.0) {
				initialRayDirection = reflect(originalRayDirection, sign(rDotN) * -ray.normal);
				color.a += 1;
			} else {
				color.a += ray.color.a;
			}
		}
	} while (ray.color.a < 1.0 && transparency > 0.1 && ray.hitDistance > 0.0);
	color += ray.color + ray.plasma + vec4(glassSpecular, 0);
	
	float hitDistance = ray.hitDistance;
	if (hitDistance < 0) {
		hitDistance = xenonRendererData.config.zFar;
	}

	// Reflections on Glass / Glossy
	if (glassReflection) {
		glassReflectionRay.color = vec4(0);
		glassReflectionRay.plasma = vec4(0);
		glassReflectionRay.hitDistance = -1;
		glassReflectionRay.t2 = 0;
		traceRayEXT(tlas, gl_RayFlagsCullBackFacingTrianglesEXT|gl_RayFlagsOpaqueEXT, RAYTRACE_MASK_TERRAIN|RAYTRACE_MASK_ENTITY|RAYTRACE_MASK_CLUTTER|RAYTRACE_MASK_ATMOSPHERE|RAYTRACE_MASK_HYDROSPHERE|RAYTRACE_MASK_PLASMA, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, glassReflectionOrigin, 0, glassReflectionDirection, xenonRendererData.config.zFar, 1);
		color.rgb = mix(color.rgb, glassReflectionRay.color.rgb, glassReflectionStrength * glassReflectionRay.color.a);
		color.rgb += glassReflectionRay.plasma.rgb * glassReflectionStrength;
	}
	
	color.rgb *= pow(renderer.globalLightingFactor, 4);
	color.a = mix(1, color.a, renderer.globalLightingFactor);
	
	if (RAY_IS_UNDERWATER || color.a > 1) {
		color.a = 1;
	}
	
	bool hitSomething = ray.hitDistance >= 0 && ray.renderableIndex != -1;
	vec3 motion;
	float depth;
	
	// Motion Vectors
	if (hitSomething) {
		mat4 mvp = xenonRendererData.config.projectionMatrix * renderer.viewMatrix * mat4(transpose(renderer.tlasInstances[ray.renderableIndex].transform));
		
		// These two lines may cause problems on AMD if they didn't fix their bugs
		renderer.mvpBuffer[ray.renderableIndex].mvp = mvp;
		renderer.realtimeBuffer[ray.renderableIndex].mvpFrameIndex = xenonRendererData.frameIndex;
		
		vec4 ndc = mvp * vec4(ray.localPosition, 1);
		ndc /= ndc.w;
		mat4 mvpHistory;
		if (renderer.realtimeBufferHistory[ray.renderableIndex].mvpFrameIndex == xenonRendererData.frameIndex - 1) {
			mvpHistory = renderer.mvpBufferHistory[ray.renderableIndex].mvp;
		} else {
			mvpHistory = renderer.reprojectionMatrix * mvp;
		}
		vec4 ndc_history = mvpHistory * vec4(ray.localPosition, 1);
		ndc_history /= ndc_history.w;
		motion = ndc_history.xyz - ndc.xyz;
		vec4 clipSpace = mat4(xenonRendererData.config.projectionMatrix) * mat4(renderer.viewMatrix) * vec4(ray.worldPosition, 1);
		depth = clamp(clipSpace.z / clipSpace.w, 0, 1);
	} else {
		vec4 ndc = vec4(uv * 2 - 1, 0, 1);
		vec4 ndc_history = renderer.reprojectionMatrix * ndc;
		ndc_history /= ndc_history.w;
		motion = ndc_history.xyz - ndc.xyz;
		depth = 0;
	}
	
	// Negative depth means underwater
	if (RAY_IS_UNDERWATER) {
		hitDistance *= -1;
	}
	
	imageStore(img_composite, COORDS, max(vec4(0), color));
	imageStore(img_depth, COORDS, vec4(depth));
	imageStore(img_motion, COORDS, vec4(motion, hitDistance));
	
	// Trace environment audio
	const int MAX_AUDIO_BOUNCE = 2;
	const uvec2 environment_audio_trace_size = uvec2(200, 200);
	if (gl_LaunchIDEXT.x < environment_audio_trace_size.x && gl_LaunchIDEXT.y < environment_audio_trace_size.y) {
		RayPayload originalRay = ray;
		vec3 testcolor = vec3(0);
		vec3 rayDir = mapToSphere(vec2(gl_LaunchIDEXT) / vec2(environment_audio_trace_size));
		rayOrigin = initialRayPosition;
		int envAudioBounce = 0;
		float audible = 1.0;
		bool hitPlasma = false;
		do {
			ray.hitDistance = -1;
			uint rayMask = RAYTRACE_MASK_TERRAIN | RAYTRACE_MASK_ENTITY | RAYTRACE_MASK_HYDROSPHERE | (hitPlasma?0:RAYTRACE_MASK_PLASMA);
			RAY_SHADOW_PUSH
				traceRayEXT(tlas, gl_RayFlagsCullBackFacingTrianglesEXT|gl_RayFlagsOpaqueEXT/*flags*/, rayMask/*rayMask*/, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, rayOrigin, 0.0, rayDir, 1000, 0/*payloadIndex*/);
			RAY_SHADOW_POP
			if (ray.hitDistance == -1 || ray.renderableIndex == -1) {
				ray.hitDistance = 1000;
				testcolor = vec3(0);
				atomicAdd(renderer.environmentAudio.miss, 1);
				break;
			} else {
				uint hitMask = renderer.tlasInstances[ray.renderableIndex].instanceCustomIndex_and_mask >> 24;
				if (hitMask == RAYTRACE_MASK_TERRAIN) {
					atomicAdd(renderer.environmentAudio.terrain, 1);
					testcolor = mix(testcolor, vec3(1,0,0), audible);
					break;
				}
				else if (hitMask == RAYTRACE_MASK_ENTITY) {
					renderer.environmentAudio.audibleRenderables[ray.renderableIndex].audible = max(renderer.environmentAudio.audibleRenderables[ray.renderableIndex].audible, audible);
					atomicAdd(renderer.environmentAudio.object, 1);
					testcolor = mix(testcolor, vec3(0,1,0), audible);
					if (envAudioBounce++ == MAX_AUDIO_BOUNCE) {
						break;
					}
					rayOrigin += rayDir * ray.hitDistance + ray.normal * EPSILON;
					rayDir = reflect(rayDir, ray.normal);
					audible *= 0.5;
				}
				else if (hitMask == RAYTRACE_MASK_HYDROSPHERE) {
					atomicAdd(renderer.environmentAudio.hydrosphere, 1);
					renderer.environmentAudio.hydrosphereDistance = atomicMin(renderer.environmentAudio.hydrosphereDistance, int(ray.hitDistance * 100));
					testcolor = mix(testcolor, vec3(0,0,1), audible);
					break;
				}
				else if (hitMask == RAYTRACE_MASK_PLASMA) {
					renderer.environmentAudio.audibleRenderables[ray.renderableIndex].audible = max(renderer.environmentAudio.audibleRenderables[ray.renderableIndex].audible, audible);
					// atomicAdd(renderer.environmentAudio.object, 1);
					testcolor = mix(testcolor, vec3(1,1,0), audible);
					hitPlasma = true;
				} else {
					break;
				}
			}
		} while (true);
		if (xenonRendererData.config.debugViewMode == RENDERER_DEBUG_VIEWMODE_ENVIRONMENT_AUDIO) imageStore(img_normal_or_debug, COORDS, vec4(testcolor, 1));
		ray = originalRay;
	}
	
	switch (xenonRendererData.config.debugViewMode) {
		default:
		case RENDERER_DEBUG_VIEWMODE_NONE:
		case RENDERER_DEBUG_VIEWMODE_SSAO:
		case RENDERER_DEBUG_VIEWMODE_DENOISING_FACTOR:
			imageStore(img_normal_or_debug, COORDS, vec4(ray.normal, ssao));
			break;
		case RENDERER_DEBUG_VIEWMODE_NORMALS:
			// imageStore(img_normal_or_debug, COORDS, vec4(max(vec3(0), ray.normal), 1));
			imageStore(img_normal_or_debug, COORDS, vec4(normalize(WORLD2VIEWNORMAL * ray.normal), 1));
			break;
		case RENDERER_DEBUG_VIEWMODE_RAYGEN_TIME:
			WRITE_DEBUG_TIME
			// Fallthrough
		case RENDERER_DEBUG_VIEWMODE_RAYHIT_TIME:
		case RENDERER_DEBUG_VIEWMODE_RAYINT_TIME:
			imageStore(img_normal_or_debug, COORDS, vec4(HeatmapClamped(float(imageLoad(img_normal_or_debug, COORDS).a / (10000000 * xenonRendererData.config.debugViewScale))), 1));
			break;
		case RENDERER_DEBUG_VIEWMODE_MOTION:
			imageStore(img_normal_or_debug, COORDS, vec4(abs(motion * 1000 * xenonRendererData.config.debugViewScale), 1));
			break;
		case RENDERER_DEBUG_VIEWMODE_DISTANCE:
			imageStore(img_normal_or_debug, COORDS, vec4(hitSomething? HeatmapClamped(pow(ray.hitDistance / 1000 * xenonRendererData.config.debugViewScale, 0.4)) : vec3(0), 1));
			break;
		case RENDERER_DEBUG_VIEWMODE_ALPHA:
			imageStore(img_normal_or_debug, COORDS, vec4(HeatmapClamped(pow(imageLoad(img_resolved, COORDS).a, xenonRendererData.config.debugViewScale)), 1));
			break;
		case RENDERER_DEBUG_VIEWMODE_AIM_RENDERABLE:
			if (renderer.aim.tlasInstanceIndex == ray.renderableIndex) {
				imageStore(img_normal_or_debug, COORDS, vec4(1,0,1, 0.5));
			}
			break;
		case RENDERER_DEBUG_VIEWMODE_AIM_GEOMETRY: 
			if (renderer.aim.tlasInstanceIndex == ray.renderableIndex && renderer.aim.geometryIndex == ray.geometryIndex) {
				imageStore(img_normal_or_debug, COORDS, vec4(1,0,1, 0.5));
			}
			break;
		case RENDERER_DEBUG_VIEWMODE_AIM_PRIMITIVE:
			if (renderer.aim.tlasInstanceIndex == ray.renderableIndex && renderer.aim.geometryIndex == ray.geometryIndex && renderer.aim.primitiveIndex == ray.primitiveIndex) {
				imageStore(img_normal_or_debug, COORDS, vec4(1,0,1, 0.5));
			}
			break;
		case RENDERER_DEBUG_VIEWMODE_TRACE_RAY_COUNT:
			float nbRays = imageLoad(img_normal_or_debug, COORDS).a;
			imageStore(img_normal_or_debug, COORDS, vec4(nbRays > 0? HeatmapClamped(xenonRendererData.config.debugViewScale * nbRays / 8) : vec3(0), 1));
			break;
		case RENDERER_DEBUG_VIEWMODE_GLOBAL_ILLUMINATION:
		case RENDERER_DEBUG_VIEWMODE_UVS:
		case RENDERER_DEBUG_VIEWMODE_DIRECT_LIGHTS:
		case RENDERER_DEBUG_VIEWMODE_GI_LIGHTS:
		case RENDERER_DEBUG_VIEWMODE_ENVIRONMENT_AUDIO:
		case RENDERER_DEBUG_VIEWMODE_TEST:
			break;
	}
}
