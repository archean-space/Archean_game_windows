#ifdef __cplusplus
	#pragma once
#else
	#extension GL_ARB_shader_clock : enable
	#extension GL_EXT_ray_tracing : require
	#extension GL_EXT_ray_query : require
#endif

// AMD doesn't seem to like ray queries from inside anyhit shaders, comment the line below if you're using an AMD GPU and it crashes
#define ENABLE_RAY_QUERIES_FROM_ANYHIT_SHADERS

#include "xenon/renderer/shaders/common.inc.glsl"

#define RAYTRACE_MASK_TERRAIN 1u // highly detailed static solid opaque geometry usually in the background with nothing else behind it
#define RAYTRACE_MASK_ENTITY 2u // dynamic solid geometry
#define RAYTRACE_MASK_FOG 4u // applied after solid geometries, on top, does not block rays nor affect ray direction
#define RAYTRACE_MASK_CLUTTER 8u // small highly detailed geometries, may cast shadows but doesn't block ambient lighting
#define RAYTRACE_MASK_LIQUID 16u // transparent dynamic volume with refraction
// #define RAYTRACE_MASK_ 32u
// #define RAYTRACE_MASK_ 64u
// #define RAYTRACE_MASK_ 128u

#define RAYTRACE_MASK_SOLID (RAYTRACE_MASK_TERRAIN|RAYTRACE_MASK_ENTITY|RAYTRACE_MASK_CLUTTER)
#define RAYTRACE_MASK_OPAQUE (RAYTRACE_MASK_TERRAIN|RAYTRACE_MASK_ENTITY)

#define LIGHT_LUMINOSITY_VISIBLE_THRESHOLD 0.01
#define ENVIRONMENT_AUDIO_MAX_DISTANCE 500

// Up to 16 flags
#define PLASMA_FLAG_AEROSPIKE	(1u << 0)
#define PLASMA_FLAG_SHAKE 		(1u << 1)

// Up to 32 options
#define RENDERER_OPTION_DIRECT_LIGHTING				(1u<< 0 )
#define RENDERER_OPTION_GLASS_REFLECTIONS			(1u<< 1 )
#define RENDERER_OPTION_GLASS_REFRACTION			(1u<< 2 )
#define RENDERER_OPTION_WATER_REFLECTIONS			(1u<< 3 )
#define RENDERER_OPTION_WATER_REFRACTION			(1u<< 4 )
#define RENDERER_OPTION_RT_AMBIENT_LIGHTING			(1u<< 5 )
#define RENDERER_OPTION_ATMOSPHERIC_SHADOWS			(1u<< 6 )
#define RENDERER_OPTION_UNDERWATER_VOLUMETRIC_FOG	(1u<< 7 )
#define RENDERER_OPTION_UNDERWATER_LIGHT_RAYS		(1u<< 8 )

BUFFER_REFERENCE_STRUCT_READONLY(16) AabbData {
	aligned_float32_t aabb[6];
	aligned_uint64_t data; // Arbitrary data defined per-shader
};
STATIC_ASSERT_ALIGNED16_SIZE(AabbData, 32)

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
	aligned_float32_t audible;
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

struct GeometryMaterial {
	aligned_f32vec4 color;
	aligned_f32vec3 emission;
	aligned_uint32_t callableShader;
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
	aligned_f32vec4 _color; // DEPRECATED
	aligned_f32vec3 viewSpaceHitNormal;
	aligned_uint32_t tlasInstanceIndex;
	aligned_f32vec2 uv;
	aligned_uint32_t monitorIndex; // matches with a texture index, 0 means it is not a monitor
	aligned_uint32_t geometryIndex;
};
STATIC_ASSERT_ALIGNED16_SIZE(AimBuffer, 96)

BUFFER_REFERENCE_STRUCT_READONLY(16) TLASInstance {
	aligned_f32mat3x4 transform;
	aligned_uint32_t instanceCustomIndex_and_mask; // mask>>24, customIndex&0xffffff
	aligned_uint32_t instanceShaderBindingTableRecordOffset_and_flags; // flags>>24
	aligned_VkDeviceAddress accelerationStructureReference;
};
STATIC_ASSERT_ALIGNED16_SIZE(TLASInstance, 64)

