// Di
#define NB_LIGHTS 16
#define SORT_LIGHTS

// bool GetBlueNoiseBool() {
// 	uint BLUE_NOISE_TEXTURES_OFFSET = renderer.bluenoise_unitvec1;
// 	uint noiseTexIndex = uint(xenonRendererData.frameIndex % BLUE_NOISE_NB_TEXTURES);
// 	vec2 texSize = vec2(textureSize(textures[nonuniformEXT(noiseTexIndex+BLUE_NOISE_TEXTURES_OFFSET)], 0).st);
// 	vec2 noiseTexCoord = (vec2(gl_LaunchIDEXT.x, gl_LaunchIDEXT.y) + 0.5) / texSize;
// 	return texture(textures[nonuniformEXT(noiseTexIndex+BLUE_NOISE_TEXTURES_OFFSET)], noiseTexCoord).r == 1;
// }

// float GetBlueNoiseFloat() {
// 	uint BLUE_NOISE_TEXTURES_OFFSET = renderer.bluenoise_scalar;
// 	uint noiseTexIndex = uint(xenonRendererData.frameIndex % BLUE_NOISE_NB_TEXTURES);
// 	vec2 texSize = vec2(textureSize(textures[nonuniformEXT(noiseTexIndex+BLUE_NOISE_TEXTURES_OFFSET)], 0).st);
// 	vec2 noiseTexCoord = (vec2(gl_LaunchIDEXT.x, gl_LaunchIDEXT.y) + 0.5) / texSize;
// 	return texture(textures[nonuniformEXT(noiseTexIndex+BLUE_NOISE_TEXTURES_OFFSET)], noiseTexCoord).r;
// }

// vec2 GetBlueNoiseFloat2() {
// 	uint BLUE_NOISE_TEXTURES_OFFSET = renderer.bluenoise_vec2;
// 	uint noiseTexIndex = uint(xenonRendererData.frameIndex % BLUE_NOISE_NB_TEXTURES);
// 	vec2 texSize = vec2(textureSize(textures[nonuniformEXT(noiseTexIndex+BLUE_NOISE_TEXTURES_OFFSET)], 0).st);
// 	vec2 noiseTexCoord = (vec2(gl_LaunchIDEXT.x, gl_LaunchIDEXT.y) + 0.5) / texSize;
// 	return texture(textures[nonuniformEXT(noiseTexIndex+BLUE_NOISE_TEXTURES_OFFSET)], noiseTexCoord).rg;
// }

// vec3 GetBlueNoiseUnitSphere() {
// 	uint BLUE_NOISE_TEXTURES_OFFSET = renderer.bluenoise_unitvec3;
// 	uint noiseTexIndex = uint(xenonRendererData.frameIndex % BLUE_NOISE_NB_TEXTURES);
// 	vec2 texSize = vec2(textureSize(textures[nonuniformEXT(noiseTexIndex+BLUE_NOISE_TEXTURES_OFFSET)], 0).st);
// 	vec2 noiseTexCoord = (vec2(gl_LaunchIDEXT.x, gl_LaunchIDEXT.y) + 0.5) / texSize;
// 	return texture(textures[nonuniformEXT(noiseTexIndex+BLUE_NOISE_TEXTURES_OFFSET)], noiseTexCoord).rgb * 2 - 1;
// }

// vec4 GetBlueNoiseUnitCosine() {
// 	uint BLUE_NOISE_TEXTURES_OFFSET = renderer.bluenoise_unitvec3_cosine;
// 	uint noiseTexIndex = uint(xenonRendererData.frameIndex % BLUE_NOISE_NB_TEXTURES);
// 	vec2 texSize = vec2(textureSize(textures[nonuniformEXT(noiseTexIndex+BLUE_NOISE_TEXTURES_OFFSET)], 0).st);
// 	vec2 noiseTexCoord = (vec2(gl_LaunchIDEXT.x, gl_LaunchIDEXT.y) + 0.5) / texSize;
// 	vec4 tex = texture(textures[nonuniformEXT(noiseTexIndex+BLUE_NOISE_TEXTURES_OFFSET)], noiseTexCoord);
// 	return vec4(tex.rgb * 2 - 1, tex.a);
// }

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

