#include "xenon/renderer/shaders/perlint.inc.glsl"

#define TERRAIN_UNIT_MULTIPLIER 1000
#define M *TERRAIN_UNIT_MULTIPLIER
#define KM *TERRAIN_UNIT_MULTIPLIER*1000

BUFFER_REFERENCE_STRUCT(4) CelestialConfig {
	aligned_float64_t baseRadiusMillimeters;
	aligned_float64_t heightVariationMillimeters;
	aligned_float32_t hydrosphere;
	aligned_float32_t continent_ratio;
	aligned_uint32_t continent_size;
	aligned_uint32_t _unused;
	aligned_uint64_t seed;
};
#ifdef GLSL
	#define config CelestialConfig(celestial_configs) // from the push_constant
#else
	CelestialConfig config;
#endif

double _moutainStep(double start, double end, double value) {
	if (value > start && value < end) return mix(start, value, smoothstep(start, end, value));
	if (value < start && value > end) return mix(start, value, smoothstep(start, end, value));
	return value;
}

dvec3 GetMainFeaturePosition() {
	return normalize(cross(dvec3(0,1,0), dvec3(1.2083421,0.2668722,0.631745)));
}

dvec2 GetHeightMapAndFeature(dvec3 normalizedPos) {
	u64vec3 pos = u64vec3(normalizedPos * config.baseRadiusMillimeters + 10000000000.0); // this supports planets with a maximum radius of 10'000 km and ground precision of 1 cm
	
	uint64_t variation = uint64_t(config.heightVariationMillimeters);
	double variationf = double(variation);
	
	const uint64_t warpMaximum = 250 KM;
	const uint64_t warpStride = 500 KM;
	const uint warpOctaves = 4;
	const uint64_t continentStride = uint64_t(config.continent_size) KM;
	const double volcanoRadius = 70 KM;
	const double volcanoHoleRadius = 2.5 KM;
	
	u64vec3 warp = u64vec3(perlint64(pos + config.seed + uint64_t(114546495), warpStride, warpMaximum, warpOctaves), perlint64(pos + uint64_t(15165156), warpStride, warpMaximum, warpOctaves), perlint64(pos - uint64_t(22897178), warpStride, warpMaximum, warpOctaves));
	u64vec3 volcanoWarp = u64vec3(perlint64(pos, warpStride/100, warpMaximum/200, warpOctaves), perlint64(pos + uint64_t(15165156), warpStride/100, warpMaximum/200, warpOctaves), perlint64(pos - uint64_t(22897178), warpStride/100, warpMaximum/200, warpOctaves));
	
	dvec3 arbitraryPointOnEquator = GetMainFeaturePosition();
	double continentsMax = clamp(dot(normalizedPos, arbitraryPointOnEquator), 0.0, 1.0);
	continentsMax = continentsMax*continentsMax*continentsMax*continentsMax*continentsMax*continentsMax;
	double continentsMed = continentsMax * (slerp(perlint64f(pos + config.seed + uint64_t(1191658432) + warp, continentStride/2, variation)));
	double continentsMin = continentsMed * (slerp(perlint64f(pos + config.seed + uint64_t(1426576949) + warp, continentStride/4, variation)));
	double continents = smoothCurve(slerp(slerp(slerp((mix(mix(continentsMin, continentsMed, smoothstep(0.25, 0.5, double(config.continent_ratio))), mix(continentsMax, 0.7, smoothstep(0.5, 1.0, double(config.continent_ratio))), smoothstep(0.5, 1.0, double(config.continent_ratio))))))));
	double volcanoIsland = clamp(max(0.0, dot(normalizedPos, arbitraryPointOnEquator) - 0.999) * 1000.0, 0.0, 1.0);
	volcanoIsland = volcanoIsland*volcanoIsland*volcanoIsland*volcanoIsland*volcanoIsland*volcanoIsland*volcanoIsland*volcanoIsland;
	continents += volcanoIsland;
	double coasts = continents * clamp((1.0-continents)*2.0 * (perlint64f(pos + config.seed, continentStride, variation, 2) * 1.5 - 0.1) + 0.025, 0.0, 1.0);
	double peaks1 = 1.0 - perlint64fRidged(pos + warp/uint64_t(2) + uint64_t(1149783892), 50 KM, variation, 4);
	double peaks2 = perlint64f(pos+warp/uint64_t(4) + uint64_t(87457641), 8 KM, variation/8, 2);
	double peaks3 = perlint64f(pos+warp/uint64_t(4) + uint64_t(276537654), 2 KM, variation/32, 2);
	double canyons = perlint64fRidged(pos + warp/uint64_t(2) + uint64_t(1762549832), 20 KM, variation, 4);
	
	double distanceToVolcanoCenter = length(normalizedPos * config.baseRadiusMillimeters - arbitraryPointOnEquator * config.baseRadiusMillimeters);
	double distanceToVolcanoCenterDistorted = length(normalizedPos * config.baseRadiusMillimeters + dvec3(volcanoWarp) - arbitraryPointOnEquator * config.baseRadiusMillimeters);
	double volcano = max(0.0, volcanoRadius - distanceToVolcanoCenter) / volcanoRadius;
	
	double sharpPeaks = double(perlint64Ridged(pos + volcanoWarp, 400 M, 50 M, 3)) / (50 M);
	
	double mountains = 0
		+ continents * variationf * 0.45
		- variationf * 0.11
		+ coasts * peaks1 * variation
		+ coasts * peaks2*peaks2 * variation/4
		+ coasts * peaks3*peaks3 * variation/8
		- coasts * canyons*canyons * variation
		+ sharpPeaks * sharpPeaks * 50 M
		+ sharpPeaks * (perlint64f(pos, 50 M, 50 M, 5)) * 20 M
		+ sharpPeaks * (perlint64f(pos, 5 M, 5 M, 3)) * 2 M
		- sharpPeaks*sharpPeaks * (perlint64f(pos, 2 M, 2 M, 4)) * 1 M
		- sharpPeaks*sharpPeaks * (perlint64f(pos, uint64_t(0.5 M), uint64_t(0.5 M), 4)) * 0.25 M
	;
	
	mountains = _moutainStep(variationf * 0.2001, variationf * 0.1995, mountains);
	mountains = _moutainStep(variationf * 0.2001, variationf * 0.3, mountains);
	
	double height = config.baseRadiusMillimeters
		+ max(0.0, mountains)
		+ volcano*volcano*volcano * variationf*0.686
		- max(0.0, volcanoHoleRadius - distanceToVolcanoCenterDistorted) / volcanoHoleRadius * variationf*0.5
	;
	
	double feature = 0;
	
	if (height < config.baseRadiusMillimeters + variationf * 0.23) {
		feature = TERRAIN_FEATURE_WAVY_SAND;
	}
	
	// Volcano
	if (distanceToVolcanoCenter < volcanoRadius * 1.7) {
		feature = TERRAIN_FEATURE_VOLCANO;
	}
	
	// Lava
	if (distanceToVolcanoCenterDistorted < volcanoHoleRadius * 0.85) {
		height = max(height, config.baseRadiusMillimeters + variationf * 0.85);
		if (height == config.baseRadiusMillimeters + variationf * 0.85) {
			feature = TERRAIN_FEATURE_LAVA;
		}
	}
	
	return dvec2(height / double(TERRAIN_UNIT_MULTIPLIER), feature);
}