BUFFER_REFERENCE_STRUCT_WRITEONLY(16) MVPBufferCurrent {aligned_f32mat4 mvp;};
BUFFER_REFERENCE_STRUCT_READONLY(16) MVPBufferHistory {aligned_f32mat4 mvp;};
BUFFER_REFERENCE_STRUCT_WRITEONLY(8) RealtimeBufferCurrent {aligned_uint64_t mvpFrameIndex;};
BUFFER_REFERENCE_STRUCT_READONLY(8) RealtimeBufferHistory {aligned_uint64_t mvpFrameIndex;};

BUFFER_REFERENCE_STRUCT_READONLY(8) LightSourceInstanceTable {
	BUFFER_REFERENCE_ADDR(LightSourceInstanceData) instance;
};

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

GLSL_FUNCTION float STEFAN_BOLTZMANN_CONSTANT = 5.670374419184429E-8f;
GLSL_FUNCTION float GetSunRadiationAtDistanceSqr(float temperature, float radius, float distanceSqr) {
	return radius*radius * STEFAN_BOLTZMANN_CONSTANT * pow(temperature, 4.0f) / distanceSqr;
}

GLSL_FUNCTION float GetRadiationAtTemperatureForWavelength(float temperature_kelvin, float wavelength_nm) {
	float hcltkb = 14387769.6f / (wavelength_nm * temperature_kelvin);
	float w = wavelength_nm / 1000.0f;
	return 119104.2868f / (w * w * w * w * w * (exp(hcltkb) - 1.0f));
}
GLSL_FUNCTION vec3 GetEmissionColor(float temperatureKelvin) {
	return vec3(
		GetRadiationAtTemperatureForWavelength(temperatureKelvin, 680.0f),
		GetRadiationAtTemperatureForWavelength(temperatureKelvin, 550.0f),
		GetRadiationAtTemperatureForWavelength(temperatureKelvin, 440.0f)
	);
}
GLSL_FUNCTION vec3 GetEmissionColor(vec4 emission_temperature) {
	return vec3(emission_temperature.r, emission_temperature.g, emission_temperature.b) + GetEmissionColor(emission_temperature.a);
}

struct RendererData {
	aligned_f32mat4 viewMatrix;
	aligned_f32mat4 historyViewMatrix;
	aligned_f32mat4 reprojectionMatrix;
	
	BUFFER_REFERENCE_ADDR(MVPBufferCurrent) mvpBuffer;
	BUFFER_REFERENCE_ADDR(MVPBufferHistory) mvpBufferHistory;
	BUFFER_REFERENCE_ADDR(RealtimeBufferCurrent) realtimeBuffer;
	BUFFER_REFERENCE_ADDR(RealtimeBufferHistory) realtimeBufferHistory;
	BUFFER_REFERENCE_ADDR(RenderableInstanceData) renderableInstances;
	BUFFER_REFERENCE_ADDR(TLASInstance) tlasInstances;
	BUFFER_REFERENCE_ADDR(AimBuffer) aim;
	aligned_uint64_t _unused1;
	aligned_uint64_t _unused2;
	aligned_uint64_t _unused3;
	BUFFER_REFERENCE_ADDR(LightSourceInstanceTable) lightSources;
	BUFFER_REFERENCE_ADDR(EnvironmentAudioData) environmentAudio;
	
	aligned_f32vec3 wireframeColor;
	aligned_float32_t wireframeThickness;
	
	aligned_i32vec3 worldOrigin;
	aligned_float32_t cameraZNear;
	
	aligned_float64_t timestamp;
	aligned_uint32_t rays_max_bounces;
	aligned_float32_t warp;
	
	aligned_uint32_t ambientAtmosphereSamples;
	aligned_uint32_t ambientOcclusionSamples;
	aligned_float32_t terrain_detail;
	aligned_float32_t globalLightingFactor;
	
	aligned_uint32_t options; // RENDERER_OPTION_*
	aligned_int32_t atmosphere_raymarch_steps;
	aligned_float32_t terrain_clutter_detail;
	aligned_float32_t testSlider;
	
	aligned_uint32_t bluenoise_scalar;
	aligned_uint32_t bluenoise_unitvec1;
	aligned_uint32_t bluenoise_unitvec2;
	aligned_uint32_t bluenoise_unitvec3;
	aligned_uint32_t bluenoise_unitvec3_cosine;
	aligned_uint32_t bluenoise_vec1;
	aligned_uint32_t bluenoise_vec2;
	aligned_uint32_t bluenoise_vec3;
};

