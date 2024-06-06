#include "overlay.inc.glsl"

layout(location = 0) in vec4 in_position;
layout(location = 1) in vec4 in_color;
layout(location = 2) in vec3 in_localPos;

layout(location = 0) out vec4 out_color;

void main() {
	
	// depth test
	float overlayDepth = (in_position.z + 0.00001) / in_position.w;
	vec2 uv = gl_FragCoord.xy / xenonRendererData.config.screenSize.xy;
	float solidDepth = texture(sampler_depth, uv).r;
	if (overlayDepth < solidDepth) discard;
	
	out_color = in_color;
	
	// hologram effect
	uint seed = InitRandomSeed(uint(xenonRendererData.frameIndex), InitRandomSeed(uint(gl_FragCoord.x), uint(gl_FragCoord.y)));
	float time = float(xenonRendererData.time);
	float bars = fract(abs(in_localPos.y * 4)) < 0.01 ? in_localPos.z : in_localPos.y;
	out_color.a -= step(0.5, fract((-bars * 500 + time*50) / 16.0)) * .1;
	out_color.a += RandomFloat(seed) * .2 - .1;
}
