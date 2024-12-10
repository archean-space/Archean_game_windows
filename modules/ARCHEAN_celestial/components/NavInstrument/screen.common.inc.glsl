#include "game/graphics/common.inc.glsl"

#define SCREEN_COLOR(r,g,b,a) ((uint32_t(a) << 24) | (uint32_t(b) << 16) | (uint32_t(g) << 8) | uint32_t(r))
#define SCREEN_OVERLAY_WIDTH 200
#define SCREEN_OVERLAY_HEIGHT 200
#define SCREEN_COMPUTE_WIDTH 800
#define SCREEN_COMPUTE_HEIGHT 800
#define SCREEN_TEXT_SIZE_X 6
#define SCREEN_TEXT_SIZE_Y 7

PUSH_CONSTANT_STRUCT NavInstrumentPushConstant {
	aligned_f32vec3 planetUp;
	aligned_uint32_t mode;
	aligned_f32vec3 velocity;
	aligned_float32_t altitude;
	aligned_f32vec3 forward;
	aligned_float32_t periapsis;
	aligned_f32vec3 up;
	aligned_float32_t apoapsis;
	aligned_f32vec3 right;
	aligned_float32_t screenPowerCycle;
	aligned_f32vec3 targetDirection;
	aligned_float32_t targetDistance;
	aligned_float32_t targetSpeedRange;
	aligned_float32_t targetAltitudeRange;
	aligned_float32_t targetSpeed;
	aligned_float32_t targetAltitude;
	aligned_float32_t heading;
	aligned_float32_t planetInnerRadius;
	aligned_float32_t planetOuterRadius;
	aligned_uint32_t imageIndex;
};
STATIC_ASSERT_PUSH_CONSTANT(NavInstrumentPushConstant);
