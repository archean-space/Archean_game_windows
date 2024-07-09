#define SHADER_COMP_RAYS

#include "game/graphics/common.inc.glsl"

layout(local_size_x = XENON_RENDERER_SCREEN_COMPUTE_LOCAL_SIZE_X, local_size_y = XENON_RENDERER_SCREEN_COMPUTE_LOCAL_SIZE_Y) in;
layout(set = 2, binding = 0, rg32f) uniform image2D images[];

layout(push_constant) uniform PushConstant {
	mat4 invViewMatrix;
	ivec2 blurDir;
	float boundingRadius;
	uint32_t imageIndex;
};

vec2 coord = vec2(gl_GlobalInvocationID.xy);
vec2 size = vec2(imageSize(images[imageIndex]).xy);
vec2 uv = coord / size;

void main() {
	// if (xenonRendererData.config.debugViewMode == RENDERER_DEBUG_VIEWMODE_TEST) {
	// 	float depth = imageLoad(images[imageIndex], ivec2(coord)).r;
	// 	imageStore(img_normal_or_debug, ivec2(coord/2), vec4(HeatmapClamped(depth / boundingRadius / 16), 1));
	// }
	
	vec2 uvMapped = (uv * 2 - 1) * boundingRadius;
	vec3 rayOrigin = (invViewMatrix * vec4(uvMapped.x, 0, uvMapped.y, 1)).xyz;
	vec3 rayDir = normalize((invViewMatrix * vec4(0,1,0,0)).xyz);
	
	float front = boundingRadius * 32;
	{
		rayQueryEXT rq;
		rayQueryInitializeEXT(rq, tlas, 0, RAYTRACE_MASK_ENTITY|RAYTRACE_MASK_CLUTTER, rayOrigin, 0, rayDir, boundingRadius * 2);
		while (rayQueryProceedEXT(rq)) {
			uint type = rayQueryGetIntersectionTypeEXT(rq, false);
			if (type == gl_RayQueryCandidateIntersectionAABBEXT) {
				COMPUTE_BOX_INTERSECTION(rq,false)
				if (RAY_STARTS_OUTSIDE_T1_T2(rq)) {
					front = min(front, T1);
				}
			} else {
				float t = rayQueryGetIntersectionTEXT(rq, false);
				if (t > 0) front = min(front, t);
			}
		}
	}
	front = max(0, front - boundingRadius * 2 / 256);
	
	float back = boundingRadius * 32;
	{
		rayOrigin += rayDir * boundingRadius * 2;
		rayDir *= -1;
		rayQueryEXT rq;
		rayQueryInitializeEXT(rq, tlas, 0, RAYTRACE_MASK_ENTITY|RAYTRACE_MASK_CLUTTER, rayOrigin, 0, rayDir, boundingRadius * 2);
		while (rayQueryProceedEXT(rq)) {
			uint type = rayQueryGetIntersectionTypeEXT(rq, false);
			if (type == gl_RayQueryCandidateIntersectionAABBEXT) {
				COMPUTE_BOX_INTERSECTION(rq,false)
				if (RAY_STARTS_OUTSIDE_T1_T2(rq)) {
					back = min(back, T1);
				}
			} else {
				float t = rayQueryGetIntersectionTEXT(rq, false);
				if (t > 0) back = min(back, t);
			}
		}
	}
	
	imageStore(images[imageIndex], ivec2(coord), vec4(front,back,0,1));
}
