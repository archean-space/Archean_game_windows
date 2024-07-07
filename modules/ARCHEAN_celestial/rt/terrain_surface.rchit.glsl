#define SHADER_RCHIT
#include "game/graphics/common.inc.glsl"

#define Color 0
#define Height 2
#define Specular 4

#define NEAR_TEXTURE_SPAN_METERS 4.0
#define FAR_TEXTURE_SPAN_METERS 64.0

#define SMOOTH_SHADING_TRIANGLE_SIZE_THRESHOLD 0.5

// #define TERRAIN_MESH_GENERATE_SMOOTH_NORMALS

#define TERRAIN_FEATURE_LAVA 1
#define TERRAIN_FEATURE_VOLCANO 2
#define TERRAIN_FEATURE_WAVY_SAND 3

BUFFER_REFERENCE_STRUCT(4) TerrainSplatBuffer {
	u8vec4 splat;
};

BUFFER_REFERENCE_STRUCT(4) TemperatureBuffer {
	float temperature;
};

BUFFER_REFERENCE_STRUCT(16) ChunkBuffer {
	aligned_f64mat4 transform;
	aligned_f64mat4 inverseTransform;
	aligned_u32vec4 tex;
	aligned_float32_t skirtOffset;
	aligned_float32_t triangleSize;
	aligned_int32_t topSign;
	aligned_int32_t rightSign;
	aligned_float32_t chunkSize;
	aligned_uint32_t vertexSubdivisions;
	BUFFER_REFERENCE_ADDR(TerrainSplatBuffer) splats;
	aligned_f64vec2 uvOffset;
	aligned_float64_t uvMult;
	aligned_float64_t planetFaceSize;
	aligned_f32vec4 texHeightDisplacement;
	aligned_f32vec4 texBumpNormalDisplacement;
	BUFFER_REFERENCE_ADDR(TemperatureBuffer) temperature;
};

#include "xenon/renderer/shaders/perlint.inc.glsl"

float NormalDetail(in vec3 pos) {
	return (SimplexFractal(pos, 3) + SimplexFractal(pos * 2, 3)) * 0.5;
}

#define BUMP(_noiseFunc, _position, _normal, _waveLength) {\
	vec3 _tangentZ = normalize(cross(vec3(1,0,0), _normal));\
	vec3 _tangentX = normalize(cross(_normal, _tangentZ));\
	mat3 _TBN = mat3(_tangentX, _normal, _tangentZ);\
	float _altitudeTop = _noiseFunc(_position + _tangentZ*_waveLength);\
	float _altitudeBottom = _noiseFunc(_position - _tangentZ*_waveLength);\
	float _altitudeRight = _noiseFunc(_position + _tangentX*_waveLength);\
	float _altitudeLeft = _noiseFunc(_position - _tangentX*_waveLength);\
	vec3 _bump = normalize(vec3((_altitudeLeft-_altitudeRight), 1, (_altitudeBottom-_altitudeTop)));\
	_normal = normalize(_TBN * _bump);\
}

const float textureNearDistance = 0;
const float textureFarDistance = 32;
const float textureNormalMaxDistance = 32;
const float textureMaxDistance = 500;

ChunkBuffer chunk = ChunkBuffer(GEOMETRY.material.data);

vec4 ComputeSplat(in uint64_t geometries, in uint geometryIndex, in uint primitiveID, in vec3 barycentricCoordsOrLocalPosition) {
	GeometryData geometry = GeometryData(geometries)[geometryIndex];
	if (uint64_t(chunk.splats) != 0) {
		uint index0 = primitiveID * 3;
		uint index1 = primitiveID * 3 + 1;
		uint index2 = primitiveID * 3 + 2;
		if (geometry.indices16 != 0) {
			index0 = IndexBuffer16(geometry.indices16).indices[index0];
			index1 = IndexBuffer16(geometry.indices16).indices[index1];
			index2 = IndexBuffer16(geometry.indices16).indices[index2];
		} else if (geometry.indices32 != 0) {
			index0 = IndexBuffer32(geometry.indices32).indices[index0];
			index1 = IndexBuffer32(geometry.indices32).indices[index1];
			index2 = IndexBuffer32(geometry.indices32).indices[index2];
		}
		return clamp(
			+ vec4(chunk.splats[index0].splat) / 255.0 * barycentricCoordsOrLocalPosition.x
			+ vec4(chunk.splats[index1].splat) / 255.0 * barycentricCoordsOrLocalPosition.y
			+ vec4(chunk.splats[index2].splat) / 255.0 * barycentricCoordsOrLocalPosition.z
		, vec4(0), vec4(1));
	} else {
		return vec4(0);
	}
}

