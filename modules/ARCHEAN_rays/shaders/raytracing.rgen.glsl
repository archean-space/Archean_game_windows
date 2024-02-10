#define SHADER_RGEN
#include "common.inc.glsl"

ivec2 pixelInMiddleOfScreen = ivec2(gl_LaunchSizeEXT.xy) / 2;
bool isMiddleOfScreen = (COORDS == pixelInMiddleOfScreen);
vec2 pixelCenter = vec2(gl_LaunchIDEXT.xy) + vec2(0.5);
vec2 screenSize = vec2(gl_LaunchSizeEXT.xy);
vec2 uv = pixelCenter/screenSize;

layout(location = 0) rayPayloadEXT RayPayload ray;
layout(location = 1) rayPayloadEXT RayPayload glassReflectionRay;

#include "lighting.inc.glsl"

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

void WriteMotionVectorsAndDepth(in vec3 worldPosition, in float hitDistance, in bool force) {
	vec4 motion = imageLoad(img_motion, COORDS);
	if (force || motion.w == 0) {
		imageStore(img_motion, COORDS, vec4(motion.xyz, hitDistance));
		vec4 clipSpace = mat4(xenonRendererData.config.projectionMatrix) * mat4(renderer.viewMatrix) * vec4(worldPosition, 1);
		float depth = clamp(clipSpace.z / clipSpace.w, 0, 1);
		imageStore(img_depth, COORDS, vec4(depth));
	}
}

void ClearMotionVectorsAndDepth() {
	vec4 ndc = vec4(uv * 2 - 1, 0, 1);
	vec4 ndc_history = renderer.reprojectionMatrix * ndc;
	ndc_history /= ndc_history.w;
	vec3 motion = ndc_history.xyz - ndc.xyz;
	imageStore(img_depth, COORDS, vec4(0));
	imageStore(img_motion, COORDS, vec4(motion, 0));
}

