#ifdef __cplusplus
	#pragma once
#endif

#ifdef GLSL
	#extension GL_ARB_shader_clock : enable
	#extension GL_EXT_ray_tracing : require
#endif

#include "game/graphics/common.inc.glsl"
#include "game/graphics/voxel.inc.glsl"

#define RAY_MAX_RECURSION 8

#define SET1_BINDING_TLAS 0
#define SET1_BINDING_LIGHTS_TLAS 1
#define SET1_BINDING_RENDERER_DATA 2
#define SET1_BINDING_RT_PAYLOAD_IMAGE 3
#define SET1_BINDING_PRIMARY_ALBEDO_ROUGHNESS_IMAGE 4
#define SET1_BINDING_POST_HISTORY_IMAGE 5
#define SET1_BINDING_BLOOM_IMAGE 6
#define SET1_BINDING_CLOUD_IMAGE 7
#define SET1_BINDING_CLOUD_SAMPLER 8

// xenonRendererData.config.debugViewMode
#define RENDERER_DEBUG_VIEWMODE_NONE 0
#define RENDERER_DEBUG_VIEWMODE_RAYGEN_TIME 1
#define RENDERER_DEBUG_VIEWMODE_RAYHIT_TIME 2
#define RENDERER_DEBUG_VIEWMODE_RAYINT_TIME 3
#define RENDERER_DEBUG_VIEWMODE_TRACE_RAY_COUNT 4
#define RENDERER_DEBUG_VIEWMODE_NORMALS 5
#define RENDERER_DEBUG_VIEWMODE_MOTION 6
#define RENDERER_DEBUG_VIEWMODE_DISTANCE 7
#define RENDERER_DEBUG_VIEWMODE_UVS 8
#define RENDERER_DEBUG_VIEWMODE_ALPHA 9
#define RENDERER_DEBUG_VIEWMODE_AIM_RENDERABLE 10
#define RENDERER_DEBUG_VIEWMODE_AIM_GEOMETRY 11
#define RENDERER_DEBUG_VIEWMODE_AIM_PRIMITIVE 12
#define RENDERER_DEBUG_VIEWMODE_SSAO 13
#define RENDERER_DEBUG_VIEWMODE_DIRECT_LIGHTS 14
#define RENDERER_DEBUG_VIEWMODE_GI_LIGHTS 15
#define RENDERER_DEBUG_VIEWMODE_GLOBAL_ILLUMINATION 16
#define RENDERER_DEBUG_VIEWMODE_ENVIRONMENT_AUDIO 17
#define RENDERER_DEBUG_VIEWMODE_DENOISING_FACTOR 18
#define RENDERER_DEBUG_VIEWMODE_TEST 19

#ifdef __cplusplus
	#define RENDERER_DEBUG_VIEWMODES_STR \
		"NONE",\
		"Ray Gen Time",\
		"Ray Hit Time",\
		"Ray Intersection Time",\
		"Ray Trace Count",\
		"Normals",\
		"Motion Vectors",\
		"Distance",\
		"UVs",\
		"Alpha",\
		"Aim Renderable",\
		"Aim Geometry",\
		"Aim Primitive",\
		"SSAO",\
		"Direct Lights",\
		"Gi Lights",\
		"Global Illumination",\
		"Environment Audio",\
		"Denoising Factor",\
		"Test",\
		
#endif

////////////////////////////////////

#define RAYTRACE_MASK_TERRAIN 1u
#define RAYTRACE_MASK_ENTITY 2u
#define RAYTRACE_MASK_ATMOSPHERE 4u
#define RAYTRACE_MASK_HYDROSPHERE 8u
#define RAYTRACE_MASK_CLUTTER 16u
#define RAYTRACE_MASK_PLASMA 32u
#define RAYTRACE_MASK_LIGHT 64u
// #define RAYTRACE_MASK_____ 128u

