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

#define NB_LIGHTS 16
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

vec3 GetDirectLighting(in vec3 worldPosition, in vec3 rayDirection, in vec3 normal) {
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
			float effectiveLightIntensity = max(0, lightSource.power / (surfaceArea * distanceToLightSurface*distanceToLightSurface + 1) - LIGHT_LUMINOSITY_VISIBLE_THRESHOLD) * penombra * nDotL;
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
				if (dot(res[reservoirIndex].lightPos, res[reservoirIndex].lightPos) > dot(position, position)) {
					traceRayEXT(tlas, gl_RayFlagsNoOpaqueEXT | gl_RayFlagsSkipClosestHitShaderEXT, RAYTRACE_MASK_TERRAIN|RAYTRACE_MASK_ENTITY|RAYTRACE_MASK_CLUTTER|RAYTRACE_MASK_LIQUID, 0/*rayType*/, 0/*nbRayTypes*/, 1/*missIndex*/, position, 0, shadowRayDir, shadowRay.hitDistance, 1);
				} else {
					traceRayEXT(tlas, gl_RayFlagsNoOpaqueEXT | gl_RayFlagsSkipClosestHitShaderEXT, RAYTRACE_MASK_TERRAIN|RAYTRACE_MASK_ENTITY|RAYTRACE_MASK_CLUTTER|RAYTRACE_MASK_LIQUID, 0/*rayType*/, 0/*nbRayTypes*/, 1/*missIndex*/, res[reservoirIndex].lightPos, res[reservoirIndex].lightRadius, -shadowRayDir, shadowRay.hitDistance, 1);
				}
				// if (dot(res[reservoirIndex].lightPos, res[reservoirIndex].lightPos) > dot(position, position)) {
				// 	traceRayEXT(tlas, gl_RayFlagsNoOpaqueEXT | gl_RayFlagsSkipClosestHitShaderEXT | gl_RayFlagsTerminateOnFirstHitEXT | gl_RayFlagsCullBackFacingTrianglesEXT, RAYTRACE_MASK_TERRAIN, 0/*rayType*/, 0/*nbRayTypes*/, 1/*missIndex*/, position, 0, shadowRayDir, shadowRay.hitDistance, 1);
				// 	traceRayEXT(tlas, gl_RayFlagsNoOpaqueEXT | gl_RayFlagsSkipClosestHitShaderEXT, RAYTRACE_MASK_ENTITY|RAYTRACE_MASK_CLUTTER|RAYTRACE_MASK_LIQUID, 0/*rayType*/, 0/*nbRayTypes*/, 1/*missIndex*/, position, 0, shadowRayDir, shadowRay.hitDistance, 1);
				// } else {
				// 	traceRayEXT(tlas, gl_RayFlagsNoOpaqueEXT | gl_RayFlagsSkipClosestHitShaderEXT | gl_RayFlagsTerminateOnFirstHitEXT | gl_RayFlagsCullBackFacingTrianglesEXT, RAYTRACE_MASK_TERRAIN, 0/*rayType*/, 0/*nbRayTypes*/, 1/*missIndex*/, res[reservoirIndex].lightPos, res[reservoirIndex].lightRadius, -shadowRayDir, shadowRay.hitDistance, 1);
				// 	traceRayEXT(tlas, gl_RayFlagsNoOpaqueEXT | gl_RayFlagsSkipClosestHitShaderEXT, RAYTRACE_MASK_ENTITY|RAYTRACE_MASK_CLUTTER|RAYTRACE_MASK_LIQUID, 0/*rayType*/, 0/*nbRayTypes*/, 1/*missIndex*/, res[reservoirIndex].lightPos, res[reservoirIndex].lightRadius, -shadowRayDir, shadowRay.hitDistance, 1);
				// }
				directLighting += shadowRay.colorAttenuation * res[reservoirIndex].lightColor * res[reservoirIndex].totalLightJuice;
			}
		}
	}
	
	return directLighting;
}

