// Di
#define NB_LIGHTS 16
#define SORT_LIGHTS
// Gi
#define ACCUMULATOR_MAX_FRAME_INDEX_DIFF 10
#define GI_MAX_DISTANCE (rayIsUnderWater? 40 : 100)
// #define USE_BLUE_NOISE

uint rotl32(uint x, uint r) {
	return (x << r) | (x >> (32 - r));
}
uint fmix32(uint h) {
	h ^= h >> 16;
	h *= 0x85ebca6b;
	h ^= h >> 13;
	h *= 0xc2b2ae35;
	h ^= h >> 16;
	return h;
}
uint hash4(uvec4 key) {
	uint h = 0;
	uint c1 = 0xcc9e2d51;
	uint c2 = 0x1b873593;
	uint r1 = 15;
	uint r2 = 13;
	uint m = 5;
	uint n = 0xe6546b64;

	for (int i = 0; i < 4; ++i) {
		uint k = key[i];
		k *= c1;
		k = rotl32(k, r1);
		k *= c2;

		h ^= k;
		h = rotl32(h, r2);
		h = h * m + n;
	}

	h ^= 16;
	h = fmix32(h);

	return h;
}

uvec4 GetGiPos(in uint objectIndex, in ivec3 pos) {
	return uvec4(uvec3(pos + ivec3(1<<30)), objectIndex);
}
uint GetGiIndex(in uint objectIndex, in ivec3 pos) {
	return (hash4(GetGiPos(objectIndex, pos)) % renderer.globalIlluminationTableCount);
}
#define GetGi(i) renderer.globalIllumination[i]
#define GetGi0(i) renderer.globalIllumination0[i]
#define GetGi1(i) renderer.globalIllumination1[i]

const int nbAdjacentSides = 26;
const ivec3 adjacentSides[nbAdjacentSides] = {
	ivec3( 0, 0, 1),
	ivec3( 0, 1, 0),
	ivec3( 1, 0, 0),
	ivec3( 0, 0,-1),
	ivec3( 0,-1, 0),
	ivec3(-1, 0, 0),
	
	ivec3( 0, 1, 1),
	ivec3( 1, 0, 1),
	ivec3( 1, 1, 0),
	ivec3( 0,-1,-1),
	ivec3(-1, 0,-1),
	ivec3(-1,-1, 0),
	ivec3( 0,-1, 1),
	ivec3(-1, 0, 1),
	ivec3(-1, 1, 0),
	ivec3( 0, 1,-1),
	ivec3( 1, 0,-1),
	ivec3( 1,-1, 0),
	
	ivec3(-1,-1,-1),
	ivec3(-1,-1,+1),
	ivec3(-1,+1,-1),
	ivec3(-1,+1,+1),
	ivec3(+1,-1,-1),
	ivec3(+1,-1,+1),
	ivec3(+1,+1,-1),
	ivec3(+1,+1,+1),
};

bool LockAmbientLighting0(in uint giIndex) {
	return atomicExchange(GetGi0(giIndex).lock, 1) != 1;
}
void UnlockAmbientLighting0(in uint giIndex) {
	GetGi0(giIndex).lock = 0;
}
bool LockAmbientLighting1(in uint giIndex) {
	return atomicExchange(GetGi1(giIndex).lock, 1) != 1;
}
void UnlockAmbientLighting1(in uint giIndex) {
	GetGi1(giIndex).lock = 0;
}

vec4 GetGiVariance(in uint objectIndex, in ivec3 pos) {
	vec4 variance = vec4(0);
	if (abs(GetGi0(GetGiIndex(objectIndex, pos)).frameIndex - int64_t(xenonRendererData.frameIndex)) < ACCUMULATOR_MAX_FRAME_INDEX_DIFF && GetGi0(GetGiIndex(objectIndex, pos)).iteration == renderer.giIteration && GetGi0(GetGiIndex(objectIndex, pos)).pos == GetGiPos(objectIndex, pos)) {
		variance = GetGi(GetGiIndex(objectIndex, pos)).variance;
	}
	for (int i = 0; i < nbAdjacentSides; ++i) {
		ivec3 iPos = pos + adjacentSides[i];
		if (abs(GetGi0(GetGiIndex(objectIndex, iPos)).frameIndex - int64_t(xenonRendererData.frameIndex)) < ACCUMULATOR_MAX_FRAME_INDEX_DIFF && GetGi0(GetGiIndex(objectIndex, iPos)).iteration == renderer.giIteration && GetGi0(GetGiIndex(objectIndex, iPos)).pos == GetGiPos(objectIndex, iPos)) {
			variance = max(variance, GetGi(GetGiIndex(objectIndex, iPos)).variance);
		}
	}
	return variance;
}

