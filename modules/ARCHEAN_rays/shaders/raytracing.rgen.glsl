#define SHADER_RGEN
#include "common.inc.glsl"

layout(location = 0) rayPayloadEXT RayPayload ray0; // primary ray
layout(location = 1) rayPayloadEXT RayPayload ray1; // reflection/glossiness
layout(location = 2) rayPayloadEXT RayPayload ray2; // direct lighting
layout(location = 3) rayPayloadEXT RayPayload ray3; // metallic reflection
layout(location = 4) rayPayloadEXT RayPayload ray4; // ambient lighting

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

void ApplyMetallicReflection(inout RayPayload ray, inout vec3 rayOrigin, inout vec3 rayDirection, in uint mask) {
	float attenuation = 1;
	for (int RAYLOOP = 0; RAYLOOP < 12; ++RAYLOOP) {
		if (ray.metallic < 0.5) break;
		if (ray.roughness > 0.01) break;
		if (attenuation < 0.01) break;
		rayOrigin += rayDirection * ray.t1 + ray.normal * EPSILON;
		rayDirection = reflect(rayDirection, ray.normal);
		traceRayEXT(tlas, gl_RayFlagsCullBackFacingTrianglesEXT/*flags*/, mask, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, rayOrigin, renderer.cameraZNear, rayDirection, xenonRendererData.config.zFar, 3/*payloadIndex*/);
		ray3.emission *= attenuation;
		ray3.albedo *= attenuation;
		ray = ray3;
		attenuation *= 0.5;
	}
}

#define NB_LIGHTS 16
#define SORT_LIGHTS

