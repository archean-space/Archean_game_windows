#define SHADER_RCHIT
#define SHADER_WATER
#include "common.inc.glsl"
#include "xenon/renderer/shaders/perlint.inc.glsl"

#include "lighting.inc.glsl"

#define WATER_IOR 1.33
#define WATER_OPACITY 0.1
#define WATER_TINT vec3(0.4,0.7,0.8)

hitAttributeEXT hit {
	float t1;
	float t2;
};

void SetHitWater() {
	ray.renderableIndex = gl_InstanceID;
	ray.geometryIndex = gl_GeometryIndexEXT;
	ray.primitiveIndex = gl_PrimitiveID;
	ray.color.a = 1;
}

#define RAIN_DROP_HASHSCALE1 .1031
#define RAIN_DROP_HASHSCALE3 vec3(.1031, .1030, .0973)
#define RAIN_DROP_MAX_RADIUS 2
float hash12(vec2 p) {
	vec3 p3  = fract(vec3(p.xyx) * RAIN_DROP_HASHSCALE1);
	p3 += dot(p3, p3.yzx + 19.19);
	return fract((p3.x + p3.y) * p3.z);
}
vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * RAIN_DROP_HASHSCALE3);
	p3 += dot(p3, p3.yzx+19.19);
	return fract((p3.xx+p3.yz)*p3.zy);
}
float RainDrops(vec3 pos) {
	float t = float(renderer.timestamp);
	vec2 uv = pos.xy;
	vec2 p0 = floor(uv);
	vec2 circles = vec2(0.);
	for (int j = -RAIN_DROP_MAX_RADIUS; j <= RAIN_DROP_MAX_RADIUS; ++j) {
		for (int i = -RAIN_DROP_MAX_RADIUS; i <= RAIN_DROP_MAX_RADIUS; ++i) {
			vec2 pi = p0 + vec2(i, j);
			vec2 hsh = pi;
			vec2 p = pi + hash22(hsh);
			float t = fract(0.3*t + hash12(hsh));
			vec2 v = p - uv;
			float d = length(v) - (float(RAIN_DROP_MAX_RADIUS) + 1.)*t;
			float h = 1e-3;
			float d1 = d - h;
			float d2 = d + h;
			float p1 = sin(31.*d1) * smoothstep(-0.6, -0.3, d1) * smoothstep(0., -0.3, d1);
			float p2 = sin(31.*d2) * smoothstep(-0.6, -0.3, d2) * smoothstep(0., -0.3, d2);
			circles += 0.5 * normalize(v) * ((p2 - p1) / (2. * h) * (1. - t) * (1. - t));
		}
	}
	circles /= float((RAIN_DROP_MAX_RADIUS*2+1)*(RAIN_DROP_MAX_RADIUS*2+1));
	return dot(circles, circles);
}

const float smallWavesMaxDistance = 20;
const float mediumWavesMaxDistance = 100;
const float bigWavesMaxDistance = 500;
const float giantWavesMaxDistance = 10000;

float smallWavesStrength = smoothstep(smallWavesMaxDistance, 0, gl_HitTEXT);
float mediumWavesStrength = smoothstep(mediumWavesMaxDistance, 0, gl_HitTEXT) * (1-smallWavesStrength);
float bigWavesStrength = smoothstep(bigWavesMaxDistance, smallWavesMaxDistance, gl_HitTEXT) * (1-mediumWavesStrength);
float giantWavesStrength = smoothstep(giantWavesMaxDistance, bigWavesMaxDistance, gl_HitTEXT) * (1-bigWavesStrength);