vec4 GetGiRadianceVariance(in uint objectIndex, in ivec3 pos, in vec3 newRadiance) {
	vec3 radiance1 = newRadiance;
	vec3 radiance2 = newRadiance*newRadiance;
	int totalSamples = 1;
	if (abs(GetGi0(GetGiIndex(objectIndex, pos)).frameIndex - int64_t(xenonRendererData.frameIndex)) < ACCUMULATOR_MAX_FRAME_INDEX_DIFF && GetGi0(GetGiIndex(objectIndex, pos)).iteration == renderer.giIteration && GetGi0(GetGiIndex(objectIndex, pos)).pos == GetGiPos(objectIndex, pos)) {
		vec3 radiance = GetGi(GetGiIndex(objectIndex, pos)).variance.rgb;
		radiance1 += radiance;
		radiance2 = radiance*radiance;
		++totalSamples;
	}
	for (int i = 0; i < nbAdjacentSides; ++i) {
		ivec3 iPos = pos + adjacentSides[i];
		if (abs(GetGi0(GetGiIndex(objectIndex, iPos)).frameIndex - int64_t(xenonRendererData.frameIndex)) < ACCUMULATOR_MAX_FRAME_INDEX_DIFF && GetGi0(GetGiIndex(objectIndex, iPos)).iteration == renderer.giIteration && GetGi0(GetGiIndex(objectIndex, iPos)).pos == GetGiPos(objectIndex, iPos)) {
			vec3 radiance = GetGi(GetGiIndex(objectIndex, iPos)).variance.rgb;
			radiance1 += radiance;
			radiance2 = radiance*radiance;
			++totalSamples;
		}
	}
	radiance1 /= float(totalSamples);
	radiance2 /= float(totalSamples);
	vec3 sigma = sqrt(abs(radiance2 - radiance1*radiance1));
	return vec4(newRadiance, length(sigma));
}

// Level 0 (locked from caller)
vec3 WriteAmbientLighting0(in uint giIndex, in uint objectIndex, in ivec3 iPos, in vec3 color) {
	uvec4 giPos = GetGiPos(objectIndex, iPos);
	vec4 radiance = GetGi0(giIndex).radiance;
	float accumulation = clamp(radiance.a + 1, 1, mix(10, 400, clamp(GetGiVariance(objectIndex, iPos).a, 0, 1)));
	if (abs(GetGi0(giIndex).frameIndex - int64_t(xenonRendererData.frameIndex)) >= ACCUMULATOR_MAX_FRAME_INDEX_DIFF || GetGi0(giIndex).iteration != renderer.giIteration) {
		accumulation = 1;
		GetGi0(giIndex).pos = giPos;
		GetGi(giIndex).bestSample = vec4(0);
	}
	vec3 l = mix(radiance.rgb, color, clamp(1.0/accumulation, 0, 1));
	if (isnan(l.r) || isnan(l.g) || isnan(l.b) || isnan(accumulation)) {
		l = vec3(0);
		accumulation = 1;
		GetGi0(giIndex).pos = giPos;
		GetGi(giIndex).bestSample = vec4(0);
	}
	if (GetGi0(giIndex).pos == giPos) {
		GetGi0(giIndex).iteration = renderer.giIteration;
		GetGi0(giIndex).frameIndex = int64_t(xenonRendererData.frameIndex);
		GetGi0(giIndex).radiance = vec4(l, accumulation);
		GetGi(giIndex).variance = GetGiRadianceVariance(objectIndex, iPos, color);
	}
	return l;
}

// Level 1
vec3 WriteAmbientLighting1(in uint objectIndex, in ivec3 iPos, in vec3 inputRadiance, in float inputRatio) {
	vec3 l = clamp(inputRadiance, vec3(0), vec3(1));
	uint giIndex = GetGiIndex(objectIndex, iPos);
	if (LockAmbientLighting1(giIndex)) {
		uvec4 giPos = GetGiPos(objectIndex, iPos);
		vec4 radiance = GetGi1(giIndex).radiance;
		float accumulation = clamp(radiance.a + 1, 1, mix(10, 400, clamp(GetGiVariance(objectIndex, iPos).a, 0, 1)));
		if (isnan(l.r) || isnan(l.g) || isnan(l.b) || isnan(accumulation)) {
			l = vec3(0);
			accumulation = 1;
			GetGi1(giIndex).pos = giPos;
		} else if (abs(GetGi1(giIndex).frameIndex - int64_t(xenonRendererData.frameIndex)) >= ACCUMULATOR_MAX_FRAME_INDEX_DIFF || GetGi1(giIndex).iteration != renderer.giIteration) {
			accumulation = 1;
			GetGi1(giIndex).pos = giPos;
		} else {
			l = mix(radiance.rgb, l, inputRatio/accumulation);
		}
		if (GetGi1(giIndex).pos == giPos) {
			GetGi1(giIndex).iteration = renderer.giIteration;
			GetGi1(giIndex).frameIndex = int64_t(xenonRendererData.frameIndex);
			GetGi1(giIndex).radiance = vec4(l, accumulation);
		}
		UnlockAmbientLighting1(giIndex);
	}
	return l;
}


