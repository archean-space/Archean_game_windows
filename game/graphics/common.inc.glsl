#ifdef __cplusplus
	#pragma once
#endif

#include "xenon/renderer/shaders/common.inc.glsl"

#define RENDERABLE_TYPE_TERRAIN_TRI 0
#define RENDERABLE_TYPE_ENTITY_TRI 1
#define RENDERABLE_TYPE_ENTITY_BOX 2
#define RENDERABLE_TYPE_ENTITY_SPHERE 3
#define RENDERABLE_TYPE_ATMOSPHERE 4
#define RENDERABLE_TYPE_HYDROSPHERE 5
#define RENDERABLE_TYPE_ENTITY_VOXEL 6
#define RENDERABLE_TYPE_CLUTTER_TRI 7
#define RENDERABLE_TYPE_PLASMA 8
#define RENDERABLE_TYPE_LIGHT_BOX 9
#define RENDERABLE_TYPE_CLUTTER_PIPE 10
#define RENDERABLE_TYPE_CLUTTER_ROCK 11
#define RENDERABLE_TYPE_PROPELLER 12
#define RENDERABLE_TYPE_CLUTTER_BOX 13
#define RENDERABLE_TYPE_CLOUD 14

#define SURFACE_CALLABLE_PAYLOAD 0
#define VOXEL_SURFACE_CALLABLE_PAYLOAD 1

#define LIGHT_LUMINOSITY_VISIBLE_THRESHOLD 0.05

// Up to 32 flags
#define PIPE_FLAG_BOX			(1u << 0)
#define PIPE_FLAG_CAPSULE		(1u << 1)
#define PIPE_FLAG_STRIPES		(1u << 2)
#define PIPE_FLAG_CHROME		(1u << 3)
#define PIPE_FLAG_GLOSSY		(1u << 5)
#define PIPE_FLAG_FLEXIBLE		(1u << 6)
#define PIPE_FLAG_METAL			(1u << 7)

// Up to 16 flags
#define PLASMA_FLAG_AEROSPIKE	(1u << 0)
#define PLASMA_FLAG_SHAKE 		(1u << 1)

BUFFER_REFERENCE_STRUCT_READONLY(16) AabbData {
	aligned_float32_t aabb[6];
	aligned_uint64_t data; // Arbitrary data defined per-shader
};
STATIC_ASSERT_ALIGNED16_SIZE(AabbData, 32)

struct SunData {
	vec3 position;
	float radius;
	vec3 color;
	float temperature;
};
STATIC_ASSERT_ALIGNED16_SIZE(SunData, 32)

// This is per geometry, not per renderable, and is unique to each individual instance
BUFFER_REFERENCE_STRUCT_READONLY(16) RenderableData {
	aligned_f32vec3 emission; // always added to output color
	aligned_float32_t colorMix; // 0 means don't use this color, 1 means use this color fully, values between (0-1) means mix between material's color and this custom color
	aligned_f32vec4 color;
	aligned_float32_t pbrMix;
	aligned_float32_t pbrMetallic;
	aligned_float32_t pbrRoughness;
	aligned_uint32_t monitorIndex; // matches with a texture index, 0 means not a monitor and don't load any texture
	aligned_f32vec4 customVec4Data; // unused in game, reserved for modules
};
STATIC_ASSERT_ALIGNED16_SIZE(RenderableData, 64)

BUFFER_REFERENCE_STRUCT_READONLY(16) LightSourceInstanceData {
	aligned_float32_t aabb[6];
	aligned_float32_t power; // in watts
	aligned_float32_t maxDistance; // dynamically updated (along with aabb) depending on set power
	aligned_f32vec3 color; // components individually normalized between 0 and 1
	aligned_float32_t innerRadius;
	aligned_f32vec3 direction; // oriented in object space, for spot lights only (must have a non-zero angle set below)
	aligned_float32_t angle; // in radians, used for spotlights only, otherwise set to 0 for a point/sphere light
};
STATIC_ASSERT_ALIGNED16_SIZE(LightSourceInstanceData, 64)

BUFFER_REFERENCE_STRUCT_WRITEONLY(4) AudibleRenderableData {
	float audible;
};

