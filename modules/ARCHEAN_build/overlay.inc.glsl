#ifdef __cplusplus
	#pragma once
	using namespace glm;
#endif

#include "game/graphics/common.inc.glsl"

PUSH_CONSTANT_STRUCT OverlayPushConstant {
	aligned_f32mat4 modelViewMatrix;
	aligned_f32vec4 color;
	aligned_f32vec3 begin;
	aligned_float32_t _unused;
	aligned_f32vec3 end;
	aligned_float32_t radius;
	BUFFER_REFERENCE_ADDR(VertexBuffer) vertexBuffer;
	BUFFER_REFERENCE_ADDR(IndexBuffer16) indexBuffer;
};
STATIC_ASSERT_PUSH_CONSTANT(OverlayPushConstant)