vec3 GetDirectLighting(in vec3 position, in vec3 rayDirection, in RayPayload ray) {
	if (dot(ray.albedo, ray.albedo) == 0) return vec3(0);
	
	position += ray.normal * ray.t1 * EPSILON;
	
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
		vec3 lightPosition = rayQueryGetIntersectionObjectToWorldEXT(q, false)[3].xyz; // may be broken on AMD...
		int lightID = rayQueryGetIntersectionInstanceIdEXT(q, false);
		vec3 relativeLightPosition = lightPosition - position;
		vec3 lightDir = normalize(relativeLightPosition);
		float nDotL = dot(ray.normal, lightDir);
		LightSourceInstanceData lightSource = renderer.lightSources[lightID].instance;
		float distanceToLightSurface = length(relativeLightPosition) - lightSource.innerRadius - ray.t1 * EPSILON;
		if (distanceToLightSurface <= 0.001) {
			directLighting += lightSource.color * lightSource.power;
		} else if (nDotL > 0 && distanceToLightSurface < lightSource.maxDistance) {
			float effectiveLightIntensity = max(0, lightSource.power / (4.0 * PI * distanceToLightSurface*distanceToLightSurface + 1) - LIGHT_LUMINOSITY_VISIBLE_THRESHOLD);
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
			lightsRadius[index] = lightSource.innerRadius;
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
	
	if (xenonRendererData.config.debugViewMode == RENDERER_DEBUG_VIEWMODE_DIRECT_LIGHTS) {
		imageStore(img_normal_or_debug, COORDS, vec4(HeatmapClamped(float(nbLights) / float(NB_LIGHTS)), 1));
	}
	
	bool rayIsUnderWater = RAY_IS_UNDERWATER;
	
	int usefulLights = 0;
	for (uint i = 0; i < nbLights; ++i) {
		vec3 shadowRayDir = lightsDir[i];
		bool isSunLight = lightsDistance[i] > 1e7;
		float shadowRayStart = 0;
		vec3 transmittance = vec3(1);
		const float MAX_SHADOW_TRANSPARENCY_RAYS = 8;
		for (int j = 0; j < MAX_SHADOW_TRANSPARENCY_RAYS; ++j) {
			if (dot(shadowRayDir, ray.normal) > 0) {
				vec3 rayDir = shadowRayDir;
				uint shadowTraceMask = RAYTRACE_MASK_TERRAIN|RAYTRACE_MASK_ENTITY|RAYTRACE_MASK_CLUTTER;
				// if (rayIsUnderWater) {
				// 	if (j == 0) {
				// 		shadowTraceMask |= RAYTRACE_MASK_HYDROSPHERE;
				// 	}
				// }
				RAY_RECURSION_PUSH
					RAY_SHADOW_PUSH
						traceRayEXT(tlas, gl_RayFlagsOpaqueEXT, shadowTraceMask, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, position, shadowRayStart, rayDir, lightsDistance[i] - EPSILON, 2);
					RAY_SHADOW_POP
				RAY_RECURSION_POP
				if (ray2.t1 == -1) {
					// lit
					vec3 light = lightsColor[i] * lightsPower[i];
					vec3 diffuse = ray.albedo * light * clamp(dot(ray.normal, shadowRayDir) * mix(1-Fresnel(rayDirection, ray.normal, ray.ior), 1, ray.roughness), 0, 1) * (1 - ray.metallic) * mix(0.5, 1, ray.roughness);
					vec3 reflectDir = reflect(-shadowRayDir, ray.normal);
					vec3 specular = light * pow(max(dot(-rayDirection, reflectDir), 0.0), mix(16, 4, ray.metallic)) * mix(vec3(1), ray.albedo, ray.metallic);
					directLighting += transmittance * mix(diffuse, (diffuse + specular) * 0.5, step(1, float(renderer.options & RENDERER_OPTION_SPECULAR_SURFACES)) * ray.specular);
					
					break;
					
				} else {
					if (dot(ray2.transmittance, ray2.transmittance) == 0) {
						break;
					}
					
					// if (rayIsUnderWater) {
					// 	float dist = min(lightsDistance[i], max(ray.t2, ray.hitDistance));
					// 	ray.color.a = pow(clamp(dist - ray.hitDistance, 0, WATER_MAX_LIGHT_DEPTH) / WATER_MAX_LIGHT_DEPTH, 0.5);
					// 	ray.color.rgb *= (1 - ray.color.a);
					// 	// if (isSunLight) {
					// 	// 	// its a sun light, make caustics
					// 	// 	vec3 lightIncomingDir = normalize(normalize(vec3(renderer.worldOrigin)) + shadowRayDir); // approximation of the refracted ray, good enough here
					// 	// 	opacity += 1 - clamp(caustics(worldPosition*vec3(0.9,0.5,0.7), lightIncomingDir, float(renderer.timestamp)) * 0.5 + 0.5, 0, 1);
					// 	// }
					// }
					
					transmittance *= ray2.transmittance;
					
					shadowRayStart = max(ray2.t1, ray2.t2) * 1.0001;
				}
				if (dot(transmittance, transmittance) < 0.001) break;
			}
		}
	}
	return directLighting;
}

vec3 GetAmbientLighting(in vec3 position, in vec3 rayDirection, in RayPayload ray) {
	float realDistance = length(position - inverse(renderer.viewMatrix)[3].xyz);
	vec3 ambient = vec3(pow(smoothstep(200/*max ambient distance*/, 0, realDistance), 4)) * renderer.baseAmbientBrightness * 0.1;
	if ((renderer.options & RENDERER_OPTION_RT_AMBIENT_LIGHTING) != 0) {
		// if (recursions <= 1) {
			float ambientFactor = 1;
			if (renderer.ambientOcclusionSamples > 0) {
				ambient /= renderer.ambientOcclusionSamples;
				const float maxAmbientDistance = renderer.ambientOcclusionSamples * 4;
				float avgHitDistance = 0;
				for (int i = 0; i < renderer.ambientOcclusionSamples; ++i) {
					rayQueryEXT rq;
					rayQueryInitializeEXT(rq, tlas, gl_RayFlagsOpaqueEXT, RAYTRACE_MASK_TERRAIN|RAYTRACE_MASK_ENTITY|RAYTRACE_MASK_CLUTTER, position, ray.t1 * 0.001, normalize(ray.normal + RandomInUnitSphere(seed)), maxAmbientDistance);
					while (rayQueryProceedEXT(rq)) {
						uint type = rayQueryGetIntersectionTypeEXT(rq, false);
						if (type == gl_RayQueryCandidateIntersectionAABBEXT) {
							vec3 _rayOrigin = rayQueryGetIntersectionObjectRayOriginEXT(rq,false);
							vec3 _rayDirection = rayQueryGetIntersectionObjectRayDirectionEXT(rq,false);
							AabbData aabbData = renderer.renderableInstances[rayQueryGetIntersectionInstanceIdEXT(rq,false)].geometries[rayQueryGetIntersectionGeometryIndexEXT(rq,false)].aabbs[rayQueryGetIntersectionPrimitiveIndexEXT(rq,false)];
							const vec3 _tbot = (vec3(aabbData.aabb[0], aabbData.aabb[1], aabbData.aabb[2]) - _rayOrigin) / _rayDirection;
							const vec3 _ttop = (vec3(aabbData.aabb[3], aabbData.aabb[4], aabbData.aabb[5]) - _rayOrigin) / _rayDirection;
							const vec3 _tmin = min(_ttop, _tbot);
							const vec3 _tmax = max(_ttop, _tbot);
							const float T1 = max(_tmin.x, max(_tmin.y, _tmin.z));
							const float T2 = min(_tmax.x, min(_tmax.y, _tmax.z));
							if (rayQueryGetRayTMinEXT(rq) <= T1 && T2 > T1) {
								rayQueryGenerateIntersectionEXT(rq, T1);
							}
						} else {
							rayQueryConfirmIntersectionEXT(rq);
						}
					}
					float hitDistance = rayQueryGetIntersectionTEXT(rq, true);
					avgHitDistance += hitDistance>0? hitDistance : maxAmbientDistance;
				}
				ambientFactor = pow(clamp(avgHitDistance / maxAmbientDistance / renderer.ambientOcclusionSamples, 0, 1), 2);
			}
			uint fakeGiSeed = 598734;
			RAY_RECURSION_PUSH
				RAY_GI_PUSH
				for (int i = 0; i < renderer.ambientAtmosphereSamples; ++i) {
					traceRayEXT(tlas, gl_RayFlagsOpaqueEXT, RAYTRACE_MASK_ATMOSPHERE, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, position, 1.0, normalize(ray.normal + RandomInUnitSphere(fakeGiSeed)), 10000, 4);
					ambient += pow(ray4.emission, vec3(0.5)) / renderer.ambientAtmosphereSamples * ambientFactor * renderer.baseAmbientBrightness;
					// ambient = max(ambient, pow(ray4.emission, vec3(0.5)) * ambientFactor * renderer.baseAmbientBrightness);
				}
				RAY_GI_POP
			RAY_RECURSION_POP
		// }
		return ray.albedo * ambient * max(1, renderer.ambientOcclusionSamples) / 32;
	} else {
		return ray.albedo * ambient / 4;
	}
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
	
	imageStore(rtPayloadImage, COORDS, u8vec4(0));
	imageStore(img_depth, COORDS, vec4(0));
	imageStore(img_motion, COORDS, vec4(0));
	
	vec3 rayOrigin = initialRayPosition;
	vec3 rayDirection = normalize(VIEW2WORLDNORMAL * viewDir);
	vec3 color = vec3(0);
	float opacity = 0;
	vec3 transmittance = vec3(1);
	
	uint mask = RAYTRACE_MASK_TERRAIN|RAYTRACE_MASK_ENTITY|RAYTRACE_MASK_CLUTTER|RAYTRACE_MASK_ATMOSPHERE;
	for (int RAYLOOP = 0; RAYLOOP < 12; ++RAYLOOP) {
		traceRayEXT(tlas, gl_RayFlagsCullBackFacingTrianglesEXT/*flags*/, mask, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, rayOrigin, renderer.cameraZNear, rayDirection, xenonRendererData.config.zFar, 0/*payloadIndex*/);
		mask &= ~ray0.mask;
		
		opacity += 1 - clamp(max(max(ray0.transmittance.r, ray0.transmittance.g), ray0.transmittance.b), 0, 1);
		
		ApplyMetallicReflection(ray0, rayOrigin, rayDirection, mask);
		
		color += transmittance * ray0.emission.rgb * renderer.globalLightingFactor;
		
		if (ray0.t1 == -1)
			break;
		
		rayOrigin += rayDirection * ray0.t1;
		color += transmittance * GetDirectLighting(rayOrigin, rayDirection, ray0) * renderer.globalLightingFactor;
		color += transmittance * GetAmbientLighting(rayOrigin, rayDirection, ray0) * renderer.globalLightingFactor;
		
		vec3 reflectionRayOrigin = rayOrigin;
		vec3 reflectionRayDirection = reflect(rayDirection, ray0.normal);
		if (ray0.reflectance > 0) {
			float fresnel = Fresnel(-reflectionRayDirection, ray0.normal, ray0.ior);
			traceRayEXT(tlas, gl_RayFlagsCullBackFacingTrianglesEXT/*flags*/, mask, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, reflectionRayOrigin, renderer.cameraZNear, reflectionRayDirection, xenonRendererData.config.zFar, 1/*payloadIndex*/);
			mask &= ~ray1.mask;
			ApplyMetallicReflection(ray1, reflectionRayOrigin, reflectionRayDirection, mask);
			reflectionRayOrigin += reflectionRayDirection * ray1.t1;
			vec3 factor = transmittance * fresnel * ray0.reflectance * renderer.globalLightingFactor;
			color += factor * ray1.emission.rgb;
			if (ray1.t1 != -1) {
				color += factor * GetDirectLighting(reflectionRayOrigin, reflectionRayDirection, ray1);
				color += factor * GetAmbientLighting(reflectionRayOrigin, reflectionRayDirection, ray1);
			}
		}
		if (dot(ray0.transmittance, ray0.transmittance) > 0) {
			Refract(rayDirection, ray0.normal, ray0.ior);
			transmittance *= ray0.transmittance;
		} else {
			break;
		}
		
		if (dot(transmittance, transmittance) < 0.01)
			break;
	}
	
	imageStore(img_composite, COORDS, vec4(color.rgb, clamp(opacity, 0, 1)));
	
	
	
	
	
	// if (isMiddleOfScreen) {
	// 	renderer.aim.monitorIndex = 0;
	// }
	
	// // Warp drive
	// if (renderer.warp > 0) {
	// 	const float centerFactor = length((pixelCenter/screenSize-0.5) * vec2(screenSize.x / screenSize.y, 1));
	// 	viewDir.xy = mix(viewDir.xy, viewDir.xy * pow(clamp(centerFactor, 0.08, 1), 2) , renderer.warp);
	// }
	
	// vec3 rayDirection = normalize(VIEW2WORLDNORMAL * viewDir);
	
	// imageStore(rtPayloadImage, COORDS, u8vec4(0));
	// imageStore(img_primary_albedo_roughness, COORDS, u8vec4(0));
	// if (xenonRendererData.config.debugViewMode != 0) {
	// 	imageStore(img_normal_or_debug, COORDS, vec4(0));
	// }
	
	// ray.hitDistance = -1;
	// ray.t2 = 0;
	// ray.normal = vec3(0);
	// ray.color = vec4(0);
	// ray.ssao = 0;
	// ray.metallicReflectance = 0;
	// ray.glassReflectance = 0;
	// ray.ior = 0;
	// ray.mask = 0;
	// vec3 rayOrigin = initialRayPosition;
	// vec3 glassTint = vec3(1);
	// float ssao = 1;
	// float transparency = 1.0;
	// ray.plasma = vec4(0);
	// uint primaryRayMask = RAYTRACE_MASK_TERRAIN|RAYTRACE_MASK_ENTITY|RAYTRACE_MASK_ATMOSPHERE|RAYTRACE_MASK_HYDROSPHERE|RAYTRACE_MASK_CLUTTER|RAYTRACE_MASK_PLASMA;
	// if (xenonRendererData.config.debugViewMode == RENDERER_DEBUG_VIEWMODE_GI_LIGHTS) {
	// 	primaryRayMask |= RAYTRACE_MASK_LIGHT;
	// }
	// for (int i = 0; i < 10; ++i) {
	// 	traceRayEXT(tlas, gl_RayFlagsCullBackFacingTrianglesEXT|gl_RayFlagsOpaqueEXT/*flags*/, primaryRayMask, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, rayOrigin, renderer.cameraZNear, rayDirection, xenonRendererData.config.zFar, 0/*payloadIndex*/);
	// 	// Aim
	// 	if (i == 0 && isMiddleOfScreen) {
	// 		renderer.aim.localPosition = ray.localPosition;
	// 		renderer.aim.geometryIndex = ray.geometryIndex;
	// 		renderer.aim.aimID = ray.aimID;
	// 		renderer.aim.worldSpaceHitNormal = ray.normal;
	// 		renderer.aim.primitiveIndex = ray.primitiveIndex;
	// 		renderer.aim.worldSpacePosition = ray.worldPosition;
	// 		renderer.aim.hitDistance = ray.hitDistance;
	// 		renderer.aim.color = ray.color;
	// 		renderer.aim.viewSpaceHitNormal = normalize(WORLD2VIEWNORMAL * ray.normal);
	// 		renderer.aim.tlasInstanceIndex = ray.renderableIndex;
	// 	}
	// 	// ray.color.rgb *= clamp(transparency, 0.0, 1.0) * glassTint;
	// 	ssao *= ray.ssao;
	// 	if (ray.hitDistance == -1) {
	// 		break;
	// 	}
	// 	ssao *= ray.color.a;
	// 	vec3 tint = ray.color.rgb;
	// 	transparency *= min(0.95, 1.0 - clamp(ray.color.a, 0, 1));
	// 	glassTint *= tint;
	// 	rayOrigin += rayDirection * ray.hitDistance;
	// 	// Refraction on Glass
	// 	if (ray.color.a < 1.0 && ray.ior > 0 && RandomFloat(seed) > ray.color.a + ray.glassReflectance) {
	// 		Refract(rayDirection, ray.normal, ray.ior);
	// 	} else if (ray.glassReflectance > 0) {
	// 		rayOrigin = ray.worldPosition + ray.normal * max(2.0, ray.hitDistance) * EPSILON * 10;
	// 		rayDirection = reflect(rayDirection, ray.normal);
	// 	} else if (ray.metallicReflectance > 0) {
	// 		rayOrigin = ray.worldPosition + ray.normal * max(2.0, ray.hitDistance) * EPSILON * 10;
	// 		rayDirection = reflect(rayDirection, ray.normal);
	// 	} else break;
	// 	primaryRayMask &= ~ray.mask;
	// }
	// vec4 color = ray.color + ray.plasma;
	
	// float hitDistance = ray.hitDistance;
	// if (hitDistance < 0) {
	// 	hitDistance = xenonRendererData.config.zFar;
	// }

	// color.rgb *= pow(renderer.globalLightingFactor, 4);
	// color.a = mix(1, color.a, renderer.globalLightingFactor);
	
	// if (RAY_IS_UNDERWATER) {
	// 	color.a = 1;
	// }
	
	// bool hitSomething = ray.hitDistance >= 0 && ray.renderableIndex != -1;
	// vec3 motion;
	// float depth;
	
	// // Motion Vectors
	// if (hitSomething) {
	// 	mat4 mvp = xenonRendererData.config.projectionMatrix * renderer.viewMatrix * mat4(transpose(renderer.tlasInstances[ray.renderableIndex].transform));
		
	// 	// These two lines may cause problems on AMD if they didn't fix their bugs
	// 	renderer.mvpBuffer[ray.renderableIndex].mvp = mvp;
	// 	renderer.realtimeBuffer[ray.renderableIndex].mvpFrameIndex = xenonRendererData.frameIndex;
		
	// 	vec4 ndc = mvp * vec4(ray.localPosition, 1);
	// 	ndc /= ndc.w;
	// 	mat4 mvpHistory;
	// 	if (renderer.realtimeBufferHistory[ray.renderableIndex].mvpFrameIndex == xenonRendererData.frameIndex - 1) {
	// 		mvpHistory = renderer.mvpBufferHistory[ray.renderableIndex].mvp;
	// 	} else {
	// 		mvpHistory = renderer.reprojectionMatrix * mvp;
	// 	}
	// 	vec4 ndc_history = mvpHistory * vec4(ray.localPosition, 1);
	// 	ndc_history /= ndc_history.w;
	// 	motion = ndc_history.xyz - ndc.xyz;
	// 	vec4 clipSpace = mat4(xenonRendererData.config.projectionMatrix) * mat4(renderer.viewMatrix) * vec4(ray.worldPosition, 1);
	// 	depth = clamp(clipSpace.z / clipSpace.w, 0, 1);
	// } else {
	// 	vec4 ndc = vec4(uv * 2 - 1, 0, 1);
	// 	vec4 ndc_history = renderer.reprojectionMatrix * ndc;
	// 	ndc_history /= ndc_history.w;
	// 	motion = ndc_history.xyz - ndc.xyz;
	// 	depth = 0;
	// }
	
	// // Negative depth means underwater
	// if (RAY_IS_UNDERWATER) {
	// 	hitDistance *= -1;
	// }
	
	// imageStore(img_composite, COORDS, max(vec4(0), color));
	// imageStore(img_depth, COORDS, vec4(depth));
	// imageStore(img_motion, COORDS, vec4(motion, hitDistance));
	
	// // Trace environment audio
	// const int MAX_AUDIO_BOUNCE = 2;
	// const uvec2 environment_audio_trace_size = uvec2(200, 200);
	// if (gl_LaunchIDEXT.x < environment_audio_trace_size.x && gl_LaunchIDEXT.y < environment_audio_trace_size.y) {
	// 	RayPayload originalRay = ray;
	// 	vec3 testcolor = vec3(0);
	// 	vec3 rayDir = mapToSphere(vec2(gl_LaunchIDEXT) / vec2(environment_audio_trace_size));
	// 	rayOrigin = initialRayPosition;
	// 	int envAudioBounce = 0;
	// 	float audible = 1.0;
	// 	bool hitPlasma = false;
	// 	do {
	// 		ray.hitDistance = -1;
	// 		uint rayMask = RAYTRACE_MASK_TERRAIN | RAYTRACE_MASK_ENTITY | RAYTRACE_MASK_HYDROSPHERE | (hitPlasma?0:RAYTRACE_MASK_PLASMA);
	// 		RAY_SHADOW_PUSH
	// 			traceRayEXT(tlas, gl_RayFlagsCullBackFacingTrianglesEXT|gl_RayFlagsOpaqueEXT/*flags*/, rayMask/*rayMask*/, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, rayOrigin, 0.0, rayDir, 1000, 0/*payloadIndex*/);
	// 		RAY_SHADOW_POP
	// 		if (ray.hitDistance == -1 || ray.renderableIndex == -1) {
	// 			ray.hitDistance = 1000;
	// 			testcolor = vec3(0);
	// 			atomicAdd(renderer.environmentAudio.miss, 1);
	// 			break;
	// 		} else {
	// 			uint hitMask = renderer.tlasInstances[ray.renderableIndex].instanceCustomIndex_and_mask >> 24;
	// 			if (hitMask == RAYTRACE_MASK_TERRAIN) {
	// 				atomicAdd(renderer.environmentAudio.terrain, 1);
	// 				testcolor = mix(testcolor, vec3(1,0,0), audible);
	// 				break;
	// 			}
	// 			else if (hitMask == RAYTRACE_MASK_ENTITY) {
	// 				renderer.environmentAudio.audibleRenderables[ray.renderableIndex].audible = max(renderer.environmentAudio.audibleRenderables[ray.renderableIndex].audible, audible);
	// 				atomicAdd(renderer.environmentAudio.object, 1);
	// 				testcolor = mix(testcolor, vec3(0,1,0), audible);
	// 				if (envAudioBounce++ == MAX_AUDIO_BOUNCE) {
	// 					break;
	// 				}
	// 				rayOrigin += rayDir * ray.hitDistance + ray.normal * EPSILON;
	// 				rayDir = reflect(rayDir, ray.normal);
	// 				audible *= 0.5;
	// 			}
	// 			else if (hitMask == RAYTRACE_MASK_HYDROSPHERE) {
	// 				atomicAdd(renderer.environmentAudio.hydrosphere, 1);
	// 				renderer.environmentAudio.hydrosphereDistance = atomicMin(renderer.environmentAudio.hydrosphereDistance, int(ray.hitDistance * 100));
	// 				testcolor = mix(testcolor, vec3(0,0,1), audible);
	// 				break;
	// 			}
	// 			else if (hitMask == RAYTRACE_MASK_PLASMA) {
	// 				renderer.environmentAudio.audibleRenderables[ray.renderableIndex].audible = max(renderer.environmentAudio.audibleRenderables[ray.renderableIndex].audible, audible);
	// 				// atomicAdd(renderer.environmentAudio.object, 1);
	// 				testcolor = mix(testcolor, vec3(1,1,0), audible);
	// 				hitPlasma = true;
	// 			} else {
	// 				break;
	// 			}
	// 		}
	// 	} while (true);
	// 	if (xenonRendererData.config.debugViewMode == RENDERER_DEBUG_VIEWMODE_ENVIRONMENT_AUDIO) imageStore(img_normal_or_debug, COORDS, vec4(testcolor, 1));
	// 	ray = originalRay;
	// }
	
	// switch (xenonRendererData.config.debugViewMode) {
	// 	default:
	// 	case RENDERER_DEBUG_VIEWMODE_NONE:
	// 	case RENDERER_DEBUG_VIEWMODE_SSAO:
	// 	case RENDERER_DEBUG_VIEWMODE_DENOISING_FACTOR:
	// 		imageStore(img_normal_or_debug, COORDS, vec4(ray.normal, ssao));
	// 		break;
	// 	case RENDERER_DEBUG_VIEWMODE_NORMALS:
	// 		// imageStore(img_normal_or_debug, COORDS, vec4(max(vec3(0), ray.normal), 1));
	// 		imageStore(img_normal_or_debug, COORDS, vec4(normalize(WORLD2VIEWNORMAL * ray.normal), 1));
	// 		break;
	// 	case RENDERER_DEBUG_VIEWMODE_RAYGEN_TIME:
	// 		WRITE_DEBUG_TIME
	// 		// Fallthrough
	// 	case RENDERER_DEBUG_VIEWMODE_RAYHIT_TIME:
	// 	case RENDERER_DEBUG_VIEWMODE_RAYINT_TIME:
	// 		imageStore(img_normal_or_debug, COORDS, vec4(HeatmapClamped(float(imageLoad(img_normal_or_debug, COORDS).a / (1000000 * xenonRendererData.config.debugViewScale))), 1));
	// 		break;
	// 	case RENDERER_DEBUG_VIEWMODE_MOTION:
	// 		imageStore(img_normal_or_debug, COORDS, vec4(abs(motion * 1000 * xenonRendererData.config.debugViewScale), 1));
	// 		break;
	// 	case RENDERER_DEBUG_VIEWMODE_DISTANCE:
	// 		imageStore(img_normal_or_debug, COORDS, vec4(hitSomething? HeatmapClamped(pow(ray.hitDistance / 1000 * xenonRendererData.config.debugViewScale, 0.4)) : vec3(0), 1));
	// 		break;
	// 	case RENDERER_DEBUG_VIEWMODE_ALPHA:
	// 		imageStore(img_normal_or_debug, COORDS, vec4(HeatmapClamped(pow(imageLoad(img_resolved, COORDS).a, xenonRendererData.config.debugViewScale)), 1));
	// 		break;
	// 	case RENDERER_DEBUG_VIEWMODE_AIM_RENDERABLE:
	// 		if (renderer.aim.tlasInstanceIndex == ray.renderableIndex) {
	// 			imageStore(img_normal_or_debug, COORDS, vec4(1,0,1, 0.5));
	// 		}
	// 		break;
	// 	case RENDERER_DEBUG_VIEWMODE_AIM_GEOMETRY: 
	// 		if (renderer.aim.tlasInstanceIndex == ray.renderableIndex && renderer.aim.geometryIndex == ray.geometryIndex) {
	// 			imageStore(img_normal_or_debug, COORDS, vec4(1,0,1, 0.5));
	// 		}
	// 		break;
	// 	case RENDERER_DEBUG_VIEWMODE_AIM_PRIMITIVE:
	// 		if (renderer.aim.tlasInstanceIndex == ray.renderableIndex && renderer.aim.geometryIndex == ray.geometryIndex && renderer.aim.primitiveIndex == ray.primitiveIndex) {
	// 			imageStore(img_normal_or_debug, COORDS, vec4(1,0,1, 0.5));
	// 		}
	// 		break;
	// 	case RENDERER_DEBUG_VIEWMODE_TRACE_RAY_COUNT:
	// 		float nbRays = imageLoad(img_normal_or_debug, COORDS).a;
	// 		imageStore(img_normal_or_debug, COORDS, vec4(nbRays > 0? HeatmapClamped(xenonRendererData.config.debugViewScale * nbRays / 8) : vec3(0), 1));
	// 		break;
	// 	case RENDERER_DEBUG_VIEWMODE_GLOBAL_ILLUMINATION:
	// 	case RENDERER_DEBUG_VIEWMODE_UVS:
	// 	case RENDERER_DEBUG_VIEWMODE_DIRECT_LIGHTS:
	// 	case RENDERER_DEBUG_VIEWMODE_GI_LIGHTS:
	// 	case RENDERER_DEBUG_VIEWMODE_ENVIRONMENT_AUDIO:
	// 	case RENDERER_DEBUG_VIEWMODE_TEST:
	// 		break;
	// }
}