BUFFER_REFERENCE_STRUCT(4) EnvironmentAudioData {
	aligned_int32_t miss;
	aligned_int32_t terrain;
	aligned_int32_t object;
	aligned_int32_t hydrosphere;
	aligned_int32_t hydrosphereDistance; // in centimeters
	aligned_int32_t _unused;
	BUFFER_REFERENCE_ADDR(AudibleRenderableData) audibleRenderables;
};
STATIC_ASSERT_SIZE(EnvironmentAudioData, 32)

BUFFER_REFERENCE_STRUCT_READONLY(16) AtmosphereData {
	aligned_f32vec4 rayleigh;
	aligned_f32vec4 mie;
	aligned_float32_t innerRadius;
	aligned_float32_t outerRadius;
	aligned_float32_t g;
	aligned_float32_t temperature;
	aligned_f32vec3 _unused;
	aligned_int32_t nbSuns;
	SunData suns[2];
};
STATIC_ASSERT_ALIGNED16_SIZE(AtmosphereData, 128)

BUFFER_REFERENCE_STRUCT_READONLY(16) WaterData {
	aligned_f64vec3 center;
	aligned_float64_t radius;
};
STATIC_ASSERT_ALIGNED16_SIZE(WaterData, 32)

BUFFER_REFERENCE_STRUCT_READONLY(16) PlasmaData {
	aligned_float32_t depth;
	aligned_float32_t radius;
	aligned_float32_t temperature; // [1000 - 10000] (5000)
	aligned_uint16_t mask;
	aligned_uint16_t flags;
	aligned_f32vec3 color;
	aligned_float32_t density; // [10 - 10000] (500)
};
STATIC_ASSERT_ALIGNED16_SIZE(PlasmaData, 32)

BUFFER_REFERENCE_STRUCT_READONLY(16) PropellerData {
	aligned_float32_t radius;
	aligned_float32_t width;
	aligned_float32_t base;
	aligned_float32_t twist;
	aligned_float32_t pitch;
	aligned_float32_t roundedTips;
	aligned_float32_t speed;
	aligned_uint16_t flags;
	aligned_uint8_t blades;
	aligned_uint8_t _unused;
};
STATIC_ASSERT_ALIGNED16_SIZE(PropellerData, 32)

struct GeometryMaterial {
	aligned_f32vec4 color;
	aligned_f32vec3 emission;
	aligned_uint32_t surfaceIndex;
	aligned_uint64_t data; // custom per surface shader, default is a pack of 4x uint16 texture indices (albedo/alpha, normal/bump, metallic/roughness, emission)
	aligned_float32_t metallic;
	aligned_float32_t roughness;
	aligned_VkDeviceAddress uv1; // Used only within a surface shader as surface.geometryUv1Data, may be used for custom stuff, although for monitors we should compute it and set surface.uv1 from our surface shader
	aligned_VkDeviceAddress uv2; // Used only within a surface shader as surface.geometryUv2Data, may be used for custom stuff
};
STATIC_ASSERT_ALIGNED16_SIZE(GeometryMaterial, 64)

BUFFER_REFERENCE_STRUCT_READONLY(16) Matrix3x4 {
	aligned_f32mat3x4 transform3x4;
};

BUFFER_REFERENCE_STRUCT_READONLY(16) GeometryData {
	BUFFER_REFERENCE_ADDR(AabbData) aabbs;
	aligned_VkDeviceAddress vertices;
	aligned_VkDeviceAddress indices16;
	aligned_VkDeviceAddress indices32;
	BUFFER_REFERENCE_ADDR(Matrix3x4) transform;
	aligned_VkDeviceAddress normals;
	aligned_VkDeviceAddress colors_u8;
	aligned_VkDeviceAddress colors_f32;
	GeometryMaterial material;
};
STATIC_ASSERT_ALIGNED16_SIZE(GeometryData, 128)

BUFFER_REFERENCE_STRUCT_READONLY(16) RenderableInstanceData {
	BUFFER_REFERENCE_ADDR(GeometryData) geometries; // shared data between all renderables loaded from the same mesh file
	aligned_uint64_t data; // custom data defined per renderable type (defaults to an array of RenderableData per geometry)
};
STATIC_ASSERT_ALIGNED16_SIZE(RenderableInstanceData, 16)

