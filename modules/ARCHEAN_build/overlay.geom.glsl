#include "overlay.inc.glsl"

layout (lines) in;
layout (triangle_strip, max_vertices = 24) out;

layout(location = 0) in vec4 in_position[];
layout(location = 1) in vec4 in_color[];
layout(location = 2) in vec3 in_localPos[];

layout(location = 0) out vec4 out_position;
layout(location = 1) out vec4 out_color;
layout(location = 2) out vec3 out_localPos;

void main() {
	vec3 v[8];
	int indices[24];
	
	if (radius > 0) {
		vec3 direction = normalize(in_localPos[1] - in_localPos[0]);
		vec3 up = abs(dot(direction, vec3(0.0, 1.0, 0.0))) < 0.9 ? vec3(0.0, 1.0, 0.0) : vec3(0.0, 0.0, 1.0);
		vec3 right = normalize(cross(direction, up));
		up = normalize(cross(right, direction));
		
		up *= radius;
		right *= radius;
		
		vec3 faceA = in_localPos[0];
		vec3 faceB = in_localPos[1];
		
		v[0] = faceA -up -right;
		v[1] = faceA -up +right;
		v[2] = faceA +up -right;
		v[3] = faceA +up +right;
		v[4] = faceB -up -right;
		v[5] = faceB -up +right;
		v[6] = faceB +up -right;
		v[7] = faceB +up +right;
	} else {
		vec3 box_min = in_localPos[0];
		vec3 box_max = in_localPos[1];
		
		v[0] = vec3(box_min.x, box_min.y, box_min.z);// -x -y -z;
		v[1] = vec3(box_max.x, box_min.y, box_min.z);// +x -y -z;
		v[2] = vec3(box_min.x, box_max.y, box_min.z);// -x +y -z;
		v[3] = vec3(box_max.x, box_max.y, box_min.z);// +x +y -z;
		
		v[4] = vec3(box_min.x, box_min.y, box_max.z);// -x -y +z;
		v[5] = vec3(box_max.x, box_min.y, box_max.z);// +x -y +z;
		v[6] = vec3(box_min.x, box_max.y, box_max.z);// -x +y +z;
		v[7] = vec3(box_max.x, box_max.y, box_max.z);// +x +y +z;
	}

	int i = 0;
	indices[i++] = 0;
	indices[i++] = 4;
	indices[i++] = 1;
	indices[i++] = 5;
	indices[i++] = 2;
	indices[i++] = 6;
	indices[i++] = 3;
	indices[i++] = 7;
	indices[i++] = 0;
	indices[i++] = 4;
	indices[i++] = 2;
	indices[i++] = 6;
	indices[i++] = 1;
	indices[i++] = 5;
	indices[i++] = 3;
	indices[i++] = 7;
	indices[i++] = 0;
	indices[i++] = 1;
	indices[i++] = 2;
	indices[i++] = 3;
	indices[i++] = 4;
	indices[i++] = 5;
	indices[i++] = 6;
	indices[i++] = 7;
	
	for(int i = 0; i < 24; i++) {
		out_color = in_color[0];
		out_localPos = v[indices[i]];
		gl_Position = out_position = xenonRendererData.config.projectionMatrix * modelViewMatrix * vec4(out_localPos, 1.0);
		EmitVertex();
		if (i % 4 == 3) EndPrimitive();
	}
}