double GetHeightMap(dvec3 normalizedPos) {
	return GetHeightMapAndFeature(normalizedPos).x;
}

#ifdef GLSL
	vec4 GetSplat(dvec3 posNorm, double height, float slope, double feature) {
		u64vec3 pos = u64vec3(posNorm * height * 100 + 1000000000.0);
		double heightRatio = (height - double(config.baseRadiusMillimeters)/TERRAIN_UNIT_MULTIPLIER) / config.heightVariationMillimeters * TERRAIN_UNIT_MULTIPLIER;
		float dryLake = clamp(float(perlint64f(pos, 20000, 255, 4)) + float(perlint64f(pos, 1000, 255, 6)) * 0.5 - 0.4, 0, 1)
			* smoothstep(config.hydrosphere + 0.0002, config.hydrosphere + 0.00019, float(heightRatio))
			* smoothstep(config.hydrosphere + 0.000098, config.hydrosphere + 0.000105, float(heightRatio))
		;
		float pebbles = clamp(float(perlint64f(pos, 10000, 255, 3)) + float(perlint64f(pos, 1000, 255, 6)) * 0.5 - 0.5, 0, 1);
		float stones = clamp(pow(float(perlint64f(pos, 5000, 255, 5)), 0.5) * float(perlint64f(pos, 1000, 255, 5)), 0, 1);
		vec4 splat = smoothCurve(smoothCurve(smoothCurve(vec4(dryLake,pebbles,stones,0))));
		if (feature == TERRAIN_FEATURE_VOLCANO) {
			float volcanicRocks = clamp(float(perlint64f(pos, 1000, 255, 3) + perlint64f(pos, 200, 255, 4)) * 0.5, 0, 1);
			splat = mix(smoothCurve(smoothCurve(smoothCurve(vec4(0,0,0,volcanicRocks)))), splat, pow(clamp(float(1.0 - heightRatio) * 2 - 0.6, 0, 1), 4));
		}
		return splat;
	}
	vec3 GetColor(dvec3 posNorm, double height, float slope, double feature, vec4 splat) {
		double heightRatio = (height - double(config.baseRadiusMillimeters)/TERRAIN_UNIT_MULTIPLIER) / config.heightVariationMillimeters * TERRAIN_UNIT_MULTIPLIER;
		const vec3 baseColor = vec3(0.47, 0.45, 0.42);
		const vec3 sandColor = vec3(0.5, 0.4, 0.3);
		const vec3 mountainsColor = vec3(0.3, 0.27, 0.23);
		const vec3 rockColor = vec3(0.2);
		vec3 color = mix(mix(baseColor, sandColor, smoothCurve(splat.x + splat.y)), rockColor, pow(smoothstep(0.2, 0.25, float(heightRatio)), 0.125));
		if (feature == TERRAIN_FEATURE_VOLCANO) {
			color = mix(vec3(0.1), color, pow(clamp(float(1.0 - heightRatio) * 2 - 0.6, 0, 1), 4));
		} else {
			u64vec3 pos = u64vec3(posNorm * height * 100 + 1000000000.0);
			float mountainsHeightRatio = float(heightRatio + perlint64f(pos, 1 KM, 1 KM, 3) * 0.04) - 0.03;
			color = mix(color, mountainsColor, smoothstep(0.33, 0.38, mountainsHeightRatio) * smoothstep(0.5, 0.38, mountainsHeightRatio));
		}
		return color;
	}
	float GetClutterDensity(dvec3 posNorm, double height) {
		u64vec3 pos = u64vec3(posNorm * height * 100 + 1000000000.0);
		float pebbles = clamp(float(perlint64f(pos, 10000, 255, 3)) + float(perlint64f(pos, 1000, 255, 6)) * 0.5 - 0.5, 0, 1);
		float dryLake = clamp(float(perlint64f(pos, 20000, 255, 4)) + float(perlint64f(pos, 1000, 255, 6)) * 0.5 - 0.5, 0, 1);
		double heightRatio = (height - double(config.baseRadiusMillimeters)/TERRAIN_UNIT_MULTIPLIER) / config.heightVariationMillimeters * TERRAIN_UNIT_MULTIPLIER;
		return
			// Underwater rocks
			+ smoothstep(config.hydrosphere - 0.00003, config.hydrosphere - 0.0003, float(heightRatio))
			
			// Beach rocks
			+ smoothstep(config.hydrosphere + 0.0003, config.hydrosphere + 0.00028, float(heightRatio))
			* smoothstep(config.hydrosphere + 0.00009, config.hydrosphere + 0.0001, float(heightRatio))
			* smoothCurve(smoothCurve(pebbles))
		;
	}
#endif