void main() {
	const vec3 initialRayPosition = inverse(renderer.viewMatrix)[3].xyz;
	const mat4 projMatrix = isMiddleOfScreen? mat4(xenonRendererData.config.projectionMatrix) : mat4(xenonRendererData.config.projectionMatrixWithTAA);
	vec3 viewDir = normalize(vec4(inverse(projMatrix) * vec4(uv*2-1, 1, 1)).xyz);
	
	if (isMiddleOfScreen) {
		renderer.aim.aimID = 0;
		renderer.aim.monitorIndex = 0;
	}
	
	// Warp drive
	if (renderer.warp > 0) {
		const float centerFactor = length((pixelCenter/screenSize-0.5) * vec2(screenSize.x / screenSize.y, 1));
		viewDir.xy = mix(viewDir.xy, viewDir.xy * pow(clamp(centerFactor, 0.08, 1), 2) , renderer.warp);
	}
	
	vec3 initialRayDirection = normalize(VIEW2WORLDNORMAL * viewDir);
	vec3 rayDirection = initialRayDirection;
	
	imageStore(rtPayloadImage, COORDS, u8vec4(0));
	imageStore(img_primary_albedo_roughness, COORDS, u8vec4(0));
	if (xenonRendererData.config.debugViewMode != 0) {
		imageStore(img_normal_or_debug, COORDS, vec4(0));
	}
	
	ClearMotionVectorsAndDepth();
	
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
	ray.emission = vec3(0);
	uint primaryRayMask = RAYTRACE_MASK_TERRAIN|RAYTRACE_MASK_ENTITY|RAYTRACE_MASK_ATMOSPHERE|RAYTRACE_MASK_HYDROSPHERE|RAYTRACE_MASK_CLUTTER|RAYTRACE_MASK_PLASMA;
	if (xenonRendererData.config.debugViewMode == RENDERER_DEBUG_VIEWMODE_GI_LIGHTS) {
		primaryRayMask |= RAYTRACE_MASK_LIGHT;
	}
	do {
		traceRayEXT(tlas, /*gl_RayFlagsCullBackFacingTrianglesEXT|*/gl_RayFlagsOpaqueEXT/*flags*/, primaryRayMask, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, rayOrigin, renderer.cameraZNear, rayDirection, xenonRendererData.config.zFar, 0/*payloadIndex*/);
		float rDotN = dot(rayDirection, ray.normal);
		if (rDotN > 0 && ray.color.a < 1.0) {
			RayPayload originalRay = ray;
			traceRayEXT(tlas, gl_RayFlagsCullBackFacingTrianglesEXT|gl_RayFlagsOpaqueEXT/*flags*/, primaryRayMask, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, rayOrigin, originalRay.hitDistance * 0.999, rayDirection, originalRay.hitDistance * 1.001, 0/*payloadIndex*/);
			if (ray.hitDistance == -1) {
				ray = originalRay;
			}
		}
		ray.color.rgb *= clamp(transparency, 0.0, 1.0) * glassTint;
		ray.emission.rgb *= clamp(transparency, 0.0, 1.0) * glassTint;
		ssao *= ray.ssao;
		if (ray.hitDistance == -1) {
			break;
		}
		ssao *= ray.color.a;
		if (xenonRendererData.config.debugViewMode == RENDERER_DEBUG_VIEWMODE_NORMALS) {
			break;
		}
		vec3 tint = ray.color.rgb;
		transparency *= min(0.99, 1.0 - clamp(ray.color.a, 0, 1));
		glassTint *= tint;
		rayOrigin += rayDirection * ray.hitDistance;
		// Reflections on Glass
		if ((renderer.options & RENDERER_OPTION_GLASS_REFLECTIONS) != 0 && !glassReflection && ray.color.a != 1.0 && ray.hitDistance > 0.0 && ray.hitDistance < ATMOSPHERE_RAY_MIN_DISTANCE && rDotN < 0.0) {
			glassReflection = true;
			glassReflectionStrength = Fresnel(normalize((renderer.viewMatrix * vec4(rayOrigin, 1)).xyz), normalize(WORLD2VIEWNORMAL * ray.normal), 1.15);
			glassReflectionOrigin = rayOrigin + ray.normal * max(2.0, ray.hitDistance) * EPSILON * 10;
			glassReflectionDirection = reflect(rayDirection, ray.normal);
		}
		// Specular/Shadows on Glass
		if ((renderer.options & RENDERER_OPTION_DIRECT_LIGHTING) != 0 && ray.color.a < 1.0 && rDotN < 0) {
			RayPayload originalRay = ray;
			glassSpecular += GetDirectLighting(rayOrigin, rayDirection, originalRay.normal, vec3(0), originalRay.hitDistance, 0, 1, 0.5);
			ray = originalRay;
		}
		// Refraction on Glass
		if ((renderer.options & RENDERER_OPTION_GLASS_REFRACTION) != 0 && ray.color.a < 1.0) {
			vec3 originalRayDirection = rayDirection;
			float ior = 1.5;
			if (rDotN < 0) {
				ior = 1.0 / ior;
			} else {
				ssao = 0;
			}
			rayDirection = refract(rayDirection, sign(rDotN) * -ray.normal, ior);
			if (dot(rayDirection, rayDirection) == 0.0) {
				ssao = 0;
				rayDirection = reflect(originalRayDirection, sign(rDotN) * -ray.normal);
				color.a += 1;
			} else {
				color.a += ray.color.a;
				if (dot(initialRayDirection, originalRayDirection) > 0.707 && transparency > 0.5 && ray.color.a < 0.5) {
					ClearMotionVectorsAndDepth();
				}
			}
		}
	} while (ray.color.a < 1.0 && transparency > 0.01 && ray.hitDistance > 0.0);
	color += ray.color + vec4(ray.emission, 0) + vec4(glassSpecular, 0);
	
	// Reflections on Glass / Glossy
	if (glassReflection) {
		glassReflectionRay.color = vec4(0);
		glassReflectionRay.emission = vec3(0);
		glassReflectionRay.hitDistance = -1;
		glassReflectionRay.t2 = 0;
		WriteMotionVectorsAndDepth(glassReflectionOrigin, distance(initialRayPosition, glassReflectionOrigin), false);
		traceRayEXT(tlas, gl_RayFlagsCullBackFacingTrianglesEXT|gl_RayFlagsOpaqueEXT, RAYTRACE_MASK_TERRAIN|RAYTRACE_MASK_ENTITY|RAYTRACE_MASK_CLUTTER|RAYTRACE_MASK_ATMOSPHERE|RAYTRACE_MASK_HYDROSPHERE|RAYTRACE_MASK_PLASMA, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, glassReflectionOrigin, 0, glassReflectionDirection, xenonRendererData.config.zFar, 1);
		color.rgb = mix(color.rgb, glassReflectionRay.color.rgb, glassReflectionStrength * step(1.0, glassReflectionRay.color.a));
		color.rgb += glassReflectionRay.emission.rgb * glassReflectionStrength;
	}
	
	color.rgb *= pow(renderer.globalLightingFactor, 4);
	color.a = mix(1, color.a, renderer.globalLightingFactor);
	
	if (RAY_IS_UNDERWATER || color.a > 1) {
		color.a = 1;
	}
	
	bool hitSomething = ray.hitDistance >= 0 && ray.renderableIndex != -1;
	
	if (RAY_IS_UNDERWATER) {
		// Negative distance means underwater
		imageStore(img_motion, COORDS, vec4(0,0,0,-1));
	} else {
		vec4 motion = imageLoad(img_motion, COORDS);
		if (motion.a <= 0) {
			imageStore(img_motion, COORDS, vec4(motion.xyz, xenonRendererData.config.zFar));
		}
	}
	
	imageStore(img_composite, COORDS, max(vec4(0), color));
	
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
			imageStore(img_normal_or_debug, COORDS, vec4(abs(imageLoad(img_motion, COORDS).rgb * 1000 * xenonRendererData.config.debugViewScale), 1));
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
