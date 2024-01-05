#include "xenon/graphics/interface.inc.glsl"

#define UI_TEXT_MAX_LENGTH 92

PUSH_CONSTANT_STRUCT UiElementTextPushConstant {
	aligned_f32vec4 color;
	aligned_float32_t x;
	aligned_float32_t y;
	aligned_float32_t size; // vertical size in NDC
	aligned_uint32_t length;
	aligned_uint32_t flags;
	aligned_uint32_t text[UI_TEXT_MAX_LENGTH/4];
};
STATIC_ASSERT_ALIGNED16_SIZE(UiElementTextPushConstant, 128)
