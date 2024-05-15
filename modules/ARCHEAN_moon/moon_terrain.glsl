#include "xenon/renderer/shaders/perlint.inc.glsl"

#define TERRAIN_UNIT_MULTIPLIER 1000
#define M *TERRAIN_UNIT_MULTIPLIER
#define KM *TERRAIN_UNIT_MULTIPLIER*1000

BUFFER_REFERENCE_STRUCT(4) CelestialConfig {
	aligned_float64_t baseRadiusMillimeters;
	aligned_float64_t heightVariationMillimeters;
	aligned_float32_t hydrosphere;
	aligned_float32_t continent_ratio;
};
#ifdef GLSL
	#define config CelestialConfig(celestial_configs) // from the push_constant
#else
	CelestialConfig config;
#endif

double Crater(u64vec3 pos, uint64_t stride, uint64_t variation) {
	double t = smoothstep(0.96, 0.995, perlint64f(pos, stride, variation));
	return max(smoothstep(0.0, 0.5, t * (0.9 + perlint64f(pos, stride / 25, variation, 3))), step(0.5, 1 - t) * 0.75) * smoothstep(1.0, 0.5, t * (0.9 + perlint64f(pos, stride / 10, variation, 3))) - 0.7;
}

dvec2 GetHeightMapAndFeature(dvec3 posNorm) {
	u64vec3 pos = u64vec3(posNorm * config.baseRadiusMillimeters + 10000000000.0); // this supports planets with a maximum radius of 10'000 km and ground precision of 1 cm
	
	uint64_t variation = uint64_t(config.heightVariationMillimeters);
	double variationf = double(variation);
	
	double continents = (perlint64f(pos, 1200 KM, variation, 2) * 2 - 1) * -5 KM;
	double mountains = perlint64f(pos, 500 KM, variation, 4) * perlint64f(pos / u64vec3(1,3,8), 100 KM, variation, 4) + smoothstep(0.25, 1.0, perlint64f(pos / u64vec3(2,1,4), 10 KM, variation, 4));
	double detail = (perlint64f(pos, 2000 KM, variation, 12) * 2 - 1) * 2 KM + mountains*mountains * perlint64f(pos, 300 M, variation, 3) * 25 M + mountains*mountains * perlint64f(pos, 25 M, variation, 2) * 10 M + mountains * perlint64f(pos, 5 M, variation, 2) * 1 M - mountains*mountains * abs(perlint64f(pos, 1 M / 2, variation, 3) - 0.2) * 0.2 M;
	
	double height = variationf * 0.3 + mountains * variationf * 0.01;
	height += Crater(pos, 500 KM, variation) * 5 KM;
	height += Crater(pos, 200 KM, variation) * 2 KM;
	height += Crater(pos, 100 KM, variation) * 1 KM;
	height += Crater(pos, 60 KM, variation) * 1 KM;
	height += Crater(pos, 40 KM, variation) * 1 KM;
	height += Crater(pos, 30 KM, variation) * 0.5 KM;
	height += Crater(pos, 12 KM, variation) * 0.25 KM;
	height += Crater(pos, 9 KM, variation) * 0.25 KM;
	height += Crater(pos, 6 KM, variation) * 0.1 KM;
	height += Crater(pos, 2 KM, variation) * 0.05 KM;
	height += Crater(pos, 1 KM, variation) * 0.05 KM;
	
	return dvec2((config.baseRadiusMillimeters + clamp(continents + height + detail, 0.0, variationf)) / double(TERRAIN_UNIT_MULTIPLIER), 0);
}

double GetHeightMap(dvec3 posNorm) {
	return GetHeightMapAndFeature(posNorm).x;
}

#ifdef GLSL
	vec4 GetSplat(dvec3 posNorm, double height, float slope, double feature) {
		return vec4(0);
	}
	vec3 GetColor(dvec3 posNorm, double height, float slope, double feature, vec4 splat) {
		u64vec3 pos = u64vec3(posNorm * config.baseRadiusMillimeters + 10000000000.0); // this supports planets with a maximum radius of 10'000 km and ground precision of 1 cm
		uint64_t variation = uint64_t(config.heightVariationMillimeters);
		double heightRatio = (height - double(config.baseRadiusMillimeters)/TERRAIN_UNIT_MULTIPLIER) / config.heightVariationMillimeters * TERRAIN_UNIT_MULTIPLIER;
		float continents = float(perlint64f(pos, 1200 KM, variation, 3)) * 0.6 - float(perlint64f(pos, 250 KM, variation, 3)) * 0.5 + float(perlint64f(pos, 50 KM, variation, 3)) * 0.5 + float(perlint64f(pos, 10 KM, variation, 4)) * 0.5;
		vec3 color = mix(vec3(0.05, 0.1, 0.2), vec3(0.7, 0.8, 1.0), smoothstep(0, 1, continents * 0.8 + 0.2));
		color = mix(vec3(0.16, 0.2, 0.3), color, smoothstep(0.2, 0.4, float(heightRatio)));
		color = mix(vec3(0.25,0.305,0.4), color, smoothstep(0.05, 0.2, float(heightRatio)));
		color *= mix(0.8, 1.1, float(perlint64f(pos, 10 KM, 10 KM, 3)));
		color *= mix(0.8, 1.1, float(perlint64f(pos, 1 M / 8, 1 M / 8, 6)));
		color *= 0.3;
		return pow(clamp(color, vec3(0.0), vec3(0.999)), vec3(0.5));
		// return HeatmapClamped(float(heightRatio));
	}
	float GetClutterDensity(dvec3 posNorm, double height) {
		return 0;
	}
#endif