BUFFER_REFERENCE_STRUCT(16) AimBuffer {
	aligned_f32vec3 localPosition;
	aligned_uint32_t aimID;
	aligned_f32vec3 worldSpaceHitNormal;
	aligned_uint32_t primitiveIndex;
	aligned_f32vec3 worldSpacePosition; // MUST COMPENSATE FOR ORIGIN RESET
	aligned_float32_t hitDistance;
	aligned_f32vec4 color;
	aligned_f32vec3 viewSpaceHitNormal;
	aligned_uint32_t tlasInstanceIndex;
	aligned_f32vec2 uv;
	aligned_uint32_t monitorIndex; // matches with a texture index, 0 means it is not a monitor
	aligned_uint32_t geometryIndex;
};
STATIC_ASSERT_ALIGNED16_SIZE(AimBuffer, 96)

GLSL_FUNCTION float smoothCurve(float x) {
	x = clamp(x,0.0f,1.0f);
	return x*x*x*(x*(x*6.0f-15.0f)+10.0f);
}
GLSL_FUNCTION double smoothCurve(double x) {
	x = clamp(x,0.0,1.0);
	return x*x*x*(x*(x*6.0-15.0)+10.0);
}
GLSL_FUNCTION vec2 smoothCurve(vec2 x) {
	x = clamp(x,vec2(0),vec2(1));
	return x*x*x*(x*(x*6.0f-15.0f)+10.0f);
}
GLSL_FUNCTION vec3 smoothCurve(vec3 x) {
	x = clamp(x,vec3(0),vec3(1));
	return x*x*x*(x*(x*6.0f-15.0f)+10.0f);
}
GLSL_FUNCTION vec4 smoothCurve(vec4 x) {
	x = clamp(x,vec4(0),vec4(1));
	return x*x*x*(x*(x*6.0f-15.0f)+10.0f);
}