vec3 GetDirectLighting(in vec3 worldPosition, in vec3 normal, in vec3 albedo, in float fresnel) {
	vec3 position = worldPosition + normal * gl_HitTEXT * 0.001;
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
		float nDotL = dot(normal, lightDir);
		LightSourceInstanceData lightSource = renderer.lightSources[lightID].instance;
		float distanceToLightSurface = length(relativeLightPosition) - lightSource.innerRadius - gl_HitTEXT * EPSILON;
		if (distanceToLightSurface <= 0.001) {
			directLighting += lightSource.color * lightSource.power;
			ray.ssao = 0;
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
	
	RayPayload originalRay = ray;
	int usefulLights = 0;
	for (uint i = 0; i < nbLights; ++i) {
		vec3 shadowRayDir = lightsDir[i];
		bool isSunLight = lightsDistance[i] > 1e7;
		float shadowRayStart = 0;
		vec3 colorFilter = vec3(1);
		float opacity = 0;
		const float MAX_SHADOW_TRANSPARENCY_RAYS = 5;
		for (int j = 0; j < MAX_SHADOW_TRANSPARENCY_RAYS; ++j) {
			// // Soft Shadows
			// if ((xenonRendererData.config.options & RENDER_OPTION_GROUND_TRUTH) != 0) {
			// 	#ifdef USE_BLUE_NOISE
			// 		vec2 rnd = GetBlueNoiseFloat2();
			// 	#else
			// 		vec2 rnd = vec2(RandomFloat(seed), RandomFloat(seed));
			// 	#endif
			// 	float pointRadius = lightsRadius[i] / lightsDistance[i] * rnd.x;
			// 	float pointAngle = rnd.y * 2.0 * PI;
			// 	vec2 diskPoint = vec2(pointRadius * cos(pointAngle), pointRadius * sin(pointAngle));
			// 	vec3 lightTangent = normalize(cross(shadowRayDir, normal));
			// 	vec3 lightBitangent = normalize(cross(lightTangent, shadowRayDir));
			// 	shadowRayDir = normalize(shadowRayDir + diskPoint.x * lightTangent + diskPoint.y * lightBitangent);
			// }
			if (dot(shadowRayDir, normal) > 0) {
				vec3 rayDir = shadowRayDir;
				uint shadowTraceMask = RAYTRACE_MASK_TERRAIN|RAYTRACE_MASK_ENTITY|RAYTRACE_MASK_CLUTTER;
				if (rayIsUnderWater) {
					if (j == 0) {
						shadowTraceMask |= RAYTRACE_MASK_HYDROSPHERE;
					}
					// if (isSunLight) { // this causes issues with eclipes
					// 	float variation = Simplex(worldPosition + vec3(float(renderer.timestamp))) * 0.5 + 1.0;
					// 	rayDir = normalize(shadowRayDir + vec3(variation) * 0.01);
					// }
				}
				RAY_RECURSION_PUSH
					RAY_SHADOW_PUSH
						ray.color = vec4(0);
						traceRayEXT(tlas, gl_RayFlagsOpaqueEXT, shadowTraceMask, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, position, shadowRayStart, rayDir, lightsDistance[i] - EPSILON, 0);
					RAY_SHADOW_POP
				RAY_RECURSION_POP
				if (ray.hitDistance == -1) {
					// lit
					vec3 light = lightsColor[i] * lightsPower[i];
					vec3 diffuse = albedo * light * clamp(dot(normal, shadowRayDir), 0, 1) * (1 - surface.metallic) * mix(0.5, 1, surface.roughness);
					vec3 reflectDir = reflect(-shadowRayDir, normal);
					vec3 specular = light * pow(max(dot(-gl_WorldRayDirectionEXT, reflectDir), 0.0), mix(16, 4, surface.metallic)) * mix(vec3(1), albedo, surface.metallic);
					directLighting += colorFilter * (1 - clamp(opacity,0,1)) * mix(diffuse, (diffuse + specular) * 0.5, step(1, float(renderer.options & RENDERER_OPTION_SPECULAR_SURFACES)) * surface.specular);
					
					// if (++usefulLights == 2) {
					// 	ray = originalRay;
					// 	return directLighting;
					// }
					
					break;
					
				} else {
					if (ray.color.a == 1) {
						opacity = 1;
						break;
					}
					
					if (rayIsUnderWater) {
						float dist = min(lightsDistance[i], max(ray.t2, ray.hitDistance));
						ray.color.a = pow(clamp(dist - ray.hitDistance, 0, WATER_MAX_LIGHT_DEPTH) / WATER_MAX_LIGHT_DEPTH, 0.5);
						ray.color.rgb *= (1 - ray.color.a);
						if (isSunLight) {
							// its a sun light, make caustics
							vec3 lightIncomingDir = normalize(normalize(vec3(renderer.worldOrigin)) + shadowRayDir); // approximation of the refracted ray, good enough here
							opacity += 1 - clamp(caustics(worldPosition*vec3(0.9,0.5,0.7), lightIncomingDir, float(renderer.timestamp)) * 0.5 + 0.5, 0, 1);
						}
					}
					
					colorFilter *= ray.color.rgb;
					
					float transparency = 1.0 - min(1, opacity);
					transparency *= min(0.99, 1.0 - clamp(ray.color.a, 0, 1));
					opacity = 1.0 - transparency;
					
					shadowRayStart = max(ray.hitDistance, ray.t2) * 1.0001;
				}
				if (opacity > 0.99) break;
			}
		}
	}
	ray = originalRay;
	return directLighting;
}

#ifdef USE_BLUE_NOISE
	vec3 RandomCosineOnHemisphere(in vec3 normal) {
		vec3 tangentX = normalize(cross(normalize(vec3(0.356,1.2145,0.24537))/* fixed arbitrary vector in object space */, normal));
		vec3 tangentY = normalize(cross(normal, tangentX));
		mat3 TBN = mat3(tangentX, tangentY, normal);
		return normalize(TBN * GetBlueNoiseUnitCosine().rgb);
	}
	// vec3 RandomCosineOnHemisphere(in vec3 normal) {
	// 	return normalize(normal + GetBlueNoiseUnitSphere());
	// }
#else
	vec3 RandomCosineOnHemisphere(in vec3 normal) {
		return normalize(normal + RandomInUnitSphere(seed));
	}
#endif

void ApplyDefaultLighting() {
	bool rayIsShadow = RAY_IS_SHADOW;
	uint recursions = RAY_RECURSIONS;
	bool rayIsGi = RAY_IS_GI;
	bool rayIsUnderWater = RAY_IS_UNDERWATER;
	
	if (rayIsShadow) {
		ray.color = surface.color;
		return;
	}
	
	// Fresnel
	float fresnel = Fresnel((renderer.viewMatrix * vec4(ray.worldPosition, 1)).xyz, normalize(WORLD2VIEWNORMAL * ray.normal), surface.ior);
	
	vec3 albedo = surface.color.rgb;
	
	float realDistance = length(ray.worldPosition - inverse(renderer.viewMatrix)[3].xyz);
	
	// Direct Lighting
	vec3 directLighting = vec3(0);
	if ((renderer.options & RENDERER_OPTION_DIRECT_LIGHTING) != 0) {
		if (recursions < RAY_MAX_RECURSION && surface.metallic - surface.roughness < 1.0) {
			directLighting = GetDirectLighting(ray.worldPosition, ray.normal, albedo, fresnel);
		}
	}
	ray.color = vec4(mix(directLighting * renderer.globalLightingFactor, vec3(0), clamp(surface.metallic - surface.roughness, 0, 1)), 1);
	
	// Perfectly reflective metallic surface
	if (surface.metallic > 0.1 && surface.roughness < 0.1) {
		if (recursions < renderer.rays_max_bounces) {
			RayPayload originalRay = ray;
			vec3 rayOrigin = originalRay.worldPosition + originalRay.normal * max(2.0, originalRay.hitDistance) * EPSILON;
			vec3 reflectDirection = reflect(gl_WorldRayDirectionEXT, originalRay.normal);
			RAY_RECURSION_PUSH
				float transparency = 1;
				do {
					traceRayEXT(tlas, gl_RayFlagsCullBackFacingTrianglesEXT|gl_RayFlagsOpaqueEXT, RAYTRACE_MASK_TERRAIN|RAYTRACE_MASK_ENTITY|RAYTRACE_MASK_CLUTTER|RAYTRACE_MASK_ATMOSPHERE|RAYTRACE_MASK_HYDROSPHERE|RAYTRACE_MASK_PLASMA, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, rayOrigin, 0, reflectDirection, xenonRendererData.config.zFar, 0);
					ray.color.rgb *= transparency;
					rayOrigin += reflectDirection * ray.hitDistance - ray.normal * max(2.0, ray.hitDistance) * EPSILON;
					transparency *= 1.0 - clamp(ray.color.a, 0, 1);
				} while (transparency > 0.1 && ray.hitDistance > 0);
			RAY_RECURSION_POP
			originalRay.color.rgb += ray.color.rgb * albedo * min(surface.metallic, 0.9) + ray.plasma.rgb;
			ray = originalRay;
		}
	}
	
	// Ambient lighting
	else {
		vec3 ambient;
		if ((renderer.options & RENDERER_OPTION_RT_AMBIENT_LIGHTING) != 0) {
			ambient = vec3(pow(smoothstep(200/*max ambient distance*/, 0, realDistance), 4)) * 0.004;
			if (recursions <= 1) {
				float ambientFactor = 0.2;
				if (renderer.ambientOcclusionSamples > 0 && renderer.ambientOcclusionDistance > 0) {
					float avgHitDistance = 0;
					for (int i = 0; i < renderer.ambientOcclusionSamples; ++i) {
						rayQueryEXT rq;
						rayQueryInitializeEXT(rq, tlas, gl_RayFlagsOpaqueEXT, RAYTRACE_MASK_TERRAIN|RAYTRACE_MASK_ENTITY|RAYTRACE_MASK_CLUTTER, ray.worldPosition, ray.hitDistance * 0.001, normalize(ray.normal + RandomInUnitSphere(seed)), renderer.ambientOcclusionDistance);
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
						avgHitDistance += hitDistance>0? hitDistance : renderer.ambientOcclusionDistance;
					}
					ambientFactor = pow(clamp(avgHitDistance / renderer.ambientOcclusionDistance / renderer.ambientOcclusionSamples, 0, 1), 2);
				}
				uint fakeGiSeed = 598734;
				RayPayload originalRay = ray;
				RAY_RECURSION_PUSH
					RAY_GI_PUSH
					for (int i = 0; i < renderer.ambientAtmosphereSamples; ++i) {
						traceRayEXT(tlas, gl_RayFlagsOpaqueEXT, RAYTRACE_MASK_ATMOSPHERE, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, originalRay.worldPosition, 1.0, normalize(originalRay.normal + RandomInUnitSphere(fakeGiSeed)), 10000, 0);
						ambient += pow(ray.color.rgb, vec3(0.5)) / renderer.ambientAtmosphereSamples * ambientFactor;
					}
					RAY_GI_POP
				RAY_RECURSION_POP
				ray = originalRay;
			}
		} else {
			ambient = vec3(pow(smoothstep(200/*max ambient distance*/, 0, realDistance), 4)) * 0.1;
		}
		ray.color.rgb += albedo * ambient * 0.1;
	}
	
	// Emission
	ray.color.rgb += surface.emission * renderer.globalLightingFactor;
	if (dot(surface.emission,surface.emission) > 0) ray.ssao = 0;
	
	if (rayIsGi) return;
	
	// Debug Time
	if (xenonRendererData.config.debugViewMode == RENDERER_DEBUG_VIEWMODE_RAYHIT_TIME) {
		if (RAY_RECURSIONS == 0) WRITE_DEBUG_TIME
	}
}