float smoothInterpolation(float x) {
	// return mix(x, x*x*(3-2*x), 0.5);
	return 0.5 * x + 1.5 * x*x - x*x*x;
}

// vec3 DebugGiVariance(in uint objectIndex, in vec3 pos) {
// 	return Heatmap(GetGiVariance(objectIndex, ivec3(round(pos))).a);
// }

vec3 GetAmbientLighting(in uint objectIndex, in vec3 pos) {
	vec3 d = fract(pos);
	ivec3 ipos = ivec3(floor(pos));
	uint giIndex = GetGiIndex(objectIndex, ipos);
	
	vec3 p[8];
	p[0] /*p000*/ = GetGi1(giIndex).radiance.rgb;
	p[1] /*p001*/ = GetGi1(GetGiIndex(objectIndex, ipos + ivec3(0,0,1))).radiance.rgb;
	p[2] /*p010*/ = GetGi1(GetGiIndex(objectIndex, ipos + ivec3(0,1,0))).radiance.rgb;
	p[3] /*p011*/ = GetGi1(GetGiIndex(objectIndex, ipos + ivec3(0,1,1))).radiance.rgb;
	p[4] /*p100*/ = GetGi1(GetGiIndex(objectIndex, ipos + ivec3(1,0,0))).radiance.rgb;
	p[5] /*p101*/ = GetGi1(GetGiIndex(objectIndex, ipos + ivec3(1,0,1))).radiance.rgb;
	p[6] /*p110*/ = GetGi1(GetGiIndex(objectIndex, ipos + ivec3(1,1,0))).radiance.rgb;
	p[7] /*p111*/ = GetGi1(GetGiIndex(objectIndex, ipos + ivec3(1,1,1))).radiance.rgb;
	
	bool goodSamples[8];
	goodSamples[0] = abs(GetGi1(giIndex).frameIndex - int64_t(xenonRendererData.frameIndex)) < ACCUMULATOR_MAX_FRAME_INDEX_DIFF && GetGi1(giIndex).iteration == renderer.giIteration && GetGi1(giIndex).pos == GetGiPos(objectIndex, ipos);
	goodSamples[1] = abs(GetGi1(GetGiIndex(objectIndex, ipos + ivec3(0,0,1))).frameIndex - int64_t(xenonRendererData.frameIndex)) < ACCUMULATOR_MAX_FRAME_INDEX_DIFF && GetGi1(GetGiIndex(objectIndex, ipos + ivec3(0,0,1))).iteration == renderer.giIteration && GetGi1(GetGiIndex(objectIndex, ipos + ivec3(0,0,1))).pos == GetGiPos(objectIndex, ipos + ivec3(0,0,1));
	goodSamples[2] = abs(GetGi1(GetGiIndex(objectIndex, ipos + ivec3(0,1,0))).frameIndex - int64_t(xenonRendererData.frameIndex)) < ACCUMULATOR_MAX_FRAME_INDEX_DIFF && GetGi1(GetGiIndex(objectIndex, ipos + ivec3(0,1,0))).iteration == renderer.giIteration && GetGi1(GetGiIndex(objectIndex, ipos + ivec3(0,1,0))).pos == GetGiPos(objectIndex, ipos + ivec3(0,1,0));
	goodSamples[3] = abs(GetGi1(GetGiIndex(objectIndex, ipos + ivec3(0,1,1))).frameIndex - int64_t(xenonRendererData.frameIndex)) < ACCUMULATOR_MAX_FRAME_INDEX_DIFF && GetGi1(GetGiIndex(objectIndex, ipos + ivec3(0,1,1))).iteration == renderer.giIteration && GetGi1(GetGiIndex(objectIndex, ipos + ivec3(0,1,1))).pos == GetGiPos(objectIndex, ipos + ivec3(0,1,1));
	goodSamples[4] = abs(GetGi1(GetGiIndex(objectIndex, ipos + ivec3(1,0,0))).frameIndex - int64_t(xenonRendererData.frameIndex)) < ACCUMULATOR_MAX_FRAME_INDEX_DIFF && GetGi1(GetGiIndex(objectIndex, ipos + ivec3(1,0,0))).iteration == renderer.giIteration && GetGi1(GetGiIndex(objectIndex, ipos + ivec3(1,0,0))).pos == GetGiPos(objectIndex, ipos + ivec3(1,0,0));
	goodSamples[5] = abs(GetGi1(GetGiIndex(objectIndex, ipos + ivec3(1,0,1))).frameIndex - int64_t(xenonRendererData.frameIndex)) < ACCUMULATOR_MAX_FRAME_INDEX_DIFF && GetGi1(GetGiIndex(objectIndex, ipos + ivec3(1,0,1))).iteration == renderer.giIteration && GetGi1(GetGiIndex(objectIndex, ipos + ivec3(1,0,1))).pos == GetGiPos(objectIndex, ipos + ivec3(1,0,1));
	goodSamples[6] = abs(GetGi1(GetGiIndex(objectIndex, ipos + ivec3(1,1,0))).frameIndex - int64_t(xenonRendererData.frameIndex)) < ACCUMULATOR_MAX_FRAME_INDEX_DIFF && GetGi1(GetGiIndex(objectIndex, ipos + ivec3(1,1,0))).iteration == renderer.giIteration && GetGi1(GetGiIndex(objectIndex, ipos + ivec3(1,1,0))).pos == GetGiPos(objectIndex, ipos + ivec3(1,1,0));
	goodSamples[7] = abs(GetGi1(GetGiIndex(objectIndex, ipos + ivec3(1,1,1))).frameIndex - int64_t(xenonRendererData.frameIndex)) < ACCUMULATOR_MAX_FRAME_INDEX_DIFF && GetGi1(GetGiIndex(objectIndex, ipos + ivec3(1,1,1))).iteration == renderer.giIteration && GetGi1(GetGiIndex(objectIndex, ipos + ivec3(1,1,1))).pos == GetGiPos(objectIndex, ipos + ivec3(1,1,1));
	
	vec3 avgGoodSamples = vec3(0);
	int nbGoodSamples = 0;
	for (int i = 0; i < 8; ++i) {
		if (goodSamples[i]) {
			avgGoodSamples += p[i];
			++nbGoodSamples;
		}
	}
	if (nbGoodSamples > 0) {
		avgGoodSamples /= float(nbGoodSamples);
	} else {
		return vec3(-1);
	}
	
	for (int i = 0; i < 8; ++i) {
		if (!goodSamples[i]) {
			p[i] = avgGoodSamples;
		}
	}
	
	vec3 p00 = (p[0] * smoothInterpolation(1.0f - d.x) + p[4] * smoothInterpolation(d.x));
	vec3 p01 = (p[1] * smoothInterpolation(1.0f - d.x) + p[5] * smoothInterpolation(d.x));
	vec3 p10 = (p[2] * smoothInterpolation(1.0f - d.x) + p[6] * smoothInterpolation(d.x));
	vec3 p11 = (p[3] * smoothInterpolation(1.0f - d.x) + p[7] * smoothInterpolation(d.x));
	vec3 p0 = (p00 * smoothInterpolation(1.0f - d.y) + p10 * smoothInterpolation(d.y));
	vec3 p1 = (p01 * smoothInterpolation(1.0f - d.y) + p11 * smoothInterpolation(d.y));
	return p0 * smoothInterpolation(1.0f - d.z) + p1 * smoothInterpolation(d.z);
}


