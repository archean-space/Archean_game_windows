#include "box_common.inc.glsl"
#include "xenon/renderer/shaders/common.inc.glsl"

const vec2 vertices[4] = {
	vec2(-0.5,+0.5),
	vec2(-0.5,-0.5),
	vec2(+0.5,+0.5),
	vec2(+0.5,-0.5)
};

layout(location = 0) out vec2 out_uv;

void main() {
	ivec2 screenSize = xenonRendererData.config.screenSize;
	float screenRatio = float(screenSize.x) / float(screenSize.y);
	vec2 boxPos = vec2(box.x, box.y);
	vec2 boxSize = vec2(box.width/screenRatio, box.height);
	if (boxSize.x == 0) boxSize.x = 2;
	if (boxSize.y == 0) boxSize.y = 2;
	gl_Position = vec4(boxPos + vertices[gl_VertexIndex] * boxSize, 0, 1);
	out_uv = vertices[gl_VertexIndex] + vec2(0.5);
}