#define SET1_BINDING_TLAS 0
#define SET1_BINDING_LIGHTS_TLAS 1
#define SET1_BINDING_RENDERER_DATA 2
#define SET1_BINDING_BLOOM_IMAGE 3
#define SET1_BINDING_CLOUD_IMAGE 4
#define SET1_BINDING_CLOUD_SAMPLER 5

#define COORDS ivec2(gl_LaunchIDEXT.xy)
#define WORLD2VIEWNORMAL transpose(inverse(mat3(renderer.viewMatrix)))
#define VIEW2WORLDNORMAL transpose(mat3(renderer.viewMatrix))

#ifdef GLSL
	layout(set = 1, binding = SET1_BINDING_TLAS) uniform accelerationStructureEXT tlas;
	layout(set = 1, binding = SET1_BINDING_LIGHTS_TLAS) uniform accelerationStructureEXT tlas_lights;
	layout(set = 1, binding = SET1_BINDING_RENDERER_DATA) uniform RendererDataBuffer { RendererData renderer; };
	layout(set = 1, binding = SET1_BINDING_BLOOM_IMAGE, rgba8) uniform image2D img_bloom;
	layout(set = 1, binding = SET1_BINDING_CLOUD_IMAGE, rgba32f) uniform image2D img_cloud[2];
	layout(set = 1, binding = SET1_BINDING_CLOUD_SAMPLER) uniform sampler2D sampler_cloud;
#endif

// layout(set = 1, binding = 9, rgba32f) uniform image2D images[];

// layout(push_constant) uniform RayTracingPushConstant {
// 	mat4 viewMatrix;
// 	float aspectRatio;
// 	float fov;
// 	float zNear;
// 	float zFar;
// 	vec2 jitter;
// 	uint32_t albedoOpacityImageIndex;
// 	uint32_t normalDistanceImageIndex;
// 	uint32_t emissionIorImageIndex;
// 	uint32_t extraImageIndex; // roughness, metallic, specular, 8 flags
// };

struct RayPayload {
	vec3 color;
	float hitDistance;
	vec3 normal;
	int32_t renderableIndex;
	vec3 localPosition;
	uint8_t roughness;
	uint8_t ior; // 0 for interior faces
	uint8_t surfaceFlags;
	uint8_t rayFlags;
};

struct RayShadowPayload {
	vec3 colorAttenuation;
	float hitDistance;
	vec3 emission;
	uint32_t rayFlags;
};

#define RAY_SURFACE_DIFFUSE uint8_t(0) // no flags
#define RAY_SURFACE_METALLIC uint8_t(0x1)
#define RAY_SURFACE_EMISSIVE uint8_t(0x2)
#define RAY_SURFACE_TRANSPARENT uint8_t(0x4)
//... 4 more

#define RAY_FLAG_RECURSION uint8_t(0x1)
#define RAY_FLAG_AIM uint8_t(0x2)
#define RAY_FLAG_FLUID uint8_t(0x4) // when inside a fluid volume
//... 5 more

#define SHADOW_RAY_FLAG_EMISSION uint32_t(0x1)
//... 31 more

