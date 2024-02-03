#define SHADER_RCHIT
#include "hydrosphere.common.inc.glsl"
#include "xenon/renderer/shaders/perlint.inc.glsl"

#define WATER_IOR 1.33
#define WATER_OPACITY 0.3
#define WATER_TINT vec3(0.4,0.7,0.8)

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

const float smallWavesMaxDistance = 10;
const float mediumWavesMaxDistance = 100;
const float bigWavesMaxDistance = 500;
const float giantWavesMaxDistance = 100000;

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
		+ smallWavesStrength * Simplex(pos*5 + float(renderer.timestamp - pos.z)*2) * 0.1
		+ mediumWavesStrength * Simplex(pos*vec3(0.5, 0.8, 0.5) + float(renderer.timestamp - pos.z)*0.5)
		+ bigWavesStrength * Simplex(pos*vec3(0.02, 0.06, 0.03) + float(renderer.timestamp - pos.z)*0.2) * 5
		+ mediumWavesStrength * WaterMap(pos, 0.1) * 2
		+ bigWavesStrength * WaterMap(pos, 0.03) * 4
		+ giantWavesStrength * WaterMap(pos, 0.01) * 8
	;
}

void main() {
	
	ray.albedo = vec3(0);
	ray.t1 = gl_HitTEXT;
	ray.normal = vec3(0);
	ray.emission = vec3(0);
	ray.transmittance = vec3(0);
	ray.ior = 0;
	ray.reflectance = 0;
	ray.metallic = 0;
	ray.roughness = 0;
	ray.specular = 0;
	ray.localPosition = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * gl_HitTEXT;
	ray.renderableIndex = gl_InstanceID;
	
	float T1;
	float T2;
	bool inside;
	if (!HydrosphereIntersection(T1, T2, inside)) return;
	
	vec3 worldPosition = gl_WorldRayOriginEXT + gl_WorldRayDirectionEXT * gl_HitTEXT;
	
	if (RAY_IS_SHADOW) {
		// Underwater shadow
		ray.t1 = gl_HitTEXT;
		float lightDistance = ray.t2;
		ray.t2 = T2;
		ray.normal = vec3(0);
		if (inside) {
			ray.mask |= RAYTRACE_MASK_HYDROSPHERE;
			ray.transmittance = vec3(1) - pow(clamp(min(lightDistance, T2) / WATER_MAX_LIGHT_DEPTH, 0, 1), 0.25);
		}
		return;
	}
	
	uint rayMask = RAYTRACE_MASK_TERRAIN|RAYTRACE_MASK_ENTITY|RAYTRACE_MASK_CLUTTER;
	
	// Compute normal
	vec3 surfaceNormal; // in world space
	const vec3 spherePosition = vec3(water.center);// (AABB_MAX + AABB_MIN) / 2;
	const vec3 hitPoint1 = gl_WorldRayOriginEXT + gl_WorldRayDirectionEXT * T1;
	const vec3 hitPoint2 = gl_WorldRayOriginEXT + gl_WorldRayDirectionEXT * T2;
	if (inside) {
		// Inside of sphere
		surfaceNormal = normalize(spherePosition - hitPoint2);
	} else {
		// Outside of sphere
		surfaceNormal = normalize(hitPoint1 - spherePosition);
	}
	
	const float waterWavesStrength = pow(0.5/*water.wavesStrength*/, 2);

	vec3 downDir = normalize(spherePosition);
	float dotUp = dot(gl_WorldRayDirectionEXT, -downDir);
	
	if (!inside) {
		// Above water
		
		if ((renderer.options & RENDERER_OPTION_WATER_WAVES) != 0 && waterWavesStrength > 0 && gl_HitTEXT < giantWavesMaxDistance) {
			vec3 wavesPosition = hitPoint1;
			APPLY_NORMAL_BUMP_NOISE(WaterWaves, wavesPosition, surfaceNormal, waterWavesStrength * 0.05)
			for (int FIX = 0; FIX < 10; ++FIX) {
				if (dot(reflect(gl_WorldRayDirectionEXT, surfaceNormal), -downDir) > 0.001) break;
				surfaceNormal = normalize(surfaceNormal - downDir);
			}
		}
		
		ray.t2 = WATER_MAX_LIGHT_DEPTH;
		ray.normal = surfaceNormal;
		ray.transmittance = WATER_TINT;
		ray.ior = WATER_IOR;
		ray.reflectance = 1;
		ray.metallic = 0;
		ray.roughness = 0;
		ray.specular = 0;
		ray.mask |= RAYTRACE_MASK_HYDROSPHERE;
		ray.renderableIndex = -1;
		
	} else {
	// 	// Underwater
		float maxLightDepth = mix(WATER_MAX_LIGHT_DEPTH, WATER_MAX_LIGHT_DEPTH_VERTICAL, max(0, dotUp));
		
		vec3 transmittance = WATER_TINT;
		
		if (dotUp > 0) {
			// Looking up towards surface

			float distanceToSurface = T2;
			vec3 wavePosition = gl_WorldRayOriginEXT + gl_WorldRayDirectionEXT * distanceToSurface;
			surfaceNormal = downDir;
			if ((renderer.options & RENDERER_OPTION_WATER_WAVES) != 0 && waterWavesStrength > 0) {
				APPLY_NORMAL_BUMP_NOISE(WaterWaves, wavePosition, surfaceNormal, waterWavesStrength * 0.05)
				for (int FIX = 0; FIX < 10; ++FIX) {
					if (dot(reflect(gl_WorldRayDirectionEXT, surfaceNormal), downDir) > 0.001) break;
					surfaceNormal = normalize(surfaceNormal + downDir);
				}
			}
			
			// See through water (underwater looking up, possibly at surface)
			vec3 rayPosition = gl_WorldRayOriginEXT;
			vec3 rayDirection = gl_WorldRayDirectionEXT;
			float rayStart = gl_RayTminEXT;
			for (int RAYLOOP = 0; RAYLOOP < 12; ++RAYLOOP) {
				traceRayEXT(tlas, gl_RayFlagsOpaqueEXT, RAYTRACE_MASK_TERRAIN|RAYTRACE_MASK_ENTITY|RAYTRACE_MASK_CLUTTER, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, rayPosition, rayStart, rayDirection, distanceToSurface, 0);
				if (ray.t1 == -1) {
					ray.albedo = vec3(0);
					ray.t1 = distanceToSurface + EPSILON;
					ray.t2 = -1;
					ray.normal = surfaceNormal;
					ray.transmittance = transmittance * pow(1 - clamp(ray.t1 / WATER_MAX_LIGHT_DEPTH_VERTICAL, 0, 1), 2);
					ray.ior = 1.0 / WATER_IOR;
					ray.reflectance = 0;
					ray.metallic = 0;
					ray.roughness = 0;
					ray.specular = 0;
					ray.localPosition = vec3(0);
					ray.renderableIndex = -1;
					break;
				}
				if (dot(ray.transmittance, ray.transmittance) == 0) {
					ray.transmittance = -transmittance * pow(1 - clamp(ray.t1 / WATER_MAX_LIGHT_DEPTH, 0, 0.9999), 2);
					ray.mask |= RAYTRACE_MASK_HYDROSPHERE;
					break;
				}
				rayStart += ray.t1 + EPSILON;
				transmittance *= ray.transmittance;
				ray.albedo = vec3(0);
				ray.t1 = min(WATER_MAX_LIGHT_DEPTH, distanceToSurface);
				ray.metallic = 0;
				ray.reflectance = 0;
				ray.transmittance = vec3(0);
				ray.mask |= RAYTRACE_MASK_HYDROSPHERE;
				ray.renderableIndex = -1;
			}
			
		} else {
			// See through water (underwater looking down)
			
			vec3 rayPosition = gl_WorldRayOriginEXT;
			vec3 rayDirection = gl_WorldRayDirectionEXT;
			float rayStart = gl_RayTminEXT;
			for (int RAYLOOP = 0; RAYLOOP < 12; ++RAYLOOP) {
				traceRayEXT(tlas, gl_RayFlagsOpaqueEXT, RAYTRACE_MASK_TERRAIN|RAYTRACE_MASK_ENTITY|RAYTRACE_MASK_CLUTTER, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, rayPosition, rayStart, rayDirection, WATER_MAX_LIGHT_DEPTH, 0);
				if (ray.t1 == -1) {
					ray.albedo = vec3(0);
					ray.t1 = WATER_MAX_LIGHT_DEPTH;
					ray.t2 = -1;
					ray.normal = vec3(0);
					ray.transmittance = vec3(0);
					ray.reflectance = 0;
					ray.metallic = 0;
					ray.mask |= RAYTRACE_MASK_HYDROSPHERE;
					ray.renderableIndex = -1;
					break;
				}
				if (dot(ray.transmittance, ray.transmittance) == 0) {
					ray.transmittance = -transmittance * pow(1 - clamp(ray.t1 / WATER_MAX_LIGHT_DEPTH, 0, 0.9999), 2);
					ray.mask |= RAYTRACE_MASK_HYDROSPHERE;
					break;
				}
				rayStart += ray.t1 + EPSILON;
				transmittance *= ray.transmittance;
				ray.albedo = vec3(0);
				ray.t1 = WATER_MAX_LIGHT_DEPTH;
				ray.metallic = 0;
				ray.reflectance = 0;
				ray.transmittance = vec3(0);
				ray.mask |= RAYTRACE_MASK_HYDROSPHERE;
				ray.renderableIndex = -1;
			}
		}
		
		// Fog
		const vec3 origin = gl_WorldRayOriginEXT;
		const vec3 dir = gl_WorldRayDirectionEXT;
		const float distFactor = clamp(ray.t1 / maxLightDepth, 0 ,1);
		const float fogStrength = max(WATER_OPACITY, pow(distFactor, 0.25));
		RayPayload originalRay = ray;
		RAY_GI_PUSH
			traceRayEXT(tlas, gl_RayFlagsOpaqueEXT, RAYTRACE_MASK_ATMOSPHERE, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, worldPosition, 0, -downDir, 10000, 0);
		RAY_GI_POP
		vec3 waterLighting = ray.emission.rgb * WATER_OPACITY * 0.5;
		ray = originalRay;
		ray.emission.rgb = WATER_OPACITY * mix(ray.emission.rgb, waterLighting, pow(clamp(ray.t1 / maxLightDepth, 0, 1), 0.5));
	}
	
	// Debug Time
	DEBUG_RAY_HIT_TIME
}