float ComputeTemperature(in uint64_t geometries, in uint geometryIndex, in uint primitiveID, in vec3 barycentricCoordsOrLocalPosition) {
	GeometryData geometry = GeometryData(geometries)[geometryIndex];
	if (uint64_t(chunk.temperature) != 0) {
		uint index0 = primitiveID * 3;
		uint index1 = primitiveID * 3 + 1;
		uint index2 = primitiveID * 3 + 2;
		if (geometry.indices16 != 0) {
			index0 = IndexBuffer16(geometry.indices16).indices[index0];
			index1 = IndexBuffer16(geometry.indices16).indices[index1];
			index2 = IndexBuffer16(geometry.indices16).indices[index2];
		} else if (geometry.indices32 != 0) {
			index0 = IndexBuffer32(geometry.indices32).indices[index0];
			index1 = IndexBuffer32(geometry.indices32).indices[index1];
			index2 = IndexBuffer32(geometry.indices32).indices[index2];
		}
		return
			+ chunk.temperature[index0].temperature * barycentricCoordsOrLocalPosition.x
			+ chunk.temperature[index1].temperature * barycentricCoordsOrLocalPosition.y
			+ chunk.temperature[index2].temperature * barycentricCoordsOrLocalPosition.z
		;
	} else {
		return 0;
	}
}

dvec2 volcanoCenterUV = dvec2(1727000, 6820000);


// Lava
mat2 rot(float a){
	return mat2(cos(a),sin(a),-sin(a),cos(a));
}
float hash21(vec2 n) {
	return fract(cos(dot(n, vec2(5.9898, 4.1414))) * 65899.89956);
}
float noise(in vec2 n) {
	const vec2 d = vec2(0.0, 1.0);
	vec2 b = floor(n);
	vec2 f = smoothstep(vec2(0.), vec2(1), fract(n));
	return mix(mix(hash21(b), hash21(b + d.yx), f.x), mix(hash21(b + d.xy), hash21(b + d.yy), f.x), f.y);
}
vec2 mixNoise(vec2 p) {
	float epsilon = .968785675;
	float noiseX = noise(vec2(p.x+epsilon,p.y))-noise(vec2(p.x-epsilon,p.y));
	float noiseY = noise(vec2(p.x,p.y+epsilon))-noise(vec2(p.x,p.y-epsilon));
	return vec2(noiseX,noiseY);
}
float fbm(in vec2 p) {
	float amplitude=3.;
	float total = 0.;
	vec2 pom = p;
	float iTime = float(xenonRendererData.time * 0.25);
	for (float i= 1.3232;i < 7.45;i++) {
		p += iTime*0.1;
		pom+=iTime*0.03;
		vec2 n= mixNoise(i*p*.3244243+iTime*.131321);
		n*=rot(iTime*.5-(0.03456*p.x+0.0342322*p.y)*50.);
		p += n*.5;
		total+= (sin(noise(p)*8.5)*0.55+0.4566)/amplitude;
		
		p = mix(pom,p,0.5);
		
		amplitude *= 1.3;
		
		p *= 2.007556;
		pom *= 1.6895367;
	}
	return total;
}
vec3 GetLava(in vec2 uv) {
	float fbm = fbm(uv);
	vec3 col = vec3(.212,0.08,0.03)/max(fbm, 0.0001);
	col = pow(col,vec3(1.5));
	return col;
}