float SeaNoise(vec3 pos, float choppy) {
	pos += Simplex(pos);
	vec3 wv = 1.0-abs(sin(pos));
	vec3 swv = abs(cos(pos));
	wv = mix(wv,swv,wv);
	return pow(1.0-pow(wv.x * wv.y,0.65), choppy);
}
float WaterMap(vec3 p, float freq) {
	float amp = 2.0;
	float choppy = 2.0;
	float d, h = 0;
	for(int i = 0; i < 3; i++) {
		d = SeaNoise((p+(1.0 + float(xenonRendererData.time)))*freq,choppy);
		d += SeaNoise((p-(1.0 + float(xenonRendererData.time)))*freq,choppy);
		h += d * amp;
		p *= 1.6;
		freq *= 1.9;
		amp *= 0.22;
		choppy = mix(choppy,1.0,0.2);
	}
	return h;
}
float WaterWaves(vec3 pos) {
	return 0
		// + smallWavesStrength * RainDrops(pos)*4
		+ smallWavesStrength * SimplexFractal(pos*4 + float(renderer.timestamp - pos.z), 3) * 0.2
		+ mediumWavesStrength * SimplexFractal(pos*vec3(0.5, 0.8, 0.5) + float(renderer.timestamp - pos.z)*0.5, 3)
		+ bigWavesStrength * Simplex(pos*vec3(0.02, 0.06, 0.03) + float(renderer.timestamp - pos.z)*0.2) * 5
		+ mediumWavesStrength * WaterMap(pos, 0.1) * 2
		+ bigWavesStrength * WaterMap(pos, 0.03) * 4
		+ giantWavesStrength * WaterMap(pos, 0.01) * 8
	;
}