#define MODELVIEW (renderer.viewMatrix * mat4(gl_ObjectToWorldEXT))
#define MODEL2WORLDNORMAL inverse(transpose(mat3(gl_ObjectToWorldEXT)))
#define MVP (xenonRendererData.config.projectionMatrix * MODELVIEW)
#define MVP_AA (xenonRendererData.config.projectionMatrixWithTAA * MODELVIEW)
#define MVP_HISTORY (xenonRendererData.config.projectionMatrix * MODELVIEW_HISTORY)
#ifdef SHADER_COMP_RAYS
	#define INSTANCE(q,commited) renderer.renderableInstances[rayQueryGetIntersectionInstanceIdEXT(q,commited)]
	#define GEOMETRY(q,commited) INSTANCE(q,commited).geometries[rayQueryGetIntersectionGeometryIndexEXT(q,commited)]
	#define AABB(q,commited) GEOMETRY(q,commited).aabbs[rayQueryGetIntersectionPrimitiveIndexEXT(q,commited)]
	#define AABB_MIN(q,commited) vec3(AABB(q,commited).aabb[0], AABB(q,commited).aabb[1], AABB(q,commited).aabb[2])
	#define AABB_MAX(q,commited) vec3(AABB(q,commited).aabb[3], AABB(q,commited).aabb[4], AABB(q,commited).aabb[5])
	#define AABB_CENTER(q,commited) ((AABB_MIN(q,commited) + AABB_MAX(q,commited)) * 0.5)
	#define AABB_CENTER_INT(q,commited) ivec3(round(AABB_CENTER(q,commited)))
	#define COMPUTE_BOX_INTERSECTION(q,commited) \
		vec3 _rayOrigin = rayQueryGetIntersectionObjectRayOriginEXT(q,commited);\
		vec3 _rayDirection = rayQueryGetIntersectionObjectRayDirectionEXT(q,commited);\
		const vec3 _tbot = (AABB_MIN(q,commited) - _rayOrigin) / _rayDirection;\
		const vec3 _ttop = (AABB_MAX(q,commited) - _rayOrigin) / _rayDirection;\
		const vec3 _tmin = min(_ttop, _tbot);\
		const vec3 _tmax = max(_ttop, _tbot);\
		const float T1 = max(_tmin.x, max(_tmin.y, _tmin.z));\
		const float T2 = min(_tmax.x, min(_tmax.y, _tmax.z));
	#define RAY_STARTS_OUTSIDE_T1_T2(q) (rayQueryGetRayTMinEXT(q) <= T1 && T2 > T1)
	#define RAY_STARTS_BETWEEN_T1_T2(q) (T1 <= rayQueryGetRayTMinEXT(q) && T2 >= rayQueryGetRayTMinEXT(q))
#endif

#ifdef GLSL
	layout(buffer_reference, std430, buffer_reference_align = 2) buffer readonly IndexBuffer16 {uint16_t indices[];};
	layout(buffer_reference, std430, buffer_reference_align = 4) buffer readonly IndexBuffer32 {uint32_t indices[];};
	layout(buffer_reference, std430, buffer_reference_align = 4) buffer readonly VertexBuffer {float vertices[];};
	layout(buffer_reference, std430, buffer_reference_align = 4) buffer readonly VertexColorU8 {u8vec4 colors[];};
	layout(buffer_reference, std430, buffer_reference_align = 16) buffer readonly VertexColorF32 {f32vec4 colors[];};
	layout(buffer_reference, std430, buffer_reference_align = 4) buffer readonly VertexNormal {float normals[];};
	layout(buffer_reference, std430, buffer_reference_align = 4) buffer readonly VertexUV {float uv[];};
#endif