hitAttributeEXT vec2 hitAttribs;
vec3 barycentricCoords = vec3(1.0f - hitAttribs.x - hitAttribs.y, hitAttribs.x, hitAttribs.y);

void main() {
	vec3 albedo = ComputeSurfaceColor(barycentricCoords).rgb;
	vec3 normal = ComputeSurfaceNormal(barycentricCoords);
	vec3 emission = vec3(0);
	vec3 localPosition = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * gl_HitTEXT;
	dvec2 uvD = (chunk.uvOffset + dvec2(ComputeSurfaceUV1(barycentricCoords)) * chunk.uvMult) * chunk.planetFaceSize;
	float specular = 0;
	
	MakeAimable(normal, vec2(0), 0);
	
	// Lava
	float temperature = ComputeTemperature(uint64_t(INSTANCE.geometries), gl_GeometryIndexEXT, gl_PrimitiveID, barycentricCoords);
	if (temperature > 1000) {
		emission = ReverseGamma(GetLava(vec2((uvD - volcanoCenterUV) / 100))) * smoothCurve(temperature / 2000);
		albedo = vec3(0);
	} else if (gl_HitTEXT < textureMaxDistance) {
	
		vec4 splat = ComputeSplat(uint64_t(INSTANCE.geometries), gl_GeometryIndexEXT, gl_PrimitiveID, barycentricCoords);
		vec2 uvNear = vec2(fract(uvD / NEAR_TEXTURE_SPAN_METERS));
		vec2 uvFar = vec2(fract(uvD / FAR_TEXTURE_SPAN_METERS));
		
		float textureMaxDistanceRatio = pow(clamp(gl_HitTEXT / textureMaxDistance, 0, 1), 0.5);
		float textureNearDistanceRatio = pow(smoothstep(textureNearDistance, textureFarDistance, gl_HitTEXT), 0.5);
		
		// Base terrain
		vec3 surfaceNormal = normal;
		BUMP(NormalDetail, localPosition * 20, surfaceNormal, 0.01)
		normal = mix(surfaceNormal, normal, pow(clamp(gl_HitTEXT / textureNormalMaxDistance, 0, 1), 0.5));
		albedo *= mix(pow(clamp(NormalDetail(localPosition * 100) + 1, 0, 1), 0.5), 1, textureMaxDistanceRatio);
		vec3 disturbedNormal = normal;
		
		vec3 color = albedo;
		
		float splats[4];
		float blending[4];
		float displacement[4];
		float bumpDisplacement[4];
		uint colors[4];
		uint heights[4];
		uint speculars[4];
		
		splats[0] = smoothCurve(splat.x);
		displacement[0] = texture(textures[nonuniformEXT(chunk.tex.x + Height)], uvNear).r;
		blending[0] = splats[0] * displacement[0];
		if (blending[0] > 0) {
			bumpDisplacement[0] = chunk.texBumpNormalDisplacement.x * blending[0];
			colors[0] = chunk.tex.x + Color;
			heights[0] = chunk.tex.x + Height;
			speculars[0] = chunk.tex.x + Specular;
		}
		
		splats[1] = smoothCurve(splat.y);
		displacement[1] = texture(textures[nonuniformEXT(chunk.tex.y + Height)], uvNear).r;
		blending[1] = splats[1] * displacement[1];
		if (blending[1] > 0) {
			bumpDisplacement[1] = chunk.texBumpNormalDisplacement.y * blending[1];
			colors[1] = chunk.tex.y + Color;
			heights[1] = chunk.tex.y + Height;
			speculars[1] = chunk.tex.y + Specular;
		}
		
		splats[2] = smoothCurve(splat.z);
		displacement[2] = texture(textures[nonuniformEXT(chunk.tex.z + Height)], uvNear).r;
		blending[2] = splats[2] * displacement[2];
		if (blending[2] > 0) {
			bumpDisplacement[2] = chunk.texBumpNormalDisplacement.z * blending[2];
			colors[2] = chunk.tex.z + Color;
			heights[2] = chunk.tex.z + Height;
			speculars[2] = chunk.tex.z + Specular;
		}
		
		splats[3] = smoothCurve(splat.w);
		displacement[3] = texture(textures[nonuniformEXT(chunk.tex.w + Height)], uvNear).r;
		blending[3] = splats[3] * displacement[3];
		if (blending[3] > 0) {
			bumpDisplacement[3] = chunk.texBumpNormalDisplacement.w * blending[3];
			colors[3] = chunk.tex.w + Color;
			heights[3] = chunk.tex.w + Height;
			speculars[3] = chunk.tex.w + Specular;
		}
		
		float maxBlending = 0;
		for (int i = 0; i < 4; ++i) {
			if (blending[i] > maxBlending) {
				vec2 texSize = textureSize(textures[nonuniformEXT(heights[i])], 0);
				maxBlending = blending[i];
				float blend = smoothCurve(smoothCurve(pow(blending[i], 0.0625) * (1 - textureMaxDistanceRatio)));
				// Color
				vec3 colorNear = texture(textures[nonuniformEXT(colors[i])], uvNear).rgb;
				vec3 colorFar = texture(textures[nonuniformEXT(colors[i] + 1)], uvFar).rgb;
				albedo = mix(color, mix(colorNear, colorFar, textureNearDistanceRatio), blend);
				// albedo = mix(color, colorNear, splats[i] * (1 - textureMaxDistanceRatio));
				// Specular
				float specularNear = texture(textures[nonuniformEXT(speculars[i])], uvNear).r;
				// float specularFar = texture(textures[nonuniformEXT(speculars[i] + 1)], uvFar).r;
				// specular = mix(specular, mix(specularNear, specularFar, textureNearDistanceRatio), splats[i] * (1 - textureMaxDistanceRatio));
				specular = mix(specular, specularNear, splats[i] * (1 - textureMaxDistanceRatio));
				// Normal
				if (bumpDisplacement[i] > 0) {
					float bumpTextureMeterPerPixel = NEAR_TEXTURE_SPAN_METERS / texSize.x;
					float altitudeTop = textureOffset(textures[nonuniformEXT(heights[i])], uvNear, ivec2(0,-1)).r;
					float altitudeBottom = textureOffset(textures[nonuniformEXT(heights[i])], uvNear, ivec2(0,+1)).r;
					float altitudeLeft = textureOffset(textures[nonuniformEXT(heights[i])], uvNear, ivec2(-1,0)).r;
					float altitudeRight = textureOffset(textures[nonuniformEXT(heights[i])], uvNear, ivec2(+1,0)).r;
					vec3 bump = normalize(vec3((altitudeLeft-altitudeRight), bumpTextureMeterPerPixel / bumpDisplacement[i], (altitudeBottom-altitudeTop)));
					vec3 tangentZ = normalize(cross(vec3(1,0,0), normal));
					vec3 tangentX = normalize(cross(normal, tangentZ));
					mat3 TBN = mat3(tangentX, normal, tangentZ);
					normal = normalize(mix(disturbedNormal, TBN * bump, blend));
				}
			}
		}
	}
	
	// Reverse gamma
	albedo = ReverseGamma(albedo);
	
	// Fix black specs caused by skirts
	if (dot(normal, vec3(0,1,0)) < 0.15) normal = vec3(0,1,0);

	if (dot(emission, emission) > 0) {
		RayHit(
			/*albedo*/		emission,
			/*normal*/		normal,
			/*distance*/	gl_HitTEXT,
			/*roughness*/	1.0,
			/*ior*/			1.5,
			RAY_SURFACE_EMISSIVE
		);
	} else {
		RayHit(
			/*albedo*/		albedo,
			/*normal*/		normal,
			/*distance*/	gl_HitTEXT,
			/*roughness*/	1.0,
			/*ior*/			1.5,
			RAY_SURFACE_DIFFUSE
		);
	}
	
}
