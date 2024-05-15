#include "overlay.inc.glsl"

layout(location = 0) out vec4 out_position;
layout(location = 1) out vec4 out_color;
layout(location = 2) out vec3 out_localPos;

void main() {
	vec4 vertex;
	
	if (uint64_t(vertexBuffer) != 0 && uint64_t(indexBuffer) != 0) {
		uint index = indexBuffer.indices[gl_VertexIndex];
		vertex = vec4(
			vertexBuffer.vertices[index * 3 + 0],
			vertexBuffer.vertices[index * 3 + 1],
			vertexBuffer.vertices[index * 3 + 2],
			1
		);
	} else if (gl_VertexIndex == 0) {
		vertex = vec4(begin.xyz, 1);
	} else {
		vertex = vec4(end.xyz, 1);
	}
	
	out_localPos = vertex.xyz;
	gl_Position = out_position = xenonRendererData.config.projectionMatrix * modelViewMatrix * vertex;
	
	out_color = color;
}