#ifdef GLSL
	#define EPSILON 0.0001
	
	struct Surface {
		vec4 color;
		vec3 normal;
		float metallic;
		vec3 emission;
		float roughness;
		vec3 localPosition;
		float specular;
		uint64_t renderableData;
		uint64_t aabbData;
		uint32_t renderableIndex;
		uint32_t geometryIndex;
		uint32_t primitiveIndex;
		float ior;
		vec2 uv1;
		vec2 uv2;
		vec3 barycentricCoords;
		float distance;
		uint64_t geometries;
		uint64_t geometryInfoData;
		uint64_t geometryUv1Data;
		uint64_t geometryUv2Data;
	};
	#if defined(SHADER_RCHIT)
		layout(location = SURFACE_CALLABLE_PAYLOAD) callableDataEXT Surface surface;
	#endif
	#if defined(SHADER_SURFACE)
		layout(location = SURFACE_CALLABLE_PAYLOAD) callableDataInEXT Surface surface;
	#endif
	
	layout(buffer_reference, std430, buffer_reference_align = 2) buffer readonly IndexBuffer16 {uint16_t indices[];};
	layout(buffer_reference, std430, buffer_reference_align = 4) buffer readonly IndexBuffer32 {uint32_t indices[];};
	layout(buffer_reference, std430, buffer_reference_align = 4) buffer readonly VertexBuffer {float vertices[];};
	layout(buffer_reference, std430, buffer_reference_align = 4) buffer readonly VertexColorU8 {u8vec4 colors[];};
	layout(buffer_reference, std430, buffer_reference_align = 16) buffer readonly VertexColorF32 {f32vec4 colors[];};
	layout(buffer_reference, std430, buffer_reference_align = 4) buffer readonly VertexNormal {float normals[];};
	layout(buffer_reference, std430, buffer_reference_align = 4) buffer readonly VertexUV {float uv[];};
	
	vec3 ComputeSurfaceNormal(in uint64_t geometries, in uint geometryIndex, in uint primitiveID, in vec3 barycentricCoordsOrLocalPosition) {
		GeometryData geometry = GeometryData(geometries)[nonuniformEXT(geometryIndex)];
		if (uint64_t(geometry.aabbs) != 0) {
			const vec3 aabb_min = vec3(geometry.aabbs[nonuniformEXT(primitiveID)].aabb[0], geometry.aabbs[nonuniformEXT(primitiveID)].aabb[1], geometry.aabbs[nonuniformEXT(primitiveID)].aabb[2]);
			const vec3 aabb_max = vec3(geometry.aabbs[nonuniformEXT(primitiveID)].aabb[3], geometry.aabbs[nonuniformEXT(primitiveID)].aabb[4], geometry.aabbs[nonuniformEXT(primitiveID)].aabb[5]);
			const vec3 absMin = abs(barycentricCoordsOrLocalPosition - aabb_min.xyz);
			const vec3 absMax = abs(barycentricCoordsOrLocalPosition - aabb_max.xyz);
			float smallestValue = 1e100;
			vec3 normal;
			if (absMin.x < smallestValue) {smallestValue = absMin.x; normal = vec3(-1, 0, 0);}
			if (absMin.y < smallestValue) {smallestValue = absMin.y; normal = vec3( 0,-1, 0);}
			if (absMin.z < smallestValue) {smallestValue = absMin.z; normal = vec3( 0, 0,-1);}
			if (absMax.x < smallestValue) {smallestValue = absMax.x; normal = vec3( 1, 0, 0);}
			if (absMax.y < smallestValue) {smallestValue = absMax.y; normal = vec3( 0, 1, 0);}
			if (absMax.z < smallestValue) {smallestValue = absMax.z; normal = vec3( 0, 0, 1);}
			return normal;
		}
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
		vec3 normal;
		if (geometry.normals != 0) {
			VertexNormal vertexNormals = VertexNormal(geometry.normals);
			normal = normalize(
				+ vec3(vertexNormals.normals[nonuniformEXT(index0*3)], vertexNormals.normals[nonuniformEXT(index0*3+1)], vertexNormals.normals[nonuniformEXT(index0*3+2)]) * barycentricCoordsOrLocalPosition.x
				+ vec3(vertexNormals.normals[nonuniformEXT(index1*3)], vertexNormals.normals[nonuniformEXT(index1*3+1)], vertexNormals.normals[nonuniformEXT(index1*3+2)]) * barycentricCoordsOrLocalPosition.y
				+ vec3(vertexNormals.normals[nonuniformEXT(index2*3)], vertexNormals.normals[nonuniformEXT(index2*3+1)], vertexNormals.normals[nonuniformEXT(index2*3+2)]) * barycentricCoordsOrLocalPosition.z
			);
			
		} else if (geometry.vertices != 0) {
			VertexBuffer vertexBuffer = VertexBuffer(geometry.vertices);
			vec3 v0 = vec3(vertexBuffer.vertices[nonuniformEXT(index0*3)], vertexBuffer.vertices[nonuniformEXT(index0*3+1)], vertexBuffer.vertices[nonuniformEXT(index0*3+2)]);
			vec3 v1 = vec3(vertexBuffer.vertices[nonuniformEXT(index1*3)], vertexBuffer.vertices[nonuniformEXT(index1*3+1)], vertexBuffer.vertices[nonuniformEXT(index1*3+2)]);
			vec3 v2 = vec3(vertexBuffer.vertices[nonuniformEXT(index2*3)], vertexBuffer.vertices[nonuniformEXT(index2*3+1)], vertexBuffer.vertices[nonuniformEXT(index2*3+2)]);
			normal = normalize(cross(v1 - v0, v2 - v0));
		} else {
			return normalize(barycentricCoordsOrLocalPosition);
		}
		if (uint64_t(geometry.transform) != 0) {
			normal = normalize(inverse(mat3(geometry.transform.transform3x4)) * normal);
		}
		return normal;
	}
	vec4 ComputeSurfaceColor(in uint64_t geometries, in uint geometryIndex, in uint primitiveID, in vec3 barycentricCoordsOrLocalPosition) {
		GeometryData geometry = GeometryData(geometries)[nonuniformEXT(geometryIndex)];
		if (geometry.colors_u8 != 0) {
			VertexColorU8 vertexColors = VertexColorU8(geometry.colors_u8);
			if (uint64_t(geometry.aabbs) != 0) {
				return clamp(vec4(vertexColors.colors[nonuniformEXT(primitiveID)]) / 255.0, vec4(0), vec4(1));
			}
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
				+ vec4(vertexColors.colors[nonuniformEXT(index0)]) / 255.0 * barycentricCoordsOrLocalPosition.x
				+ vec4(vertexColors.colors[nonuniformEXT(index1)]) / 255.0 * barycentricCoordsOrLocalPosition.y
				+ vec4(vertexColors.colors[nonuniformEXT(index2)]) / 255.0 * barycentricCoordsOrLocalPosition.z
			, vec4(0), vec4(1));
		} else if (geometry.colors_f32 != 0) {
			VertexColorF32 vertexColors = VertexColorF32(geometry.colors_f32);
			if (uint64_t(geometry.aabbs) != 0) {
				return clamp(vertexColors.colors[nonuniformEXT(primitiveID)], vec4(0), vec4(1));
			}
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
				+ vertexColors.colors[nonuniformEXT(index0)] * barycentricCoordsOrLocalPosition.x
				+ vertexColors.colors[nonuniformEXT(index1)] * barycentricCoordsOrLocalPosition.y
				+ vertexColors.colors[nonuniformEXT(index2)] * barycentricCoordsOrLocalPosition.z
			, vec4(0), vec4(1));
		} else {
			return vec4(1);
		}
	}
	vec2 ComputeSurfaceUV1(in uint64_t geometries, in uint geometryIndex, in uint primitiveID, in vec3 barycentricCoordsOrLocalPosition) {
		GeometryData geometry = GeometryData(geometries)[nonuniformEXT(geometryIndex)];
		if (uint64_t(geometry.aabbs) != 0) {
			return vec2(0);
		}
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
		if (geometry.material.uv1 != 0) {
			VertexUV vertexUV = VertexUV(geometry.material.uv1);
			return (
				+ vec2(vertexUV.uv[nonuniformEXT(index0*2)], vertexUV.uv[nonuniformEXT(index0*2+1)]) * barycentricCoordsOrLocalPosition.x
				+ vec2(vertexUV.uv[nonuniformEXT(index1*2)], vertexUV.uv[nonuniformEXT(index1*2+1)]) * barycentricCoordsOrLocalPosition.y
				+ vec2(vertexUV.uv[nonuniformEXT(index2*2)], vertexUV.uv[nonuniformEXT(index2*2+1)]) * barycentricCoordsOrLocalPosition.z
			);
		} else {
			return vec2(0);
		}
	}
	vec2 ComputeSurfaceUV2(in uint64_t geometries, in uint geometryIndex, in uint primitiveID, in vec3 barycentricCoordsOrLocalPosition) {
		GeometryData geometry = GeometryData(geometries)[nonuniformEXT(geometryIndex)];
		if (uint64_t(geometry.aabbs) != 0) {
			return vec2(0);
		}
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
		if (geometry.material.uv2 != 0) {
			VertexUV vertexUV = VertexUV(geometry.material.uv2);
			return (
				+ vec2(vertexUV.uv[nonuniformEXT(index0*2)], vertexUV.uv[nonuniformEXT(index0*2+1)]) * barycentricCoordsOrLocalPosition.x
				+ vec2(vertexUV.uv[nonuniformEXT(index1*2)], vertexUV.uv[nonuniformEXT(index1*2+1)]) * barycentricCoordsOrLocalPosition.y
				+ vec2(vertexUV.uv[nonuniformEXT(index2*2)], vertexUV.uv[nonuniformEXT(index2*2+1)]) * barycentricCoordsOrLocalPosition.z
			);
		} else {
			return vec2(0);
		}
	}
	
