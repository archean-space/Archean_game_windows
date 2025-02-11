#include "game/graphics/common.inc.glsl"

layout(push_constant) uniform PushConstant {
	ScreenPushConstant screen;
};

layout(location = 0) in vec4 in_position;
layout(location = 1) in vec2 in_uv;
layout(location = 0) out vec4 out_post;

float GetTrueDistanceFromDepthBuffer(float depth) {
	if (depth == 0 || depth == 1) return xenonRendererData.config.zFar;
	return 2.0 * (xenonRendererData.config.zFar * xenonRendererData.config.zNear) / (xenonRendererData.config.zNear + xenonRendererData.config.zFar - (depth * 2.0 - 1.0) * (xenonRendererData.config.zNear - xenonRendererData.config.zFar));
}

const float maxScreenDistance = 10.0;

void main() {
	// depth test
	float screenDepth = in_position.z * 1.03 / in_position.w;
	float screenDistance = GetTrueDistanceFromDepthBuffer(screenDepth);
	if (screenDistance > maxScreenDistance) discard;
	vec2 uv = gl_FragCoord.xy / imageSize(img_emission);
	float solidDepth = texture(sampler_depth, uv).r;
	if (screenDepth < solidDepth) discard;
	vec4 color = texture(textures[screen.monitorIndex], in_uv) * xenonRendererData.config.globalLightingFactor;
	out_post = vec4(color.rgb, color.a * smoothstep(maxScreenDistance, maxScreenDistance/2, GetTrueDistanceFromDepthBuffer(screenDepth)));
	// out_post = vec4(in_uv, 0, 1);
}