bool GetBlueNoiseBool() {
	uint BLUE_NOISE_TEXTURES_OFFSET = renderer.bluenoise_unitvec1;
	uint noiseTexIndex = uint(xenonRendererData.frameIndex % BLUE_NOISE_NB_TEXTURES);
	vec2 texSize = vec2(textureSize(textures[nonuniformEXT(noiseTexIndex+BLUE_NOISE_TEXTURES_OFFSET)], 0).st);
	vec2 noiseTexCoord = (vec2(gl_LaunchIDEXT.x, gl_LaunchIDEXT.y) + 0.5) / texSize;
	return texture(textures[nonuniformEXT(noiseTexIndex+BLUE_NOISE_TEXTURES_OFFSET)], noiseTexCoord).r == 1;
}

float GetBlueNoiseFloat() {
	uint BLUE_NOISE_TEXTURES_OFFSET = renderer.bluenoise_scalar;
	uint noiseTexIndex = uint(xenonRendererData.frameIndex % BLUE_NOISE_NB_TEXTURES);
	vec2 texSize = vec2(textureSize(textures[nonuniformEXT(noiseTexIndex+BLUE_NOISE_TEXTURES_OFFSET)], 0).st);
	vec2 noiseTexCoord = (vec2(gl_LaunchIDEXT.x, gl_LaunchIDEXT.y) + 0.5) / texSize;
	return texture(textures[nonuniformEXT(noiseTexIndex+BLUE_NOISE_TEXTURES_OFFSET)], noiseTexCoord).r;
}

