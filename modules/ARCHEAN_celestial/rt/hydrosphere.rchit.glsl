#define SHADER_RCHIT
#include "../common.inc.glsl"
#include "xenon/renderer/shaders/perlint.inc.glsl"

#define WORKAROUND_AMD_BUG

WaterData water = WaterData(AABB.data);

hitAttributeEXT hit {
	float T1;
	float T2;
};

#define WATER_IOR 1.333

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
	
#ifdef WORKAROUND_AMD_BUG
	const double r = water.radius + double( sin(float(double(renderer.timestamp*1.06))) + sin(float(double(renderer.timestamp*4.25))) + sin(float(double(renderer.timestamp*1.895))) ) * 0.01;
	const dvec3 oc = dvec3(gl_WorldRayOriginEXT) - water.center;
	const dvec3 dir = dvec3(gl_WorldRayDirectionEXT);
	const double b = dot(oc, dir);
	const double discriminantSqr = b * b - dot(oc, oc) + r*r;
	const double det = double(sqrt(discriminantSqr));
	const float t1 = float(-b - det);
	const float t2 = float(-b + det);
	const vec3 hitPoint1 = gl_WorldRayOriginEXT + gl_WorldRayDirectionEXT * t1;
	const vec3 hitPoint2 = gl_WorldRayOriginEXT + gl_WorldRayDirectionEXT * t2;
	bool inside = t1 <= gl_RayTminEXT && t2 >= gl_RayTminEXT;
#else
	const vec3 hitPoint1 = gl_WorldRayOriginEXT + gl_WorldRayDirectionEXT * T1;
	const vec3 hitPoint2 = gl_WorldRayOriginEXT + gl_WorldRayDirectionEXT * T2;
	bool inside = gl_HitKindEXT == 1;
#endif
	
	const float waterWavesStrength = pow(0.5/*water.wavesStrength*/, 2);
	const vec3 spherePosition = vec3(water.center);
	vec3 downDir = normalize(spherePosition);
	
	if (inside) {
		// Underwater looking at surface
		vec3 surfaceNormal = normalize(spherePosition - hitPoint2);
		
		if (waterWavesStrength > 0 && gl_HitTEXT < giantWavesMaxDistance) {
			APPLY_NORMAL_BUMP_NOISE(WaterWaves, hitPoint2, surfaceNormal, waterWavesStrength * 0.05)
			for (int FIX = 0; FIX < 10; ++FIX) {
				if (dot(reflect(gl_WorldRayDirectionEXT, surfaceNormal), downDir) > 0.001) break;
				surfaceNormal = normalize(surfaceNormal + downDir);
			}
		}
		
		RayHitWorld(
			/*albedo*/		vec3(1),
			/*normal*/		surfaceNormal,
			/*distance*/	gl_HitTEXT,
			/*roughness*/	0,
			/*ior*/			1/WATER_IOR,
			/*flags*/		RAY_SURFACE_TRANSPARENT
		);
		ray.rayFlags |= RAY_FLAG_FLUID;
	} else {
		// Above water looking down
		vec3 surfaceNormal = normalize(hitPoint1 - spherePosition);
		
		if (waterWavesStrength > 0 && gl_HitTEXT < giantWavesMaxDistance) {
			APPLY_NORMAL_BUMP_NOISE(WaterWaves, hitPoint1, surfaceNormal, waterWavesStrength * 0.05)
			for (int FIX = 0; FIX < 10; ++FIX) {
				if (dot(reflect(gl_WorldRayDirectionEXT, surfaceNormal), -downDir) > 0.001) break;
				surfaceNormal = normalize(surfaceNormal - downDir);
			}
		}
		
		float transparency = smoothstep(10000, 100, gl_HitTEXT);
		
		RayHitWorld(
			/*albedo*/		vec3(sqrt(max(0, dot(surfaceNormal, -gl_WorldRayDirectionEXT)))) * transparency,
			/*normal*/		surfaceNormal,
			/*distance*/	gl_HitTEXT,
			/*roughness*/	0,
			/*ior*/			WATER_IOR,
			/*flags*/		transparency>0? RAY_SURFACE_TRANSPARENT : RAY_SURFACE_DIFFUSE
		);
		ray.rayFlags |= RAY_FLAG_FLUID;
	}
	
}