vec3 TraceFogRay(in vec3 rayOrigin, in vec3 rayDirection, in float maxDistance, inout vec3 colorFilter) {
	shadowRay.colorAttenuation = vec3(1);
	shadowRay.emission = vec3(0);
	shadowRay.hitDistance = maxDistance;
	shadowRay.rayFlags = SHADOW_RAY_FLAG_EMISSION;
	++traceRayCount;
	traceRayEXT(tlas, gl_RayFlagsNoOpaqueEXT | gl_RayFlagsSkipClosestHitShaderEXT/*flags*/, RAYTRACE_MASK_LIQUID, 0/*rayType*/, 0/*nbRayTypes*/, 1/*missIndex*/, rayOrigin, EPSILON * 100, rayDirection, maxDistance, 1/*payloadIndex*/);
	++traceRayCount;
	traceRayEXT(tlas, gl_RayFlagsNoOpaqueEXT | gl_RayFlagsSkipClosestHitShaderEXT/*flags*/, RAYTRACE_MASK_FOG /*| RAYTRACE_MASK_VOLUME*/, 0/*rayType*/, 0/*nbRayTypes*/, 1/*missIndex*/, rayOrigin, EPSILON * 100, rayDirection, maxDistance, 1/*payloadIndex*/);
	vec3 color = shadowRay.emission * colorFilter;
	colorFilter *= shadowRay.colorAttenuation;
	return color;
}

vec3 EnvBRDFApprox2(vec3 SpecularColor, float alpha, float NoV) {
	NoV = abs(NoV);
	// [Ray Tracing Gems, Chapter 32]
	vec4 X;
	X.x = 1.f;
	X.y = NoV;
	X.z = NoV * NoV;
	X.w = NoV * X.z;
	vec4 Y;
	Y.x = 1.f;
	Y.y = alpha;
	Y.z = alpha * alpha;
	Y.w = alpha * Y.z;
	mat2 M1 = mat2(0.99044f, -1.28514f, 1.29678f, -0.755907f);
	mat3 M2 = mat3(1.f, 2.92338f, 59.4188f, 20.3225f, -27.0302f, 222.592f, 121.563f, 626.13f, 316.627f);
	mat2 M3 = mat2(0.0365463f, 3.32707, 9.0632f, -9.04756);
	mat3 M4 = mat3(1.f, 3.59685f, -1.36772f, 9.04401f, -16.3174f, 9.22949f, 5.56589f, 19.7886f, -20.2123f);
	float bias = dot(M1 * X.xy, Y.xy) / dot(M2 * X.xyw, Y.xyw);
	float scale = dot(M3 * X.xy, Y.xy) / dot(M4 * X.xzw, Y.xyw);
	// This is a hack for specular reflectance of 0
	bias *= clamp(SpecularColor.g * 50, 0, 1);
	return SpecularColor * max(0, scale) + max(0, bias);
}