#if defined(SHADER_RINT) || defined(SHADER_RCHIT) || defined(SHADER_RAHIT)

	#define INSTANCE renderer.renderableInstances[gl_InstanceID]
	#define GEOMETRY INSTANCE.geometries[gl_GeometryIndexEXT]
	#define AABB GEOMETRY.aabbs[gl_PrimitiveID]
	#define AABB_MIN vec3(AABB.aabb[0], AABB.aabb[1], AABB.aabb[2])
	#define AABB_MAX vec3(AABB.aabb[3], AABB.aabb[4], AABB.aabb[5])
	#define AABB_CENTER ((AABB_MIN + AABB_MAX) * 0.5)
	#define AABB_CENTER_INT ivec3(round(AABB_CENTER))
	#define COMPUTE_BOX_INTERSECTION \
		const vec3 _tbot = (AABB_MIN - gl_ObjectRayOriginEXT) / gl_ObjectRayDirectionEXT;\
		const vec3 _ttop = (AABB_MAX - gl_ObjectRayOriginEXT) / gl_ObjectRayDirectionEXT;\
		const vec3 _tmin = min(_ttop, _tbot);\
		const vec3 _tmax = max(_ttop, _tbot);\
		const float T1 = max(_tmin.x, max(_tmin.y, _tmin.z));\
		const float T2 = min(_tmax.x, min(_tmax.y, _tmax.z));
	#define RAY_STARTS_OUTSIDE_T1_T2 (gl_RayTminEXT <= T1 && T1 < gl_RayTmaxEXT && T2 > T1)
	#define RAY_STARTS_BETWEEN_T1_T2 (T1 <= gl_RayTminEXT && T2 >= gl_RayTminEXT)

	vec3 ComputeSurfaceNormal(in uint64_t geometries, in uint geometryIndex, in uint primitiveID, in vec3 barycentricCoordsOrLocalPosition) {
		GeometryData geometry = GeometryData(geometries)[geometryIndex];
		if (uint64_t(geometry.aabbs) != 0) {
			const vec3 aabb_min = vec3(geometry.aabbs[primitiveID].aabb[0], geometry.aabbs[primitiveID].aabb[1], geometry.aabbs[primitiveID].aabb[2]);
			const vec3 aabb_max = vec3(geometry.aabbs[primitiveID].aabb[3], geometry.aabbs[primitiveID].aabb[4], geometry.aabbs[primitiveID].aabb[5]);
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
			index0 = IndexBuffer16(geometry.indices16).indices[index0];
			index1 = IndexBuffer16(geometry.indices16).indices[index1];
			index2 = IndexBuffer16(geometry.indices16).indices[index2];
		} else if (geometry.indices32 != 0) {
			index0 = IndexBuffer32(geometry.indices32).indices[index0];
			index1 = IndexBuffer32(geometry.indices32).indices[index1];
			index2 = IndexBuffer32(geometry.indices32).indices[index2];
		}
		vec3 normal;
		if (geometry.normals != 0) {
			VertexNormal vertexNormals = VertexNormal(geometry.normals);
			normal = normalize(
				+ vec3(vertexNormals.normals[index0*3], vertexNormals.normals[index0*3+1], vertexNormals.normals[index0*3+2]) * barycentricCoordsOrLocalPosition.x
				+ vec3(vertexNormals.normals[index1*3], vertexNormals.normals[index1*3+1], vertexNormals.normals[index1*3+2]) * barycentricCoordsOrLocalPosition.y
				+ vec3(vertexNormals.normals[index2*3], vertexNormals.normals[index2*3+1], vertexNormals.normals[index2*3+2]) * barycentricCoordsOrLocalPosition.z
			);
			
		} else if (geometry.vertices != 0) {
			VertexBuffer vertexBuffer = VertexBuffer(geometry.vertices);
			vec3 v0 = vec3(vertexBuffer.vertices[index0*3], vertexBuffer.vertices[index0*3+1], vertexBuffer.vertices[index0*3+2]);
			vec3 v1 = vec3(vertexBuffer.vertices[index1*3], vertexBuffer.vertices[index1*3+1], vertexBuffer.vertices[index1*3+2]);
			vec3 v2 = vec3(vertexBuffer.vertices[index2*3], vertexBuffer.vertices[index2*3+1], vertexBuffer.vertices[index2*3+2]);
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
		GeometryData geometry = GeometryData(geometries)[geometryIndex];
		if (geometry.colors_u8 != 0) {
			VertexColorU8 vertexColors = VertexColorU8(geometry.colors_u8);
			if (uint64_t(geometry.aabbs) != 0) {
				return clamp(vec4(vertexColors.colors[primitiveID]) / 255.0, vec4(0), vec4(1));
			}
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
				+ vec4(vertexColors.colors[index0]) / 255.0 * barycentricCoordsOrLocalPosition.x
				+ vec4(vertexColors.colors[index1]) / 255.0 * barycentricCoordsOrLocalPosition.y
				+ vec4(vertexColors.colors[index2]) / 255.0 * barycentricCoordsOrLocalPosition.z
			, vec4(0), vec4(1));
		} else if (geometry.colors_f32 != 0) {
			VertexColorF32 vertexColors = VertexColorF32(geometry.colors_f32);
			if (uint64_t(geometry.aabbs) != 0) {
				return clamp(vertexColors.colors[primitiveID], vec4(0), vec4(1));
			}
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
				+ vertexColors.colors[index0] * barycentricCoordsOrLocalPosition.x
				+ vertexColors.colors[index1] * barycentricCoordsOrLocalPosition.y
				+ vertexColors.colors[index2] * barycentricCoordsOrLocalPosition.z
			, vec4(0), vec4(1));
		} else {
			return vec4(1);
		}
	}
	vec2 ComputeSurfaceUV1(in uint64_t geometries, in uint geometryIndex, in uint primitiveID, in vec3 barycentricCoordsOrLocalPosition) {
		GeometryData geometry = GeometryData(geometries)[geometryIndex];
		if (uint64_t(geometry.aabbs) != 0) {
			return vec2(0);
		}
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
		if (geometry.material.uv1 != 0) {
			VertexUV vertexUV = VertexUV(geometry.material.uv1);
			return (
				+ vec2(vertexUV.uv[index0*2], vertexUV.uv[index0*2+1]) * barycentricCoordsOrLocalPosition.x
				+ vec2(vertexUV.uv[index1*2], vertexUV.uv[index1*2+1]) * barycentricCoordsOrLocalPosition.y
				+ vec2(vertexUV.uv[index2*2], vertexUV.uv[index2*2+1]) * barycentricCoordsOrLocalPosition.z
			);
		} else {
			return vec2(0);
		}
	}
	vec2 ComputeSurfaceUV2(in uint64_t geometries, in uint geometryIndex, in uint primitiveID, in vec3 barycentricCoordsOrLocalPosition) {
		GeometryData geometry = GeometryData(geometries)[geometryIndex];
		if (uint64_t(geometry.aabbs) != 0) {
			return vec2(0);
		}
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
		if (geometry.material.uv2 != 0) {
			VertexUV vertexUV = VertexUV(geometry.material.uv2);
			return (
				+ vec2(vertexUV.uv[index0*2], vertexUV.uv[index0*2+1]) * barycentricCoordsOrLocalPosition.x
				+ vec2(vertexUV.uv[index1*2], vertexUV.uv[index1*2+1]) * barycentricCoordsOrLocalPosition.y
				+ vec2(vertexUV.uv[index2*2], vertexUV.uv[index2*2+1]) * barycentricCoordsOrLocalPosition.z
			);
		} else {
			return vec2(0);
		}
	}
	
	vec3 ComputeSurfaceNormal(in vec3 barycentricCoordsOrLocalPosition) {
		return ComputeSurfaceNormal(uint64_t(INSTANCE.geometries), gl_GeometryIndexEXT, gl_PrimitiveID, barycentricCoordsOrLocalPosition);
	}
	vec4 ComputeSurfaceColor(in vec3 barycentricCoordsOrLocalPosition) {
		return ComputeSurfaceColor(uint64_t(INSTANCE.geometries), gl_GeometryIndexEXT, gl_PrimitiveID, barycentricCoordsOrLocalPosition);
	}
	vec2 ComputeSurfaceUV1(in vec3 barycentricCoordsOrLocalPosition) {
		return ComputeSurfaceUV1(uint64_t(INSTANCE.geometries), gl_GeometryIndexEXT, gl_PrimitiveID, barycentricCoordsOrLocalPosition);
	}
	vec2 ComputeSurfaceUV2(in vec3 barycentricCoordsOrLocalPosition) {
		return ComputeSurfaceUV2(uint64_t(INSTANCE.geometries), gl_GeometryIndexEXT, gl_PrimitiveID, barycentricCoordsOrLocalPosition);
	}
	
