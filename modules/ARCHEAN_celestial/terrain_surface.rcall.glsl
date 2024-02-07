#extension GL_EXT_ray_tracing : require

#define SHADER_SURFACE
#include "terrain.common.inc.glsl"
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

ChunkBuffer chunk = ChunkBuffer(surface.geometryInfoData);

vec4 ComputeSplat(in uint64_t geometries, in uint geometryIndex, in uint primitiveID, in vec3 barycentricCoordsOrLocalPosition) {
	GeometryData geometry = GeometryData(geometries)[nonuniformEXT(geometryIndex)];
	if (uint64_t(chunk.splats) != 0) {
		uint index0 = primitiveID * 3;
		uint index1 = primitiveID * 3 + 1;
		uint index2 = primitiveID * 3 + 2;
		if (geometry.indices16 != 0) {
			index0 = IndexBuffer16(geometry.indices16).indices[nonuniformEXT(index0)];
			index1 = IndexBuffer16(geometry.indices16).indices[nonuniformEXT(index1)];
			index2 = IndexBuffer16(geometry.indices16).indices[nonuniformEXT(index2)];
		} else if (geometry.indices32 != 0) {
			index0 = IndexBuffer32(geometry.indices32).indices[nonuniformEXT(index0)];
			index1 = IndexBuffer32(geometry.indices32).indices[nonuniformEXT(index1)];
			index2 = IndexBuffer32(geometry.indices32).indices[nonuniformEXT(index2)];
		}
		return clamp(
			+ vec4(chunk.splats[nonuniformEXT(index0)].splat) / 255.0 * barycentricCoordsOrLocalPosition.x
			+ vec4(chunk.splats[nonuniformEXT(index1)].splat) / 255.0 * barycentricCoordsOrLocalPosition.y
			+ vec4(chunk.splats[nonuniformEXT(index2)].splat) / 255.0 * barycentricCoordsOrLocalPosition.z
		, vec4(0), vec4(1));
	} else {
		return vec4(0);
	}
}

float ComputeTemperature(in uint64_t geometries, in uint geometryIndex, in uint primitiveID, in vec3 barycentricCoordsOrLocalPosition) {
	GeometryData geometry = GeometryData(geometries)[nonuniformEXT(geometryIndex)];
	if (uint64_t(chunk.temperature) != 0) {
		uint index0 = primitiveID * 3;
		uint index1 = primitiveID * 3 + 1;
		uint index2 = primitiveID * 3 + 2;
		if (geometry.indices16 != 0) {
			index0 = IndexBuffer16(geometry.indices16).indices[nonuniformEXT(index0)];
			index1 = IndexBuffer16(geometry.indices16).indices[nonuniformEXT(index1)];
			index2 = IndexBuffer16(geometry.indices16).indices[nonuniformEXT(index2)];
		} else if (geometry.indices32 != 0) {
			index0 = IndexBuffer32(geometry.indices32).indices[nonuniformEXT(index0)];
			index1 = IndexBuffer32(geometry.indices32).indices[nonuniformEXT(index1)];
			index2 = IndexBuffer32(geometry.indices32).indices[nonuniformEXT(index2)];
		}
		return
			+ chunk.temperature[nonuniformEXT(index0)].temperature * barycentricCoordsOrLocalPosition.x
			+ chunk.temperature[nonuniformEXT(index1)].temperature * barycentricCoordsOrLocalPosition.y
			+ chunk.temperature[nonuniformEXT(index2)].temperature * barycentricCoordsOrLocalPosition.z
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

void main() {
	surface.uv1 = ComputeSurfaceUV1(surface.geometries, surface.geometryIndex, surface.primitiveIndex, surface.barycentricCoords);
	dvec2 uvD = (chunk.uvOffset + dvec2(surface.uv1) * chunk.uvMult) * chunk.planetFaceSize;
	
	// Lava
	float temperature = ComputeTemperature(surface.geometries, surface.geometryIndex, surface.primitiveIndex, surface.barycentricCoords);
	if (temperature > 1000) {
		surface.emission = ReverseGamma(GetLava(vec2((uvD - volcanoCenterUV) / 100))) * smoothCurve(temperature / 2000);
		surface.color.rgb = vec3(0);
		return;
	}
	
	if (surface.distance > textureMaxDistance) {
		return;
	}
	
	vec4 splat = ComputeSplat(surface.geometries, surface.geometryIndex, surface.primitiveIndex, surface.barycentricCoords);
	vec2 uvNear = vec2(fract(uvD / NEAR_TEXTURE_SPAN_METERS));
	vec2 uvFar = vec2(fract(uvD / FAR_TEXTURE_SPAN_METERS));
	
	vec3 normal = surface.normal;
	
	float textureMaxDistanceRatio = pow(clamp(surface.distance / textureMaxDistance, 0, 1), 0.25);
	float textureNearDistanceRatio = pow(smoothstep(textureNearDistance, textureFarDistance, surface.distance), 0.25);
	
	// Base terrain
	BUMP(NormalDetail, surface.localPosition * 20, surface.normal, 0.025)
	surface.normal = mix(surface.normal, normal, pow(clamp(surface.distance / textureNormalMaxDistance, 0, 1), 0.25));
	surface.color.rgb *= mix(pow(clamp(NormalDetail(surface.localPosition * 100) + 1, 0, 1), 0.5), 1, textureMaxDistanceRatio);
	vec3 disturbedNormal = surface.normal;
	
	vec3 color = surface.color.rgb;
	
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
			surface.color.rgb = mix(color, mix(colorNear, colorFar, textureNearDistanceRatio), blend);
			// surface.color.rgb = mix(color, colorNear, splats[i] * (1 - textureMaxDistanceRatio));
			// Specular
			float specularNear = texture(textures[nonuniformEXT(speculars[i])], uvNear).r;
			// float specularFar = texture(textures[nonuniformEXT(speculars[i] + 1)], uvFar).r;
			// surface.specular = mix(surface.specular, mix(specularNear, specularFar, textureNearDistanceRatio), splats[i] * (1 - textureMaxDistanceRatio));
			surface.specular = mix(surface.specular, specularNear, splats[i] * (1 - textureMaxDistanceRatio));
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
				surface.normal = normalize(mix(disturbedNormal, TBN * bump, blend));
			}
		}
	}
}