double GetDepthBufferFromTrueDistance(double dist) {
	if (dist <= 0) return 1;
	return (((((2.0 * (xenonRendererData.config.zFar * xenonRendererData.config.zNear)) / dist) - xenonRendererData.config.zNear - xenonRendererData.config.zFar) / (xenonRendererData.config.zFar - xenonRendererData.config.zNear)) + 1) / 2.0;
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
	imageStore(img_dlss_particles_opacity, COORDS, vec4(0)); // this seems to not really matter at all
	
	// Clear motion vectors/depth
	vec4 ndc = vec4(uv * 2 - 1, 0, 1);
	vec4 ndc_history = renderer.reprojectionMatrix * ndc;
	ndc_history /= ndc_history.w;
	vec3 motion = ndc_history.xyz - ndc.xyz;
	imageStore(img_motion, COORDS, vec4(motion, 0));
	
	// Trace Rays
	if (xenonRendererData.config.debugViewMode > RENDERER_DEBUG_VIEWMODE_TEST) {
		ray.renderableIndex = -1;
		ray.surfaceFlags = uint8_t(0);
		ray.normal = vec3(0);
		traceRayEXT(tlas, gl_RayFlagsOpaqueEXT/*flags*/, RAYTRACE_MASK_SOLID|RAYTRACE_MASK_LIQUID, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, rayOrigin, xenonRendererData.config.zNear, rayDirection, xenonRendererData.config.zFar, 0/*payloadIndex*/);
		imageStore(img_normal_or_debug, COORDS, vec4(ray.normal, 1));
	} else {
		int maxBounces = 3;
		for (int i = 0; i < maxBounces; i++) {
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
			if (ray.renderableIndex == -1) {
				vec3 color = TraceFogRay(rayOrigin, rayDirection, xenonRendererData.config.zFar, colorFilter);
				imageStore(img_composite, COORDS, vec4(color, 0) + imageLoad(img_composite, COORDS));
				break;
			}
			
			// Write Depth
			if (i == 0) {
				vec4 clipSpace = mat4(xenonRendererData.config.projectionMatrix) * mat4(renderer.viewMatrix) * vec4(rayOrigin + rayDirection * ray.hitDistance, 1);
				float depth = clamp(clipSpace.z / clipSpace.w, 0, 1);
				imageStore(img_depth, COORDS, vec4(depth));
			}
		
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
				}
			}
			
			// We have hit a solid surface
			float ior = float(ray.ior) / 51;
			float roughness = float(ray.roughness) / 255;
			vec3 hitWorldPosition = rayOrigin + rayDirection * ray.hitDistance;
			vec3 hitLocalPosition = ray.localPosition;
			vec3 rayNormal = ray.normal;
			vec3 reflectionDir = normalize(reflect(rayDirection, rayNormal));
			vec3 refractionDir = refract(rayDirection, rayNormal, currentIOR/ior);
			vec3 rayColor = ray.color * colorFilter;
			uint8_t raySurfaceFlags = ray.surfaceFlags;
			float rayHitDistance = ray.hitDistance;
			bool isTransparent = (raySurfaceFlags & RAY_SURFACE_TRANSPARENT) != 0;
			bool isMetallic = (ray.surfaceFlags & RAY_SURFACE_METALLIC) != 0;
			bool isEmissive = (raySurfaceFlags & RAY_SURFACE_EMISSIVE) != 0;
			bool isLiquid = (ray.rayFlags & RAY_FLAG_FLUID) != 0;
			
			// Write G-Buffers
			if (i == 0) {
				imageStore(img_normal_or_debug, COORDS, vec4(ray.normal, roughness));
				imageStore(img_diffuse_albedo, COORDS, vec4(ray.color, 0));
				if (!isEmissive) {
					vec3 specularAlbedo = EnvBRDFApprox2(ray.color * float(isMetallic || isLiquid), roughness*roughness, dot(rayDirection, rayNormal));
					imageStore(img_specular_albedo, COORDS, vec4(specularAlbedo, 0));
				}
				if (isLiquid) {
					float depth = float(GetDepthBufferFromTrueDistance(ray.hitDistance));
				} else {
					// Write Motion Vectors
					mat4 mvp = xenonRendererData.config.projectionMatrix * renderer.viewMatrix * mat4(transpose(renderer.tlasInstances[ray.renderableIndex].transform));
					renderer.mvpBuffer[ray.renderableIndex].mvp = mvp;
					renderer.realtimeBuffer[ray.renderableIndex].mvpFrameIndex = xenonRendererData.frameIndex;
					vec4 ndc = mvp * vec4(hitLocalPosition, 1);
					ndc /= ndc.w;
					mat4 mvpHistory;
					if (renderer.realtimeBufferHistory[ray.renderableIndex].mvpFrameIndex == xenonRendererData.frameIndex - 1) {
						mvpHistory = renderer.mvpBufferHistory[ray.renderableIndex].mvp;
					} else {
						mvpHistory = renderer.reprojectionMatrix * mvp;
					}
					vec4 ndc_history = mvpHistory * vec4(hitLocalPosition, 1);
					ndc_history /= ndc_history.w;
					vec3 motion = ndc_history.xyz - ndc.xyz;
					imageStore(img_motion, COORDS, vec4(motion, rayHitDistance));
				}
				ray.rayFlags &= ~RAY_FLAG_AIM;
			}
			
			vec3 directLighting = vec3(0);
			vec3 fogEmission = TraceFogRay(rayOrigin, rayDirection, rayHitDistance, colorFilter);
			vec3 emission = rayColor * float(isEmissive) * colorFilter;
			
			if (isMetallic) {
				if (roughness > 0) {
					if (dot(reflectionDir, rayNormal) < 0) {
						reflectionDir = rayNormal;
					}
					vec3 tangent = normalize(cross(rayNormal, reflectionDir));
					vec3 bitangent = normalize(cross(tangent, reflectionDir));
					do {
						rayDirection = reflectionDir * 0.5 + (RandomFloat(seed) - 0.5) * tangent * roughness + (RandomFloat(seed) - 0.5) * bitangent * roughness;
					} while (dot(rayDirection, rayNormal) < 0);
					rayDirection = normalize(rayDirection);
				} else {
					rayDirection = reflectionDir;
				}
				colorFilter *= rayColor;
			} else {
				// float fresnel = pow(1 - max(0, dot(-rayDirection, rayNormal)), 2);
				float fresnel = Fresnel(rayDirection, rayNormal, ior);
				if (isTransparent) {
					// float alpha = max(rayColor.r, max(rayColor.g, rayColor.b));
					// directLighting += GetDirectLighting(hitWorldPosition, rayDirection, rayNormal) * pow(1 - alpha, 2);
					if (dot(refractionDir,refractionDir) == 0) refractionDir = reflectionDir;
					if (isLiquid && ior > 1) {
						rayDirection = roughness == 0 && RandomFloat(seed) > dot(-rayDirection, rayNormal) ? reflectionDir : refractionDir;
						// rayDirection = reflectionDir;
						// rayDirection = refractionDir;
					} else {
						rayDirection = refractionDir;
						colorFilter *= rayColor;
					}
					currentIOR = ior;
					maxBounces = min(maxBounces + 1, 16);
				} else {
					directLighting += GetDirectLighting(hitWorldPosition, rayDirection, rayNormal) * colorFilter;
					rayDirection = roughness == 0 && RandomFloat(seed) < fresnel ? reflectionDir : normalize(RandomInUnitHemiSphere(seed, rayNormal));
					colorFilter *= rayColor;
				}
			}
			imageStore(img_composite, COORDS, vec4(rayColor * directLighting + emission + fogEmission + imageLoad(img_composite, COORDS).rgb, 1));
			
			rayOrigin = hitWorldPosition + rayNormal * sign(dot(rayNormal, rayDirection)) * EPSILON;
			if (isEmissive) colorFilter *= 0.5;
		}
		if (renderer.globalLightingFactor < 1) {
			vec4 composite = imageLoad(img_composite, COORDS);
			imageStore(img_composite, COORDS, vec4(composite.rgb * renderer.globalLightingFactor*renderer.globalLightingFactor, mix(1, composite.a, renderer.globalLightingFactor)));
		}
	}
	
	// Trace environment audio
	const int MAX_AUDIO_BOUNCE = 1;
	const uvec2 environment_audio_trace_size = uvec2(200, 200);
	vec4 audioDebugColor = vec4(0);
	if (gl_LaunchIDEXT.x < environment_audio_trace_size.x && gl_LaunchIDEXT.y < environment_audio_trace_size.y && xenonRendererData.config.debugViewMode <= RENDERER_DEBUG_VIEWMODE_TEST) {
		audioDebugColor.a = 1;
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
				audioDebugColor.rgb = vec3(0);
				atomicAdd(renderer.environmentAudio.miss, 1);
				break;
			} else {
				uint hitMask = renderer.tlasInstances[ray.renderableIndex].instanceCustomIndex_and_mask >> 24;
				if (hitMask == RAYTRACE_MASK_TERRAIN) {
					atomicAdd(renderer.environmentAudio.terrain, 1);
					audioDebugColor.rgb = mix(audioDebugColor.rgb, vec3(1,0,0), audible);
					break;
				}
				else if (hitMask == RAYTRACE_MASK_ENTITY) {
					renderer.environmentAudio.audibleRenderables[ray.renderableIndex].audible = max(renderer.environmentAudio.audibleRenderables[ray.renderableIndex].audible, audible);
					atomicAdd(renderer.environmentAudio.object, 1);
					audioDebugColor.rgb = mix(audioDebugColor.rgb, vec3(0,1,0), audible);
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
					audioDebugColor.rgb = mix(audioDebugColor.rgb, vec3(0,0,1), audible);
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
			imageStore(img_normal_or_debug, COORDS, audioDebugColor);
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
