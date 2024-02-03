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

// Caustics
float h12(vec2 p) {
	return fract(sin(dot(p,vec2(32.52554,45.5634)))*12432.2355);
}
float n12(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f *= f * (3.-2.*f);
	return mix(
		mix(h12(i+vec2(0.,0.)),h12(i+vec2(1.,0.)),f.x),
		mix(h12(i+vec2(0.,1.)),h12(i+vec2(1.,1.)),f.x),
		f.y
	);
}
vec2 getUVfromWorldPos(vec3 position, vec3 normal) {
	vec3 up = abs(normal.z) < 0.99 ? vec3(0,0,1) : vec3(0,1,0);
	vec3 right = normalize(cross(up, normal));
	up = cross(normal, right);
	return vec2(dot(position, right), dot(position, up));
}
float caustics(vec3 worldPosition, vec3 normal, float t) {
	vec2 p = getUVfromWorldPos(worldPosition, normal);
	vec3 k = vec3(p,t);
	float l;
	mat3 m = mat3(-2,-1,2,3,-2,1,1,2,2);
	float n = n12(p);
	k = k*m*.5;
	l = length(.5 - fract(k+n));
	k = k*m*.4;
	l = min(l, length(.5-fract(k+n)));
	k = k*m*.3;
	l = min(l, length(.5-fract(k+n)));
	return pow(l,7.)*25.;
}

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
		LightSourceInstanceData lightSource = renderer.lightSources[nonuniformEXT(lightID)].instance;
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
	
	RAY_SHADOW_PUSH
	int usefulLights = 0;
	for (uint i = 0; i < nbLights; ++i) {
		vec3 shadowRayDir = lightsDir[i];
		bool isSunLight = lightsDistance[i] > 1e7;
		float shadowRayStart = 0;
		vec3 transmittance = vec3(1);
		const float MAX_SHADOW_TRANSPARENCY_RAYS = 8;
		uint shadowTraceMask = RAYTRACE_MASK_TERRAIN|RAYTRACE_MASK_ENTITY|RAYTRACE_MASK_CLUTTER|RAYTRACE_MASK_HYDROSPHERE;
		for (int j = 0; j < MAX_SHADOW_TRANSPARENCY_RAYS; ++j) {
			if (dot(shadowRayDir, ray.normal) > 0) {
				vec3 rayDir = shadowRayDir;
				ray2.t1 = shadowRayStart;
				ray2.t2 = lightsDistance[i];
				traceRayEXT(tlas, gl_RayFlagsOpaqueEXT, shadowTraceMask, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, position, shadowRayStart, rayDir, lightsDistance[i] - EPSILON, 2);
				shadowTraceMask &= ~ray2.mask;
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
					
					// if its a sun light and we're underwater, make caustics
					if (isSunLight && (ray.mask & RAYTRACE_MASK_HYDROSPHERE) != 0) {
						vec3 lightIncomingDir = normalize(normalize(vec3(renderer.worldOrigin)) + shadowRayDir); // approximation of the refracted ray, good enough here
						transmittance *= clamp(caustics(position*vec3(0.9,0.5,0.7), lightIncomingDir, float(renderer.timestamp)) * 0.5 + 0.5, 0, 1);
					}
					
					transmittance *= ray2.transmittance;
					shadowRayStart = max(ray2.t1, ray2.t2) * 1.0001;
				}
				if (dot(transmittance, transmittance) < EPSILON*EPSILON) break;
			}
		}
	}
	RAY_SHADOW_POP
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
							AabbData aabbData = renderer.renderableInstances[nonuniformEXT(rayQueryGetIntersectionInstanceIdEXT(rq,false))].geometries[nonuniformEXT(rayQueryGetIntersectionGeometryIndexEXT(rq,false))].aabbs[nonuniformEXT(rayQueryGetIntersectionPrimitiveIndexEXT(rq,false))];
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
	
	if (isMiddleOfScreen) {
		renderer.aim.aimID = 0;
		renderer.aim.monitorIndex = 0;
	}
	
	// // Warp drive
	// if (renderer.warp > 0) {
	// 	const float centerFactor = length((pixelCenter/screenSize-0.5) * vec2(screenSize.x / screenSize.y, 1));
	// 	viewDir.xy = mix(viewDir.xy, viewDir.xy * pow(clamp(centerFactor, 0.08, 1), 2) , renderer.warp);
	// }
	
	ray0.mask = 0;
	ray1.mask = 0;
	ray2.mask = 0;
	ray3.mask = 0;
	ray4.mask = 0;
	
	imageStore(rtPayloadImage, COORDS, u8vec4(0));
	if (xenonRendererData.config.debugViewMode != 0) {
		imageStore(img_normal_or_debug, COORDS, vec4(0));
	}
	
	vec3 rayOrigin = initialRayPosition;
	vec3 rayDirection = normalize(VIEW2WORLDNORMAL * viewDir);
	vec3 color = vec3(0);
	float opacity = 0;
	vec3 transmittance = vec3(1);
	
	float hitDistance = -1;
	int hitRenderableIndex = -1;
	vec3 hitWorldPosition = vec3(0);
	vec3 hitLocalPosition = vec3(0);
	vec3 hitNormal = vec3(0);
	float attenuationDistance = -1;
	
	uint mask = RAYTRACE_MASK_TERRAIN|RAYTRACE_MASK_ENTITY|RAYTRACE_MASK_CLUTTER|RAYTRACE_MASK_ATMOSPHERE|RAYTRACE_MASK_HYDROSPHERE|RAYTRACE_MASK_PLASMA;
	for (int RAYLOOP = 0; RAYLOOP < 12; ++RAYLOOP) {
		traceRayEXT(tlas, gl_RayFlagsCullBackFacingTrianglesEXT/*flags*/, mask, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, rayOrigin, renderer.cameraZNear, rayDirection, xenonRendererData.config.zFar, 0/*payloadIndex*/);
		mask &= ~ray0.mask;
		
		if (RAYLOOP == 0 && hitDistance == -1) hitDistance = ray0.t1;
		hitRenderableIndex = ray0.renderableIndex;
		hitWorldPosition = rayOrigin + rayDirection * ray0.t1;
		hitLocalPosition = ray0.localPosition;
		hitNormal = ray0.normal;
		
		opacity += 1 - clamp(max(max(ray0.transmittance.r, ray0.transmittance.g), ray0.transmittance.b), 0, 1);
		
		if (ray0.t1 > 0 && attenuationDistance > 0) {
			transmittance *= pow(1 - clamp(ray0.t1 / attenuationDistance, 0, 1), 4);
		}
	
		ApplyMetallicReflection(ray0, rayOrigin, rayDirection, mask);
		
		color += transmittance * ray0.emission.rgb;
		
		// Attenuation
		if (dot(ray0.transmittance, vec3(1)) < 0) {
			transmittance *= -ray0.transmittance;
		}
		
		if (ray0.t1 <= 0)
			break;
		
		rayOrigin += rayDirection * ray0.t1;
		color += transmittance * GetDirectLighting(rayOrigin, rayDirection, ray0);
		color += transmittance * GetAmbientLighting(rayOrigin, rayDirection, ray0);
		
		if (ray0.reflectance > 0) {
			vec3 reflectionRayOrigin = rayOrigin;
			vec3 reflectionRayDirection = reflect(rayDirection, ray0.normal);
			float fresnel = Fresnel(-reflectionRayDirection, ray0.normal, ray0.ior);
			traceRayEXT(tlas, gl_RayFlagsCullBackFacingTrianglesEXT/*flags*/, mask, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, reflectionRayOrigin, renderer.cameraZNear, reflectionRayDirection, xenonRendererData.config.zFar, 1/*payloadIndex*/);
			mask &= ~ray1.mask;
			ApplyMetallicReflection(ray1, reflectionRayOrigin, reflectionRayDirection, mask);
			reflectionRayOrigin += reflectionRayDirection * ray1.t1;
			vec3 factor = transmittance * fresnel * ray0.reflectance;
			color += factor * ray1.emission.rgb;
			if (ray1.t1 != -1) {
				color += factor * GetDirectLighting(reflectionRayOrigin, reflectionRayDirection, ray1);
				color += factor * GetAmbientLighting(reflectionRayOrigin, reflectionRayDirection, ray1);
			}
		}
		if (dot(ray0.transmittance, vec3(1)) > 0) {
			vec3 refractionRayDir = refract(rayDirection, ray0.normal, 1.0 / ray0.ior);
			if (dot(refractionRayDir, refractionRayDir) == 0) {
				refractionRayDir = reflect(rayDirection, ray0.normal);
				rayDirection = refractionRayDir;
				transmittance *= ray0.transmittance;
			} else {
				rayDirection = refractionRayDir;
				transmittance *= ray0.transmittance * pow(1-Fresnel(-rayDirection, ray0.normal, ray0.ior), 2);
			}
			attenuationDistance = ray0.t2;
		} else {
			break;
		}
		
		if (dot(transmittance, vec3(1)) < 0.01)
			break;
	}
	
	if (hitDistance < 0) {
		hitDistance = xenonRendererData.config.zFar;
	}

	color *= pow(renderer.globalLightingFactor, 4);
	opacity = mix(1, opacity, renderer.globalLightingFactor);
	
	// if (RAY_IS_UNDERWATER) {
	// 	opacity = 1;
	// }
	
	vec3 motion;
	float depth;
	
	// Motion Vectors
	if (hitRenderableIndex != -1) {
		mat4 mvp = xenonRendererData.config.projectionMatrix * renderer.viewMatrix * mat4(transpose(renderer.tlasInstances[nonuniformEXT(hitRenderableIndex)].transform));
		
		// These two lines may cause problems on AMD if they didn't fix their bugs
		renderer.mvpBuffer[nonuniformEXT(hitRenderableIndex)].mvp = mvp;
		renderer.realtimeBuffer[nonuniformEXT(hitRenderableIndex)].mvpFrameIndex = xenonRendererData.frameIndex;
		
		vec4 ndc = mvp * vec4(hitLocalPosition, 1);
		ndc /= ndc.w;
		mat4 mvpHistory;
		if (renderer.realtimeBufferHistory[nonuniformEXT(hitRenderableIndex)].mvpFrameIndex == xenonRendererData.frameIndex - 1) {
			mvpHistory = renderer.mvpBufferHistory[nonuniformEXT(hitRenderableIndex)].mvp;
		} else {
			mvpHistory = renderer.reprojectionMatrix * mvp;
		}
		vec4 ndc_history = mvpHistory * vec4(hitLocalPosition, 1);
		ndc_history /= ndc_history.w;
		motion = ndc_history.xyz - ndc.xyz;
		vec4 clipSpace = mat4(xenonRendererData.config.projectionMatrix) * mat4(renderer.viewMatrix) * vec4(hitWorldPosition, 1);
		depth = clamp(clipSpace.z / clipSpace.w, 0, 1);
	} else {
		vec4 ndc = vec4(uv * 2 - 1, 0, 1);
		vec4 ndc_history = renderer.reprojectionMatrix * ndc;
		ndc_history /= ndc_history.w;
		motion = ndc_history.xyz - ndc.xyz;
		depth = 0;
	}
	
	// // Negative depth means underwater
	// if (RAY_IS_UNDERWATER) {
	// 	hitDistance *= -1;
	// }
	
	imageStore(img_composite, COORDS, vec4(color.rgb, clamp(opacity, 0, 1)));
	imageStore(img_depth, COORDS, vec4(depth));
	imageStore(img_motion, COORDS, vec4(motion, hitDistance));
	
	// Trace environment audio
	const int MAX_AUDIO_BOUNCE = 2;
	const uvec2 environment_audio_trace_size = uvec2(200, 200);
	if (gl_LaunchIDEXT.x < environment_audio_trace_size.x && gl_LaunchIDEXT.y < environment_audio_trace_size.y) {
		vec3 testcolor = vec3(0);
		vec3 rayDir = mapToSphere(vec2(gl_LaunchIDEXT) / vec2(environment_audio_trace_size));
		rayOrigin = initialRayPosition;
		int envAudioBounce = 0;
		float audible = 1.0;
		bool hitPlasma = false;
		do {
			ray0.t1 = -1;
			uint rayMask = RAYTRACE_MASK_TERRAIN | RAYTRACE_MASK_ENTITY | RAYTRACE_MASK_HYDROSPHERE | (hitPlasma?0:RAYTRACE_MASK_PLASMA);
			RAY_SHADOW_PUSH
				traceRayEXT(tlas, gl_RayFlagsCullBackFacingTrianglesEXT|gl_RayFlagsOpaqueEXT/*flags*/, rayMask/*rayMask*/, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, rayOrigin, 0.0, rayDir, 1000, 0/*payloadIndex*/);
			RAY_SHADOW_POP
			if (ray0.t1 == -1 || ray0.renderableIndex == -1) {
				ray0.t1 = 1000;
				testcolor = vec3(0);
				atomicAdd(renderer.environmentAudio.miss, 1);
				break;
			} else {
				uint hitMask = renderer.tlasInstances[nonuniformEXT(ray0.renderableIndex)].instanceCustomIndex_and_mask >> 24;
				if (hitMask == RAYTRACE_MASK_TERRAIN) {
					atomicAdd(renderer.environmentAudio.terrain, 1);
					testcolor = mix(testcolor, vec3(1,0,0), audible);
					break;
				}
				else if (hitMask == RAYTRACE_MASK_ENTITY) {
					renderer.environmentAudio.audibleRenderables[nonuniformEXT(ray0.renderableIndex)].audible = max(renderer.environmentAudio.audibleRenderables[nonuniformEXT(ray0.renderableIndex)].audible, audible);
					atomicAdd(renderer.environmentAudio.object, 1);
					testcolor = mix(testcolor, vec3(0,1,0), audible);
					if (envAudioBounce++ == MAX_AUDIO_BOUNCE) {
						break;
					}
					rayOrigin += rayDir * ray0.t1 + ray0.normal * EPSILON;
					rayDir = reflect(rayDir, ray0.normal);
					audible *= 0.5;
				}
				else if (hitMask == RAYTRACE_MASK_HYDROSPHERE) {
					atomicAdd(renderer.environmentAudio.hydrosphere, 1);
					renderer.environmentAudio.hydrosphereDistance = atomicMin(renderer.environmentAudio.hydrosphereDistance, int(ray0.t1 * 100));
					testcolor = mix(testcolor, vec3(0,0,1), audible);
					break;
				}
				else if (hitMask == RAYTRACE_MASK_PLASMA) {
					renderer.environmentAudio.audibleRenderables[nonuniformEXT(ray0.renderableIndex)].audible = max(renderer.environmentAudio.audibleRenderables[nonuniformEXT(ray0.renderableIndex)].audible, audible);
					// atomicAdd(renderer.environmentAudio.object, 1);
					testcolor = mix(testcolor, vec3(1,1,0), audible);
					hitPlasma = true;
				} else {
					break;
				}
			}
		} while (true);
		if (xenonRendererData.config.debugViewMode == RENDERER_DEBUG_VIEWMODE_ENVIRONMENT_AUDIO) imageStore(img_normal_or_debug, COORDS, vec4(testcolor, 1));
	}
	
	switch (xenonRendererData.config.debugViewMode) {
		default:
		case RENDERER_DEBUG_VIEWMODE_NONE:
		case RENDERER_DEBUG_VIEWMODE_SSAO:
		case RENDERER_DEBUG_VIEWMODE_DENOISING_FACTOR:
			imageStore(img_normal_or_debug, COORDS, vec4(hitNormal, opacity));
			break;
		case RENDERER_DEBUG_VIEWMODE_NORMALS:
			// imageStore(img_normal_or_debug, COORDS, vec4(max(vec3(0), hitNormal), 1)); // World-space
			imageStore(img_normal_or_debug, COORDS, vec4(hitRenderableIndex != -1 ? normalize(WORLD2VIEWNORMAL * hitNormal) : vec3(0), 1)); // View-space
			break;
		case RENDERER_DEBUG_VIEWMODE_RAYGEN_TIME:
			WRITE_DEBUG_TIME
			// Fallthrough
		case RENDERER_DEBUG_VIEWMODE_RAYHIT_TIME:
		case RENDERER_DEBUG_VIEWMODE_RAYINT_TIME:
			imageStore(img_normal_or_debug, COORDS, vec4(HeatmapClamped(float(imageLoad(img_normal_or_debug, COORDS).a / (1000000 * xenonRendererData.config.debugViewScale))), 1));
			break;
		case RENDERER_DEBUG_VIEWMODE_MOTION:
			imageStore(img_normal_or_debug, COORDS, vec4(abs(motion * 1000 * xenonRendererData.config.debugViewScale), 1));
			break;
		case RENDERER_DEBUG_VIEWMODE_DISTANCE:
			imageStore(img_normal_or_debug, COORDS, vec4(HeatmapClamped(pow(hitDistance / 1000 * xenonRendererData.config.debugViewScale, 0.4)), 1));
			break;
		case RENDERER_DEBUG_VIEWMODE_ALPHA:
			imageStore(img_normal_or_debug, COORDS, vec4(HeatmapClamped(pow(imageLoad(img_resolved, COORDS).a, xenonRendererData.config.debugViewScale)), 1));
			break;
		case RENDERER_DEBUG_VIEWMODE_AIM_RENDERABLE:
			if (hitRenderableIndex != -1 && renderer.aim.tlasInstanceIndex == hitRenderableIndex) {
				imageStore(img_normal_or_debug, COORDS, vec4(1,0,1, 0.5));
			}
			break;
		// case RENDERER_DEBUG_VIEWMODE_AIM_GEOMETRY: 
		// 	if (renderer.aim.tlasInstanceIndex == ray.renderableIndex && renderer.aim.geometryIndex == ray.geometryIndex) {
		// 		imageStore(img_normal_or_debug, COORDS, vec4(1,0,1, 0.5));
		// 	}
		// 	break;
		// case RENDERER_DEBUG_VIEWMODE_AIM_PRIMITIVE:
		// 	if (renderer.aim.tlasInstanceIndex == ray.renderableIndex && renderer.aim.geometryIndex == ray.geometryIndex && renderer.aim.primitiveIndex == ray.primitiveIndex) {
		// 		imageStore(img_normal_or_debug, COORDS, vec4(1,0,1, 0.5));
		// 	}
		// 	break;
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
