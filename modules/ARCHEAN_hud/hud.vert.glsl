const vec4[4] vertices = {
	vec4(+1.0, -1.0, 0, 1),
	vec4(-1.0, -1.0, 0, 1),
	vec4(+1.0, +1.0, 0, 1),
	vec4(-1.0, +1.0, 0, 1),
};

void main() {
	gl_Position = vertices[gl_VertexIndex];
}