void main() {
	uint recursions = RAY_RECURSIONS;
	ray.t2 = 0;
	ray.ior = WATER_IOR;
	ray.hitDistance = gl_HitTEXT;
	ray.normal = vec3(0,1,0);
	ray.color = vec4(vec3(0), 1);
	ray.renderableIndex = -1;
	
	if (recursions >= RAY_MAX_RECURSION) {
		return;
	}
	
	WaterData water = WaterData(AABB.data);
	if (uint64_t(water) == 0) return;
	
	bool rayIsGi = RAY_IS_GI;
	bool rayIsShadow = RAY_IS_SHADOW;
	bool rayIsUnderwater = RAY_IS_UNDERWATER;
	vec3 worldPosition = gl_WorldRayOriginEXT + gl_WorldRayDirectionEXT * gl_HitTEXT;
	
	if (rayIsShadow) {
		// Underwater shadow
		ray.hitDistance = gl_HitTEXT;
		ray.t2 = t2;
		ray.normal = vec3(0);
		SetHitWater();
		ray.color = vec4(vec3(1), 0);
		if (gl_HitKindEXT != 0) {
			// Underwater
			
			// Trace other things inside water
			vec3 rayPosition = gl_WorldRayOriginEXT;
			vec3 rayDirection = gl_WorldRayDirectionEXT;
			RayPayload originalRay = ray;
			RAY_RECURSION_PUSH
				traceRayEXT(tlas, gl_RayFlagsOpaqueEXT, RAYTRACE_MASK_SOLID, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, rayPosition, gl_RayTminEXT, rayDirection, t2, 0);
			RAY_RECURSION_POP
			if (ray.hitDistance > 0) {
				originalRay.color.rgb *= ray.color.rgb;
				originalRay.color.a = min(1, originalRay.color.a + ray.color.a);
				if (ray.color.a > 0.5) {
					originalRay.t2 = min(ray.hitDistance * 0.99, originalRay.t2);
				}
			}
			ray = originalRay;
		}
		return;
	}
	
	uint rayMask = RAYTRACE_MASK_SOLID|RAYTRACE_MASK_ATMOSPHERE;
	if (rayIsGi && rayIsUnderwater) {
		rayMask &= ~RAYTRACE_MASK_CLUTTER;
	}
	
	// Compute normal
	vec3 surfaceNormal; // in world space
	const vec3 spherePosition = vec3(water.center);// (AABB_MAX + AABB_MIN) / 2;
	const vec3 hitPoint1 = gl_WorldRayOriginEXT + gl_WorldRayDirectionEXT * t1;
	const vec3 hitPoint2 = gl_WorldRayOriginEXT + gl_WorldRayDirectionEXT * t2;
	if (gl_HitKindEXT == 0) {
		// Outside of sphere
		surfaceNormal = normalize(hitPoint1 - spherePosition);
	} else if (gl_HitKindEXT == 1) {
		// Inside of sphere
		surfaceNormal = normalize(spherePosition - hitPoint2);
	}
	
	float waterWavesStrength = pow(0.5/*water.wavesStrength*/, 2);

	vec3 downDir = normalize(spherePosition);
	float dotUp = dot(gl_WorldRayDirectionEXT, -downDir);
	
	// Aim
	uint monitorIndex = renderer.aim.monitorIndex;
	uint aimID = renderer.aim.aimID;
	
	if (gl_HitKindEXT == 0) {
		// Above water
		
		vec3 reflection = vec3(0);
		vec3 refraction = vec3(0);
		vec3 lighting = vec3(0);
		
		bool waterWavesVisible = (renderer.options & RENDERER_OPTION_WATER_WAVES) != 0 && waterWavesStrength > 0 && gl_HitTEXT < giantWavesMaxDistance;
		if (waterWavesVisible) {
			vec3 wavesPosition = hitPoint1;
			APPLY_NORMAL_BUMP_NOISE(WaterWaves, wavesPosition, surfaceNormal, waterWavesStrength * 0.05)
		}
		float fresnel = Fresnel(normalize((renderer.viewMatrix * vec4(worldPosition, 1)).xyz), normalize(WORLD2VIEWNORMAL * surfaceNormal), WATER_IOR);
		
		// Reflection on top of water surface
		vec3 reflectDir = normalize(reflect(gl_WorldRayDirectionEXT, surfaceNormal));
		vec3 upDir = -normalize(spherePosition);
		while (waterWavesVisible && dot(reflectDir, upDir) < 0.001) {
			reflectDir = normalize(upDir * 0.01 + reflectDir);
		}
		uint reflectionMask = ((renderer.options & RENDERER_OPTION_WATER_REFLECTIONS) != 0)? rayMask : RAYTRACE_MASK_ATMOSPHERE;
		RAY_RECURSION_PUSH
			for (int RAYLOOP = 0; RAYLOOP < 10; ++RAYLOOP) {
				traceRayEXT(tlas, gl_RayFlagsOpaqueEXT, reflectionMask, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, worldPosition, 0, reflectDir, 100000, 0);
				if (ray.hitDistance == -1 || ray.color.a > 0.5) {
					ray.color.a = 1;
					break;
				}
				worldPosition += reflectDir * (ray.hitDistance + 0.01);
			}
		RAY_RECURSION_POP
		// Restore Aim
		if (COORDS == ivec2(gl_LaunchSizeEXT.xy) / 2) {
			renderer.aim.monitorIndex = monitorIndex;
			renderer.aim.aimID = aimID;
			if (aimID == 0) {
				renderer.aim.hitDistance = distance(vec3(inverse(renderer.viewMatrix)[3]), hitPoint1);
			}
		}
		reflection = ray.color.rgb + ray.emission.rgb;
		
		lighting = GetDirectLighting(hitPoint1, gl_WorldRayDirectionEXT, surfaceNormal, vec3(WATER_OPACITY*WATER_OPACITY), t1, 0, 0, 1) * 0.5;
		
		// See through water (refraction)
		vec3 rayDirection = gl_WorldRayDirectionEXT;
		if ((renderer.options & RENDERER_OPTION_WATER_TRANSPARENCY) != 0) {
			if ((renderer.options & RENDERER_OPTION_WATER_REFRACTION) == 0 || -dotUp < 0.04 || Refract(rayDirection, surfaceNormal, WATER_IOR)) {
				RAY_RECURSION_PUSH
					RAY_UNDERWATER_PUSH
						ray.color = vec4(0);
						for (int RAYLOOP = 0; RAYLOOP < 10; ++RAYLOOP) {
							traceRayEXT(tlas, gl_RayFlagsOpaqueEXT, rayMask & ~RAYTRACE_MASK_ATMOSPHERE, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, worldPosition, xenonRendererData.config.zNear, rayDirection, WATER_MAX_LIGHT_DEPTH, 0);
							if (ray.hitDistance == -1 || ray.color.a > 0.5) {
								ray.color.a = 1;
								break;
							}
							worldPosition += rayDirection * (ray.hitDistance + 0.01);
						}
					RAY_UNDERWATER_POP
				RAY_RECURSION_POP
				if (ray.hitDistance == -1) {
					ray.hitDistance = WATER_MAX_LIGHT_DEPTH;
					ray.color = vec4(0);
				}
				refraction = ray.color.rgb * (1-clamp(ray.hitDistance / WATER_MAX_LIGHT_DEPTH, 0, 1));
			}
		}
		
		if (ray.hitDistance == -1 || rayIsShadow) {
			SetHitWater();
		}
		ray.hitDistance = gl_HitTEXT;
		ray.t2 = WATER_MAX_LIGHT_DEPTH;
		ray.color.rgb = reflection * fresnel * 0.5 + refraction * (1-fresnel) + lighting;
		ray.color.a = 1;
		ray.emission.rgb = vec3(0);
		ray.normal = surfaceNormal;
		
		// if (gl_HitTEXT < giantWavesMaxDistance) {
		// 	vec3 worldPositionGiantWaves = vec3(-renderer.worldOrigin) + gl_WorldRayOriginEXT + gl_WorldRayDirectionEXT * gl_HitTEXT;
		// 	ray.color.rgb += length(ray.color.rgb) * 0.033 * vec3(GiantWaterWaves(worldPositionGiantWaves)) * giantWavesStrength * 4;
		// }
		
	} else {
		// Underwater
		float maxLightDepth = mix(WATER_MAX_LIGHT_DEPTH, WATER_MAX_LIGHT_DEPTH_VERTICAL, max(0, dotUp));
		float depth = float(water.radius - length(dvec3(gl_WorldRayOriginEXT) - water.center));
		float depthFalloff = pow(1.0 - clamp(depth / WATER_MAX_LIGHT_DEPTH_VERTICAL, 0, 1), 2);
		vec3 colorFilter = vec3(1);
		
		RAY_UNDERWATER_PUSH
		
		if (dotUp > 0) {
			// Looking up towards surface

			waterWavesStrength *= depthFalloff*depthFalloff;
			float distanceToSurface = t2;
			vec3 wavePosition = gl_WorldRayOriginEXT + gl_WorldRayDirectionEXT * distanceToSurface;
			surfaceNormal = downDir;
			if ((renderer.options & RENDERER_OPTION_WATER_WAVES) != 0 && waterWavesStrength > 0.01) {
				APPLY_NORMAL_BUMP_NOISE(WaterWaves, wavePosition, surfaceNormal, waterWavesStrength * 0.05)
			}
			
			// See through water (underwater looking up, possibly at surface)
			vec3 rayPosition = gl_WorldRayOriginEXT;
			vec3 rayDirection = gl_WorldRayDirectionEXT;
			RAY_RECURSION_PUSH
				ray.color = vec4(0);
				for (int RAYLOOP = 0; RAYLOOP < 10; ++RAYLOOP) {
					traceRayEXT(tlas, gl_RayFlagsOpaqueEXT, rayMask, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, rayPosition, gl_RayTminEXT, rayDirection, distanceToSurface, 0);
					if (ray.hitDistance == -1 || ray.color.a > 0.5) {
						ray.color.a = 1;
						break;
					}
					colorFilter *= ray.color.rgb;
					colorFilter *= 1 - ray.color.a;
					rayPosition += rayDirection * (ray.hitDistance + 0.01);
				}
			RAY_RECURSION_POP
			
			if (ray.hitDistance == -1) {
				// Surface refraction seen from underwater
				rayPosition += rayDirection * distanceToSurface;
				float maxRayDistance = xenonRendererData.config.zFar;
				if ((renderer.options & RENDERER_OPTION_WATER_TRANSPARENCY) != 0) {
					bool shouldRestoreAim = false;
					if (!Refract(rayDirection, surfaceNormal, 1.0 / WATER_IOR)) {
						maxRayDistance = maxLightDepth;
						shouldRestoreAim = true;
					}
					RAY_RECURSION_PUSH
						ray.color = vec4(0);
						for (int RAYLOOP = 0; RAYLOOP < 10; ++RAYLOOP) {
							traceRayEXT(tlas, gl_RayFlagsOpaqueEXT, rayMask, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, rayPosition, gl_RayTminEXT, rayDirection, maxRayDistance, 0);
							if (ray.hitDistance == -1 || ray.color.a > 0.5) {
								ray.color.a = 1;
								break;
							}
							rayPosition += rayDirection * (ray.hitDistance + 0.01);
						}
					RAY_RECURSION_POP
					// Restore Aim
					if (COORDS == ivec2(gl_LaunchSizeEXT.xy) / 2) {
						if (shouldRestoreAim) {
							renderer.aim.monitorIndex = monitorIndex;
							renderer.aim.aimID = aimID;
						}
						if (aimID == 0) {
							renderer.aim.hitDistance = distance(vec3(inverse(renderer.viewMatrix)[3]), hitPoint2);
						}
					}
				}
				if (maxRayDistance == maxLightDepth) {
					if (ray.hitDistance == -1) {
						ray.hitDistance = maxLightDepth;
					}
					ray.color.rgb *= pow(1.0 - clamp(ray.hitDistance / maxLightDepth, 0, 1), 2);
					ray.emission.rgb *= pow(1.0 - clamp(ray.hitDistance / maxLightDepth, 0, 1), 2);
				}
				ray.hitDistance = distanceToSurface;
				ray.t2 = max(distanceToSurface, maxRayDistance);
				ray.normal = vec3(0,-1,0);
				SetHitWater();
				ray.renderableIndex = -1;
			}
			float falloff = pow(1.0 - clamp(ray.hitDistance / maxLightDepth, 0, 1), 2);
			// ray.color.rgb *= WATER_TINT;
			ray.color.rgb *= falloff;
			// ray.emission.rgb *= WATER_TINT;
			ray.emission.rgb *= falloff;
			
		} else {
			// See through water (underwater looking down)
			
			vec3 rayPosition = gl_WorldRayOriginEXT;
			vec3 rayDirection = gl_WorldRayDirectionEXT;
			RAY_RECURSION_PUSH
				ray.color = vec4(0);
				for (int RAYLOOP = 0; RAYLOOP < 10; ++RAYLOOP) {
					traceRayEXT(tlas, gl_RayFlagsOpaqueEXT, rayMask, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, rayPosition, gl_RayTminEXT, rayDirection, WATER_MAX_LIGHT_DEPTH_VERTICAL, 0);
					if (ray.hitDistance == -1 || ray.color.a > 0.5) {
						ray.color.a = 1;
						break;
					}
					colorFilter *= ray.color.rgb;
					colorFilter *= 1 - ray.color.a;
					rayPosition += rayDirection * (ray.hitDistance + 0.01);
				}
			RAY_RECURSION_POP
			if (ray.hitDistance == -1) {
				ray.hitDistance = maxLightDepth;
				ray.t2 = maxLightDepth;
				ray.color = vec4(0,0,0,1);
				ray.normal = vec3(0);
				SetHitWater();
			} else {
				float falloff = pow(1.0 - clamp(ray.hitDistance / maxLightDepth, 0, 1), 2);
				// ray.color.rgb *= WATER_TINT;
				ray.color.rgb *= falloff;
				// ray.emission.rgb *= WATER_TINT;
				ray.emission.rgb *= falloff;
			}
			
		}
		
		// Fog
		const vec3 origin = gl_WorldRayOriginEXT;
		const vec3 dir = gl_WorldRayDirectionEXT;
		const float distFactor = clamp(ray.hitDistance / maxLightDepth, 0 ,1);
		const float fogStrength = max(WATER_OPACITY, pow(distFactor, 0.25));
		vec3 waterLighting = vec3(0);
		if (recursions < RAY_MAX_RECURSION) {
			RayPayload originalRay = ray;
			RAY_RECURSION_PUSH
				RAY_GI_PUSH
					traceRayEXT(tlas, gl_RayFlagsOpaqueEXT, RAYTRACE_MASK_ATMOSPHERE, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, worldPosition, 0, -downDir, 10000, 0);
				RAY_GI_POP
			RAY_RECURSION_POP
			waterLighting = ray.emission.rgb * WATER_OPACITY * depthFalloff;
			ray = originalRay;
		}
		ray.color.rgb = WATER_TINT * mix(ray.color.rgb, waterLighting, pow(clamp(ray.hitDistance / maxLightDepth, 0, 1), 0.5));
		ray.emission.rgb *= colorFilter;
		ray.color.rgb *= colorFilter;
	}
	
	ray.ior = WATER_IOR;
	
	// Debug Time
	if (xenonRendererData.config.debugViewMode == RENDERER_DEBUG_VIEWMODE_RAYHIT_TIME) {
		if (recursions == 0) WRITE_DEBUG_TIME
	}
}