vec2 GetBlueNoiseFloat2() {
	uint BLUE_NOISE_TEXTURES_OFFSET = renderer.bluenoise_vec2;
	uint noiseTexIndex = uint(xenonRendererData.frameIndex % BLUE_NOISE_NB_TEXTURES);
	vec2 texSize = vec2(textureSize(textures[nonuniformEXT(noiseTexIndex+BLUE_NOISE_TEXTURES_OFFSET)], 0).st);
	vec2 noiseTexCoord = (vec2(gl_LaunchIDEXT.x, gl_LaunchIDEXT.y) + 0.5) / texSize;
	return texture(textures[nonuniformEXT(noiseTexIndex+BLUE_NOISE_TEXTURES_OFFSET)], noiseTexCoord).rg;
}

vec3 GetBlueNoiseUnitSphere() {
	uint BLUE_NOISE_TEXTURES_OFFSET = renderer.bluenoise_unitvec3;
	uint noiseTexIndex = uint(xenonRendererData.frameIndex % BLUE_NOISE_NB_TEXTURES);
	vec2 texSize = vec2(textureSize(textures[nonuniformEXT(noiseTexIndex+BLUE_NOISE_TEXTURES_OFFSET)], 0).st);
	vec2 noiseTexCoord = (vec2(gl_LaunchIDEXT.x, gl_LaunchIDEXT.y) + 0.5) / texSize;
	return texture(textures[nonuniformEXT(noiseTexIndex+BLUE_NOISE_TEXTURES_OFFSET)], noiseTexCoord).rgb * 2 - 1;
}

vec4 GetBlueNoiseUnitCosine() {
	uint BLUE_NOISE_TEXTURES_OFFSET = renderer.bluenoise_unitvec3_cosine;
	uint noiseTexIndex = uint(xenonRendererData.frameIndex % BLUE_NOISE_NB_TEXTURES);
	vec2 texSize = vec2(textureSize(textures[nonuniformEXT(noiseTexIndex+BLUE_NOISE_TEXTURES_OFFSET)], 0).st);
	vec2 noiseTexCoord = (vec2(gl_LaunchIDEXT.x, gl_LaunchIDEXT.y) + 0.5) / texSize;
	vec4 tex = texture(textures[nonuniformEXT(noiseTexIndex+BLUE_NOISE_TEXTURES_OFFSET)], noiseTexCoord);
	return vec4(tex.rgb * 2 - 1, tex.a);
}

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
			if ((xenonRendererData.config.options & RENDER_OPTION_GROUND_TRUTH) != 0) {
				#ifdef USE_BLUE_NOISE
					vec2 rnd = GetBlueNoiseFloat2();
				#else
					vec2 rnd = vec2(RandomFloat(seed), RandomFloat(seed));
				#endif
				float pointRadius = lightsRadius[i] / lightsDistance[i] * rnd.x;
				float pointAngle = rnd.y * 2.0 * PI;
				vec2 diskPoint = vec2(pointRadius * cos(pointAngle), pointRadius * sin(pointAngle));
				vec3 lightTangent = normalize(cross(shadowRayDir, normal));
				vec3 lightBitangent = normalize(cross(lightTangent, shadowRayDir));
				shadowRayDir = normalize(shadowRayDir + diskPoint.x * lightTangent + diskPoint.y * lightBitangent);
			}
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
					
					if (++usefulLights == 2) {
						ray = originalRay;
						return directLighting;
					}
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

