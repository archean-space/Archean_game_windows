#include "game/graphics/common.inc.glsl"

layout(push_constant) uniform PushConstant {
	ScreenPushConstant screen;
};

layout(location = 0) out vec4 out_position;
layout(location = 1) out vec2 out_uv;

void main() {
	uint index = gl_VertexIndex;
	if (screen.indices16 != 0) index = IndexBuffer16(screen.indices16).indices[gl_VertexIndex];
	else if (screen.indices32 != 0) index = IndexBuffer32(screen.indices32).indices[gl_VertexIndex];
	vec3 vertex = vec3(
		VertexBuffer(screen.vertices).vertices[index * 3 + 0],
		VertexBuffer(screen.vertices).vertices[index * 3 + 1],
		VertexBuffer(screen.vertices).vertices[index * 3 + 2]
	);
	gl_Position = out_position = xenonRendererData.config.projectionMatrix * screen.modelViewMatrix * vec4(vertex, 1.0);
	if (screen.uv != 0) {
		VertexUV vertexUV = VertexUV(screen.uv);
		out_uv = vec2(vertexUV.uv[index * 2 + 0], vertexUV.uv[index * 2 + 1]);
	} else {
		uint topLeft = IndexBuffer16(screen.indices16).indices[7];
		uint bottomRight = IndexBuffer16(screen.indices16).indices[2];
		vec3 topLeftVertex = vec3(
			VertexBuffer(screen.vertices).vertices[topLeft * 3 + 0],
			VertexBuffer(screen.vertices).vertices[topLeft * 3 + 1],
			VertexBuffer(screen.vertices).vertices[topLeft * 3 + 2]
		);
		vec3 bottomRightVertex = vec3(
			VertexBuffer(screen.vertices).vertices[bottomRight * 3 + 0],
			VertexBuffer(screen.vertices).vertices[bottomRight * 3 + 1],
			VertexBuffer(screen.vertices).vertices[bottomRight * 3 + 2]
		);
		vec2 screenSize = (bottomRightVertex.xy - topLeftVertex.xy);
		vec2 pos = (vertex.xy - topLeftVertex.xy) / screenSize;
		out_uv = vec2(pos.x, 1 - pos.y);
	}
}
