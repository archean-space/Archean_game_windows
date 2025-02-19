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

const float maxScreenDistance = 25.0;

void main() {
	float screenDistance = GetTrueDistanceFromDepthBuffer(in_position.z / in_position.w);
	if (screenDistance > maxScreenDistance) discard;
	vec2 uv = gl_FragCoord.xy / imageSize(img_emission);
	vec4 solidDepth = textureGather(sampler_depth, uv, 0);
	float solidDistance = GetTrueDistanceFromDepthBuffer((solidDepth[0] + solidDepth[1] + solidDepth[2] + solidDepth[3]) / 4) + 0.02;
	if (screenDistance > solidDistance) discard;
	vec4 color = texture(textures[screen.monitorIndex], in_uv) * xenonRendererData.config.globalLightingFactor;
	out_post = vec4(color.rgb, color.a * smoothstep(maxScreenDistance, maxScreenDistance/2, screenDistance));
	// out_post = vec4(in_uv, 0, 1); // debug UVs
}