// // FOR SSR
// vec3 GetScreenCoordFromViewSpacePosition(vec3 viewSpacePosition) {
// 	vec4 coord = xenonRendererData.config.projectionMatrix * vec4(viewSpacePosition, 1);
// 	coord.xyz /= coord.w;
// 	return coord.xyz * 0.5 + 0.5;
// }
// vec2 RandomInUnitSquare(inout uint seed) {
// 	return 2 * vec2(RandomFloat(seed), RandomFloat(seed)) - 1;
// }
// float GetDistance(vec2 uv) {
// 	float dist = texture(sampler_motion, uv).a;
// 	dist = max(dist, textureLodOffset(sampler_motion, uv, 0.0, ivec2( 1,  0)).a);
// 	dist = max(dist, textureLodOffset(sampler_motion, uv, 0.0, ivec2(-1,  0)).a);
// 	dist = max(dist, textureLodOffset(sampler_motion, uv, 0.0, ivec2( 0,  1)).a);
// 	dist = max(dist, textureLodOffset(sampler_motion, uv, 0.0, ivec2( 0, -1)).a);
// 	dist = max(dist, textureLodOffset(sampler_motion, uv, 0.0, ivec2( 1,  1)).a);
// 	dist = max(dist, textureLodOffset(sampler_motion, uv, 0.0, ivec2(-1, -1)).a);
// 	dist = max(dist, textureLodOffset(sampler_motion, uv, 0.0, ivec2( 1, -1)).a);
// 	dist = max(dist, textureLodOffset(sampler_motion, uv, 0.0, ivec2(-1,  1)).a);
// 	return dist;
// }