#ifdef __cplusplus
	inline static constexpr uint32_t RAYTRACE_MASKS[] { // must match the order of renderable types
		/*  0	RENDERABLE_TYPE_TERRAIN_TRI */		RAYTRACE_MASK_TERRAIN,
		/*  1	RENDERABLE_TYPE_ENTITY_TRI */		RAYTRACE_MASK_ENTITY,
		/*  2	RENDERABLE_TYPE_ENTITY_BOX */		RAYTRACE_MASK_ENTITY,
		/*  3	RENDERABLE_TYPE_ENTITY_SPHERE */	RAYTRACE_MASK_ENTITY,
		/*  4	RENDERABLE_TYPE_ATMOSPHERE */		RAYTRACE_MASK_ATMOSPHERE,
		/*  5	RENDERABLE_TYPE_HYDROSPHERE */		RAYTRACE_MASK_HYDROSPHERE,
		/*  6	RENDERABLE_TYPE_ENTITY_VOXEL */		RAYTRACE_MASK_ENTITY,
		/*  7	RENDERABLE_TYPE_CLUTTER_TRI */		RAYTRACE_MASK_CLUTTER,
		/*  8	RENDERABLE_TYPE_PLASMA */			RAYTRACE_MASK_PLASMA,
		/*  9	RENDERABLE_TYPE_LIGHT_BOX */		RAYTRACE_MASK_LIGHT,
		/* 10	RENDERABLE_TYPE_CLUTTER_PIPE */		RAYTRACE_MASK_CLUTTER,
		/* 11	RENDERABLE_TYPE_CLUTTER_ROCK */		RAYTRACE_MASK_CLUTTER,
		/* 12	RENDERABLE_TYPE_PROPELLER */		RAYTRACE_MASK_ENTITY,
		/* 13	RENDERABLE_TYPE_CLUTTER_BOX */		RAYTRACE_MASK_CLUTTER,
	};
#endif

// Up to 32 options
#define RENDERER_OPTION_DIRECT_LIGHTING		(1u<< 0 )
#define RENDERER_OPTION_INDIRECT_LIGHTING	(1u<< 1 )
#define RENDERER_OPTION_GLASS_REFLECTIONS	(1u<< 2 )
#define RENDERER_OPTION_GLASS_REFRACTION	(1u<< 3 )
#define RENDERER_OPTION_WATER_REFLECTIONS	(1u<< 4 )
#define RENDERER_OPTION_WATER_TRANSPARENCY	(1u<< 5 )
#define RENDERER_OPTION_WATER_REFRACTION	(1u<< 6 )
#define RENDERER_OPTION_WATER_WAVES			(1u<< 7 )
#define RENDERER_OPTION_ATMOSPHERIC_SHADOWS	(1u<< 8 )
#define RENDERER_OPTION_SPECULAR_SURFACES	(1u<< 9 )

BUFFER_REFERENCE_STRUCT(16) GlobalIllumination {
	aligned_f32vec4 bestSample;
	aligned_f32vec4 variance;
};
STATIC_ASSERT_ALIGNED16_SIZE(GlobalIllumination, 32);

BUFFER_REFERENCE_STRUCT(16) GlobalIllumination0 {
	aligned_f32vec4 radiance;
	aligned_u32vec4 pos;
	aligned_int64_t frameIndex;
	aligned_uint32_t iteration;
	aligned_uint32_t lock;
};
STATIC_ASSERT_ALIGNED16_SIZE(GlobalIllumination0, 48);

BUFFER_REFERENCE_STRUCT(16) GlobalIllumination1 {
	aligned_f32vec4 radiance;
	aligned_u32vec4 pos;
	aligned_int64_t frameIndex;
	aligned_uint32_t iteration;
	aligned_uint32_t lock;
};
STATIC_ASSERT_ALIGNED16_SIZE(GlobalIllumination1, 48);

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
	BUFFER_REFERENCE_ADDR(GlobalIllumination) globalIllumination;
	BUFFER_REFERENCE_ADDR(GlobalIllumination0) globalIllumination0;
	BUFFER_REFERENCE_ADDR(GlobalIllumination1) globalIllumination1;
	BUFFER_REFERENCE_ADDR(LightSourceInstanceTable) lightSources;
	BUFFER_REFERENCE_ADDR(EnvironmentAudioData) environmentAudio;
	
	aligned_f32vec3 wireframeColor;
	aligned_float32_t wireframeThickness;
	
	aligned_i32vec3 worldOrigin;
	aligned_uint32_t globalIlluminationTableCount;
	
	aligned_float64_t timestamp;
	aligned_uint32_t rays_max_bounces;
	aligned_float32_t warp;
	
	aligned_uint32_t giIteration;
	aligned_float32_t cameraZNear;
	aligned_float32_t globalLightingFactor;
	aligned_uint32_t options; // RENDERER_OPTION_*
	
	aligned_float32_t globalIlluminationVoxelSize;
	aligned_int32_t atmosphere_raymarch_steps;
	aligned_float32_t terrain_clutter_detail;
	aligned_float32_t _unused3;
	
	aligned_uint32_t bluenoise_scalar;
	aligned_uint32_t bluenoise_unitvec1;
	aligned_uint32_t bluenoise_unitvec2;
	aligned_uint32_t bluenoise_unitvec3;
	aligned_uint32_t bluenoise_unitvec3_cosine;
	aligned_uint32_t bluenoise_vec1;
	aligned_uint32_t bluenoise_vec2;
	aligned_uint32_t bluenoise_vec3;
};
STATIC_ASSERT_ALIGNED16_SIZE(RendererData, 3*64 + 12*8 + 5*16 + 4*8);

