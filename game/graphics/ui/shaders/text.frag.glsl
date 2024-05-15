#include "text_common.inc.glsl"
#include "xenon/renderer/shaders/common.inc.glsl"

layout(location = 0) in flat uint in_char;
layout(location = 0) out vec4 out_color;

void main() {
	float charPos = max(0, int(in_char) - 32); // will get a value between 0(space) and 94 (~)
	// The font atlas used is a 10x10 grid
	float grid = 10;
	vec2 coord = vec2(
		gl_PointCoord.x / grid + floor(mod(charPos, grid))/grid,
		gl_PointCoord.y / grid + floor(charPos/grid)/grid
	);
	float fill = texture(textures[0], coord).r;
	if (fill == 0) discard;
	out_color = color * fill;
}