void ApplyDefaultLighting(in uint giObjectIndex, in vec3 giPos, in vec3 giRayOrigin, in float giVoxelSize) {
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
	
	if ((xenonRendererData.config.options & RENDER_OPTION_GROUND_TRUTH) != 0) {
		if (recursions < renderer.rays_max_bounces) {
			RayPayload originalRay = ray;
			vec3 rayOrigin = originalRay.worldPosition + originalRay.normal * max(2.0, originalRay.hitDistance) * EPSILON;
			
			// Path Tracing
			vec3 reflectDirection = reflect(gl_WorldRayDirectionEXT, originalRay.normal);
			vec3 randomDirection = normalize(RandomInUnitHemiSphere(seed, originalRay.normal));
			vec3 bounceDirection;
			if (RandomFloat(seed) < fresnel) {
				bounceDirection = normalize(mix(reflectDirection, randomDirection, min(0.5, surface.roughness*surface.roughness)));
			} else {
				bounceDirection = randomDirection;
			}
			RAY_RECURSION_PUSH
				RAY_GI_PUSH
					float transparency = 1;
					do {
						traceRayEXT(tlas, gl_RayFlagsCullBackFacingTrianglesEXT|gl_RayFlagsOpaqueEXT, RAYTRACE_MASK_TERRAIN|RAYTRACE_MASK_ENTITY|RAYTRACE_MASK_CLUTTER|RAYTRACE_MASK_ATMOSPHERE|RAYTRACE_MASK_HYDROSPHERE|RAYTRACE_MASK_PLASMA, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, rayOrigin, 0, bounceDirection, xenonRendererData.config.zFar, 0);
						ray.color.rgb *= transparency;
						rayOrigin += bounceDirection * ray.hitDistance - ray.normal * max(2.0, ray.hitDistance) * EPSILON;
						transparency *= 1.0 - clamp(ray.color.a, 0, 1);
					} while (transparency > 0.1 && ray.hitDistance > 0);
				RAY_GI_POP
			RAY_RECURSION_POP
			ray.color.rgb += ray.plasma.rgb;
			originalRay.color.rgb += ray.color.rgb * albedo;
			ray = originalRay;
		}
	} else {
		if (surface.metallic > 0.1 && surface.roughness < 0.1) {
			
			if (recursions < renderer.rays_max_bounces) {
				RayPayload originalRay = ray;
				vec3 rayOrigin = originalRay.worldPosition + originalRay.normal * max(2.0, originalRay.hitDistance) * EPSILON;
				vec3 reflectDirection = reflect(gl_WorldRayDirectionEXT, originalRay.normal);
				// vec3 randomDirection = normalize(RandomInUnitHemiSphere(seed, originalRay.normal));
				// reflectDirection = normalize(mix(reflectDirection, randomDirection, 0.5*surface.roughness*surface.roughness));
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
			
			// // SSR
			// float reflectionBlur = surface.roughness*surface.roughness;
			// float mirror = clamp(1 - reflectionBlur, 0, 1);
			// const vec3 startViewSpacePos = (renderer.viewMatrix * vec4(ray.worldPosition, 1)).xyz;
			// const vec3 startScreenSpaceCoord = GetScreenCoordFromViewSpacePosition(startViewSpacePos);
			// vec3 viewSpacePos = startViewSpacePos;
			// const vec2 screenSize = textureSize(sampler_history, 0);
			// const float fragSize = 1.0 / min(screenSize.x, screenSize.y);
			// const vec3 normal = normalize(WORLD2VIEWNORMAL * ray.normal);
			// vec3 viewSpaceReflectionDir = normalize(reflect(normalize(startViewSpacePos), normal));
			// const float stepSizeViewSpace = 0.1;
			// const int maxSteps = 100;
			// vec2 uv = vec2(0);
			// for (int i = 0; i < maxSteps; ++i) {
			// 	viewSpacePos += viewSpaceReflectionDir * stepSizeViewSpace;
			// 	uv = GetScreenCoordFromViewSpacePosition(viewSpacePos).xy;
			// 	if (uv.x < 0 || uv.x > 1 || uv.y < 0 || uv.y > 1) break;
			// 	float dist = GetDistance(uv);
			// 	if (viewSpacePos.z > dist) {
			// 		break;
			// 	}
			// }
			// vec3 reflected = vec3(0);
			// float accumulation = 1;
			// if (uv.x <= 0 || uv.x > 1 || uv.y <= 0 || uv.y > 1) {
			// } else {
			// 	reflected += clamp(texture(sampler_history, uv).rgb, 0, xenonRendererData.histogram_avg_luminance.a);
			// }
			// ++accumulation;
			// ray.color.rgb = reflected / accumulation;
			
		} else 
		if ((renderer.options & RENDERER_OPTION_INDIRECT_LIGHTING) != 0) {// Global Illumination
			vec3 rayOrigin = ray.worldPosition + ray.normal * 0.001;
			const ivec3 iPos = ivec3(round(giPos));
			const uint giIndex = GetGiIndex(giObjectIndex, iPos);
			seed += recursions * RAY_MAX_RECURSION;
			if ((!rayIsGi || !rayIsUnderWater) && realDistance < GI_MAX_DISTANCE && recursions < min(RAY_MAX_RECURSION, renderer.rays_max_bounces + 1) && LockAmbientLighting0(giIndex)) {
				
				// rayQueryEXT rq;
				// rayQueryInitializeEXT(rq, tlas, gl_RayFlagsTerminateOnFirstHitEXT, RAYTRACE_MASK_TERRAIN|RAYTRACE_MASK_ENTITY, rayOrigin, 0, normalize(giRayOrigin - rayOrigin), distance(rayOrigin, giRayOrigin) + 0.0001);
				// if (rayQueryProceedEXT(rq)) {
				// 	WriteAmbientLighting0(giIndex, giObjectIndex, iPos, vec3(0));
				// 	// WriteAmbientLighting1(giObjectIndex, iPos, vec3(0), 1.0);
				// 	// for (int i = 0; i < nbAdjacentSides; ++i) {
				// 	// 	WriteAmbientLighting1(giObjectIndex, iPos + adjacentSides[i], vec3(0), 1.0);
				// 	// }
				// } else {
				// 	rayOrigin = giRayOrigin;
					
					RayPayload originalRay = ray;
					vec3 bounceDirection = normalize(RandomInUnitHemiSphere(seed, originalRay.normal));
					float bestSampleProbability = pow(RandomFloat(seed), 2.0);
					vec3 reflectDirection = reflect(gl_WorldRayDirectionEXT, originalRay.normal);
					const float reflectionDirBias = 0.8;
					bounceDirection = normalize(reflectDirection * reflectionDirBias + mix(GetGi(giIndex).bestSample.xyz, bounceDirection, bestSampleProbability));
					float nDotL = clamp(dot(originalRay.normal, bounceDirection), 0, 1);
					if (nDotL < 0.001) {
						bounceDirection = normalize(originalRay.normal + reflectDirection);
					}
					RAY_RECURSION_PUSH
						RAY_GI_PUSH
							float transparency = 1;
							do {
								traceRayEXT(tlas, gl_RayFlagsOpaqueEXT, RAYTRACE_MASK_TERRAIN|RAYTRACE_MASK_ENTITY|RAYTRACE_MASK_ATMOSPHERE|RAYTRACE_MASK_PLASMA|RAYTRACE_MASK_LIGHT, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, rayOrigin, 0, bounceDirection, max(ATMOSPHERE_RAY_MIN_DISTANCE, GI_MAX_DISTANCE), 0);
								ray.color.rgb += ray.plasma.rgb;
								ray.color.rgb *= transparency;
								rayOrigin += bounceDirection * (ray.hitDistance + ray.t2) - ray.normal * max(2.0, ray.hitDistance) * EPSILON;
								transparency *= 1.0 - clamp(ray.color.a, 0, 1);
							} while (transparency > 0.1 && ray.hitDistance > 0);
						RAY_GI_POP
					RAY_RECURSION_POP
					ray.color.rgb *= pow(1-clamp(realDistance / GI_MAX_DISTANCE, 0, 1), 2.0) * bestSampleProbability;
					vec3 l = WriteAmbientLighting0(giIndex, giObjectIndex, iPos, ApplyGamma(ray.color.rgb) * renderer.globalLightingFactor);
					if (!rayIsGi) {
						l = WriteAmbientLighting1(giObjectIndex, iPos, l, 1.0);
						for (int i = 0; i < nbAdjacentSides; ++i) {
							// rayQueryEXT rqAdjacency;
							// rayQueryInitializeEXT(rqAdjacency, tlas, gl_RayFlagsTerminateOnFirstHitEXT, RAYTRACE_MASK_TERRAIN|RAYTRACE_MASK_ENTITY, giRayOrigin, 0, normalize(MODEL2WORLDNORMAL * normalize(vec3(adjacentSides[i]))), length(vec3(adjacentSides[i])) * (giVoxelSize + 0.00001));
							// if (!rayQueryProceedEXT(rqAdjacency)) {
								WriteAmbientLighting1(giObjectIndex, iPos + adjacentSides[i], l, 1.0);
							// } else {
							// 	WriteAmbientLighting1(giObjectIndex, iPos + adjacentSides[i], l*0.5, 0.125);
							// }
						}
					}
					
					float luminance = dot(ray.color.rgb, vec3(0.2126, 0.7152, 0.0722));
					GetGi(giIndex).bestSample = mix(GetGi(giIndex).bestSample, vec4(bounceDirection, luminance), clamp(luminance / max(1, luminance + GetGi(giIndex).bestSample.a), 0, 1));
					ray = originalRay;
					
				// }
				
				UnlockAmbientLighting0(giIndex);
			}
			if (!rayIsGi) {
				vec3 ambient = vec3(0);
				if (recursions < renderer.rays_max_bounces && realDistance >= GI_MAX_DISTANCE/2) {
					RayPayload originalRay = ray;
					vec3 bounceDirection = RandomCosineOnHemisphere(originalRay.normal);
					RAY_RECURSION_PUSH
						RAY_GI_PUSH
							traceRayEXT(tlas, gl_RayFlagsOpaqueEXT, RAYTRACE_MASK_TERRAIN|RAYTRACE_MASK_ATMOSPHERE|RAYTRACE_MASK_HYDROSPHERE|RAYTRACE_MASK_ENTITY, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, originalRay.worldPosition, originalRay.hitDistance * 0.001, bounceDirection, 10000, 0);
							ambient = pow(ray.color.rgb, vec3(0.5)) * 0.25;
						RAY_GI_POP
					RAY_RECURSION_POP
					ray = originalRay;
				}
				float giFactor = smoothstep(GI_MAX_DISTANCE, GI_MAX_DISTANCE/2, realDistance);
				if (giFactor > 0) {
					vec3 ambientGi = GetAmbientLighting(giObjectIndex, giPos);
					if (ambientGi.x < 0) {
						RAY_RECURSION_PUSH
							RAY_GI_PUSH
								RayPayload originalRay = ray;
								rayOrigin = originalRay.worldPosition + originalRay.normal * max(2.0, originalRay.hitDistance) * EPSILON;
								vec3 bounceDirection = RandomCosineOnHemisphere(originalRay.normal);
								traceRayEXT(tlas, gl_RayFlagsOpaqueEXT, RAYTRACE_MASK_TERRAIN|RAYTRACE_MASK_ENTITY|RAYTRACE_MASK_ATMOSPHERE|RAYTRACE_MASK_HYDROSPHERE|RAYTRACE_MASK_PLASMA, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, rayOrigin, 0, bounceDirection, max(ATMOSPHERE_RAY_MIN_DISTANCE, GI_MAX_DISTANCE), 0);
								ambientGi = ray.color.rgb;
								ray = originalRay;
							RAY_GI_POP
						RAY_RECURSION_POP
					} else {
						ambientGi = ReverseGamma(ambientGi);
					}
					ambient = mix(ambient, ambientGi * renderer.globalLightingFactor, giFactor);
					if (recursions == 0 && xenonRendererData.config.debugViewMode == RENDERER_DEBUG_VIEWMODE_GLOBAL_ILLUMINATION) {
						imageStore(img_normal_or_debug, COORDS, vec4(ambient * xenonRendererData.config.debugViewScale, 1));
					}
				}
				ray.color.rgb += albedo * ambient;
			}
		} else {
			ray.color.rgb += albedo * vec3(pow(smoothstep(GI_MAX_DISTANCE*2, 0, realDistance), 4)) * 0.1;
		}
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