#endif

#ifdef __cplusplus
namespace {
#endif

float STEFAN_BOLTZMANN_CONSTANT = 5.670374419184429E-8f;
float GetSunRadiationAtDistanceSqr(float temperature, float radius, float distanceSqr) {
	return radius*radius * STEFAN_BOLTZMANN_CONSTANT * pow(temperature, 4.0f) / distanceSqr;
}
float GetRadiationAtTemperatureForWavelength(float temperature_kelvin, float wavelength_nm) {
	float hcltkb = 14387769.6f / (wavelength_nm * temperature_kelvin);
	float w = wavelength_nm / 1000.0f;
	return 119104.2868f / (w * w * w * w * w * (exp(hcltkb) - 1.0f));
}
vec3 GetEmissionColor(float temperatureKelvin) {
	return vec3(
		GetRadiationAtTemperatureForWavelength(temperatureKelvin, 680.0f),
		GetRadiationAtTemperatureForWavelength(temperatureKelvin, 550.0f),
		GetRadiationAtTemperatureForWavelength(temperatureKelvin, 440.0f)
	);
}
vec3 GetEmissionColor(vec4 emission_temperature) {
	return vec3(emission_temperature.r, emission_temperature.g, emission_temperature.b) + GetEmissionColor(emission_temperature.a);
}

#ifdef __cplusplus
}
#endif