#endif

#if defined(SHADER_RCHIT)

	layout(location = 0) rayPayloadInEXT RayPayload ray;
	
	void RayHit(in vec3 color, in vec3 localNormal, in float hitDistance, in float roughness, in float ior, uint8_t surfaceFlags) {
		ray.color = color;
		ray.hitDistance = hitDistance;
		ray.normal = normalize(MODEL2WORLDNORMAL * localNormal);
		ray.renderableIndex = gl_InstanceID;
		ray.localPosition = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * hitDistance;
		ray.roughness = uint8_t(roughness * 255);
		ray.ior = uint8_t(clamp(ior, 0, 5) * 51);
		ray.surfaceFlags = surfaceFlags;
	}
	
	void RayHitWorld(in vec3 color, in vec3 worldNormal, in float hitDistance, in float roughness, in float ior, uint8_t surfaceFlags) {
		ray.color = color;
		ray.hitDistance = hitDistance;
		ray.normal = worldNormal;
		ray.renderableIndex = gl_InstanceID;
		ray.localPosition = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * hitDistance;
		ray.roughness = uint8_t(roughness * 255);
		ray.ior = uint8_t(clamp(ior, 0, 5) * 51);
		ray.surfaceFlags = surfaceFlags;
	}
	
	void MakeAimable(in vec3 localNormal, in vec2 uv, uint monitorIndex) {
		if ((ray.rayFlags & RAY_FLAG_AIM) != 0) {
			ray.rayFlags &= ~RAY_FLAG_AIM;
			if (renderer.aim.aimID == 0) {
				renderer.aim.uv = uv;
				renderer.aim.localPosition = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * gl_HitTEXT;
				renderer.aim.geometryIndex = gl_GeometryIndexEXT;
				renderer.aim.aimID = gl_InstanceCustomIndexEXT;
				renderer.aim.worldSpaceHitNormal = normalize(MODEL2WORLDNORMAL * localNormal);
				renderer.aim.primitiveIndex = gl_PrimitiveID;
				renderer.aim.worldSpacePosition = gl_WorldRayOriginEXT + gl_WorldRayDirectionEXT * gl_HitTEXT;
				renderer.aim.hitDistance = distance(vec3(inverse(renderer.viewMatrix)[3]), renderer.aim.worldSpacePosition);
				// renderer.aim.color = vec4(ray.color, (ray.surfaceFlags & RAY_SURFACE_TRANSPARENT) == 0 ? 1 : 0); // we may not have the ray color yet from here
				renderer.aim.viewSpaceHitNormal = normalize(WORLD2VIEWNORMAL * renderer.aim.worldSpaceHitNormal);
				renderer.aim.tlasInstanceIndex = gl_InstanceID;
				if (monitorIndex != 0) {
					renderer.aim.monitorIndex = monitorIndex;
				}
			}
		}
	}
	
	// Back Face: flip normal and inverse index of refraction
	void AutoFlipNormal(inout vec3 localNormal, inout float ior) {
		if (dot(localNormal, gl_ObjectRayDirectionEXT) > 0) {
			ior = 0;
			localNormal *= -1;
		}
	}
	
	void HandleDefaultInstanceData(uint64_t instanceData, inout vec4 color, inout vec3 localNormal, inout float metallic, inout float roughness, inout float ior, inout vec3 emission, inout vec2 uv1) {
		if (instanceData != 0) {
			RenderableData data = RenderableData(instanceData)[gl_GeometryIndexEXT];
			emission += data.emission;
			color = mix(color, data.color, data.colorMix);
			metallic = mix(metallic, data.pbrMetallic, data.pbrMix);
			roughness = mix(roughness, data.pbrRoughness, data.pbrMix);
			if (data.monitorIndex > 0) {
				emission *= ReverseGamma(texture(textures[nonuniformEXT(data.monitorIndex)], uv1).rgb);
				emission /= GetCurrentExposure();
			}
			MakeAimable(localNormal, uv1, data.monitorIndex);
		} else {
			MakeAimable(localNormal, uv1, 0);
		}
	}

	void HandleDefaultMaterialData(uint64_t geometryMaterialData, inout vec4 color, inout vec3 localNormal, inout float metallic, inout float roughness, inout float ior, inout vec3 emission, inout vec2 uv1) {
		if (geometryMaterialData > 0) {
			uint16_t tex_albedo = 				uint16_t((geometryMaterialData) & 0xffff);
			uint16_t tex_normal = 				uint16_t((geometryMaterialData >> 16) & 0xffff);
			uint16_t tex_metallic_roughness = 	uint16_t((geometryMaterialData >> 32) & 0xffff);
			uint16_t tex_emission = 			uint16_t((geometryMaterialData >> 48) & 0xffff);
			if (tex_albedo > 0) color.rgb *= ReverseGamma(texture(textures[nonuniformEXT(tex_albedo)], uv1).rgb);
			if (tex_normal > 0) {
				//TODO: normal maps using tex_normal
			}
			if (tex_metallic_roughness > 0) {
				vec2 pbr = texture(textures[nonuniformEXT(tex_metallic_roughness)], uv1).rg;
				metallic = pbr.r;
				roughness = pbr.g;
			}
			if (tex_emission > 0) {
				vec3 emissionPower = vec3(10);
				// if (instanceData != 0) {
				// 	emissionPower = emission;
				// }
				emission = emissionPower * ReverseGamma(texture(textures[nonuniformEXT(tex_emission)], uv1).rgb);
			}
		}
	}

#endif

#if defined(SHADER_RAHIT)
	
	layout(location = 0) rayPayloadInEXT RayShadowPayload ray;
	
	void RayTransparent(in vec3 transparency) {
		ray.colorAttenuation *= transparency;
		ignoreIntersectionEXT;
	}
	
	void RayOpaque() {
		ray.colorAttenuation = vec3(0);
		terminateRayEXT;
	}
	
#endif