#ifdef GLSL
	#define BLUE_NOISE_NB_TEXTURES 64
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
	#else
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
	#endif
	#define COORDS ivec2(gl_LaunchIDEXT.xy)
	#define WRITE_DEBUG_TIME {float elapsedTime = imageLoad(img_normal_or_debug, COORDS).a + float(clockARB() - startTime); imageStore(img_normal_or_debug, COORDS, vec4(0,0,0, elapsedTime));}
	#define DEBUG_RAY_INT_TIME {if (xenonRendererData.config.debugViewMode == RENDERER_DEBUG_VIEWMODE_RAYINT_TIME) WRITE_DEBUG_TIME}
	#define traceRayEXT {if (xenonRendererData.config.debugViewMode == RENDERER_DEBUG_VIEWMODE_TRACE_RAY_COUNT) imageStore(img_normal_or_debug, COORDS, imageLoad(img_normal_or_debug, COORDS) + uvec4(0,0,0,1));} traceRayEXT
	#define DEBUG_TEST(color) {if (xenonRendererData.config.debugViewMode == RENDERER_DEBUG_VIEWMODE_TEST) imageStore(img_normal_or_debug, COORDS, color);}
	#define RAY_RECURSIONS imageLoad(rtPayloadImage, COORDS).r
	#define RAY_RECURSION_PUSH imageStore(rtPayloadImage, COORDS, imageLoad(rtPayloadImage, COORDS) + u8vec4(1,0,0,0));
	#define RAY_RECURSION_POP imageStore(rtPayloadImage, COORDS, imageLoad(rtPayloadImage, COORDS) - u8vec4(1,0,0,0));
	#define RAY_IS_SHADOW (imageLoad(rtPayloadImage, COORDS).g > 0)
	#define RAY_SHADOW_PUSH imageStore(rtPayloadImage, COORDS, imageLoad(rtPayloadImage, COORDS) + u8vec4(0,1,0,0));
	#define RAY_SHADOW_POP imageStore(rtPayloadImage, COORDS, imageLoad(rtPayloadImage, COORDS) - u8vec4(0,1,0,0));
	#define RAY_IS_GI (imageLoad(rtPayloadImage, COORDS).b > 0)
	#define RAY_GI_PUSH imageStore(rtPayloadImage, COORDS, imageLoad(rtPayloadImage, COORDS) + u8vec4(0,0,1,0));
	#define RAY_GI_POP imageStore(rtPayloadImage, COORDS, imageLoad(rtPayloadImage, COORDS) - u8vec4(0,0,1,0));
	#define RAY_IS_UNDERWATER (imageLoad(rtPayloadImage, COORDS).a > 0)
	#define RAY_UNDERWATER imageLoad(rtPayloadImage, COORDS).a
	#define RAY_UNDERWATER_PUSH imageStore(rtPayloadImage, COORDS, imageLoad(rtPayloadImage, COORDS) + u8vec4(0,0,0,1));
	#define RAY_UNDERWATER_POP imageStore(rtPayloadImage, COORDS, imageLoad(rtPayloadImage, COORDS) - u8vec4(0,0,0,1));
	#define ATMOSPHERE_RAY_MIN_DISTANCE 200
	#define WATER_MAX_LIGHT_DEPTH 128
	#define WATER_MAX_LIGHT_DEPTH_VERTICAL 256

	layout(set = 1, binding = SET1_BINDING_RENDERER_DATA) uniform RendererDataBuffer { RendererData renderer; };
	layout(set = 1, binding = SET1_BINDING_RT_PAYLOAD_IMAGE, rgba8ui) uniform uimage2D rtPayloadImage; // Recursions, Shadow, Gi, Underwater
	layout(set = 1, binding = SET1_BINDING_PRIMARY_ALBEDO_ROUGHNESS_IMAGE, rgba8) uniform image2D img_primary_albedo_roughness;
	layout(set = 1, binding = SET1_BINDING_POST_HISTORY_IMAGE, rgba8) uniform image2D img_post_history;
	layout(set = 1, binding = SET1_BINDING_BLOOM_IMAGE, rgba8) uniform image2D img_bloom;
	layout(set = 1, binding = SET1_BINDING_CLOUD_IMAGE, rgba32f) uniform image2D img_cloud[2];
	layout(set = 1, binding = SET1_BINDING_CLOUD_SAMPLER) uniform sampler2D sampler_cloud;
	
	#define WORLD2VIEWNORMAL transpose(inverse(mat3(renderer.viewMatrix)))
	#define VIEW2WORLDNORMAL transpose(mat3(renderer.viewMatrix))
	
	#ifdef SHADER_RCHIT
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
	
	struct RayPayload {
		vec4 color;
		vec3 normal;
		float ssao;
		vec3 localPosition;
		float t2;
		vec3 worldPosition;
		float hitDistance;
		int aimID;
		int renderableIndex;
		int geometryIndex;
		int primitiveIndex;
		vec4 plasma;
	};

	#if defined(SHADER_RGEN) || defined(SHADER_RCHIT) || defined(SHADER_COMP_RAYS)
		#extension GL_EXT_ray_query : require
		layout(set = 1, binding = SET1_BINDING_TLAS) uniform accelerationStructureEXT tlas;
		layout(set = 1, binding = SET1_BINDING_LIGHTS_TLAS) uniform accelerationStructureEXT tlas_lights;
	#endif

	#if defined(SHADER_RGEN) || defined(SHADER_RCHIT) || defined(SHADER_RAHIT) || defined(SHADER_RINT) || defined(SHADER_RMISS)
		uint64_t startTime = clockARB();
		uint stableSeed = InitRandomSeed(gl_LaunchIDEXT.x, gl_LaunchIDEXT.y);
		uint coherentSeed = InitRandomSeed(uint(xenonRendererData.frameIndex),0);
		uint temporalSeed = uint(int64_t(renderer.timestamp * 1000) % 1000000);
		uint seed = InitRandomSeed(stableSeed, coherentSeed);
	#endif
	
	#if defined(SHADER_RCHIT) || defined(SHADER_RAHIT)
		layout(location = 0) rayPayloadInEXT RayPayload ray;
	#endif

	#if defined(SHADER_RCHIT) || defined(SHADER_RAHIT) || defined(SHADER_RINT)
		bool IsValidVoxel(in ivec3 iPos, in vec3 gridOffset) {
			if (iPos.x < 0 || iPos.y < 0 || iPos.z < 0) return false;
			if (iPos.x >= VOXELS_X || iPos.y >= VOXELS_Y || iPos.z >= VOXELS_Z) return false;
			if (iPos.x < AABB_MIN.x - gridOffset.x) return false;
			if (iPos.y < AABB_MIN.y - gridOffset.y) return false;
			if (iPos.z < AABB_MIN.z - gridOffset.z) return false;
			if (iPos.x >= AABB_MAX.x - gridOffset.x) return false;
			if (iPos.y >= AABB_MAX.y - gridOffset.y) return false;
			if (iPos.z >= AABB_MAX.z - gridOffset.z) return false;
			return true;
		}
		bool IsValidVoxelHD(in ivec3 iPos) {
			if (iPos.x < 0 || iPos.y < 0 || iPos.z < 0) return false;
			if (iPos.x >= VOXEL_GRID_SIZE_HD || iPos.y >= VOXEL_GRID_SIZE_HD || iPos.z >= VOXEL_GRID_SIZE_HD) return false;
			return true;
		}
		const vec3[7] BOX_NORMAL_DIRS = {
			vec3(-1,0,0),
			vec3(0,-1,0),
			vec3(0,0,-1),
			vec3(+1,0,0),
			vec3(0,+1,0),
			vec3(0,0,+1),
			vec3(0)
		};
	#endif
#endif
