#extension GL_EXT_buffer_reference2 : require

layout(local_size_x = COMPUTE_SIZE_X, local_size_y = COMPUTE_SIZE_Y) in;

vec3 GetVertex(in uint index) {
	return vec3(vertices[index*3].vertex, vertices[index*3+1].vertex, vertices[index*3+2].vertex);
}

uint32_t computeSize = chunk.vertexSubdivisions + 1;
uint32_t genCol = gl_GlobalInvocationID.x;
uint32_t genRow = gl_GlobalInvocationID.y;
uint32_t currentIndex = computeSize * genRow + genCol;
uint32_t Xindex = currentIndex*3;
uint32_t Yindex = currentIndex*3+1;
uint32_t Zindex = currentIndex*3+2;

vec3 ComputeNormal() {
	vec3 currentVertex = GetVertex(currentIndex);
	dvec3 posNormRight = normalize((chunk.transform * dvec4(currentVertex + vec3(chunk.triangleSize*2,0,0), 1)).xyz);
	dvec3 posNormBottom = normalize((chunk.transform * dvec4(currentVertex + vec3(0,0,chunk.triangleSize*2), 1)).xyz);
	vec3 right = vec3((chunk.inverseTransform * dvec4(posNormRight * GetHeightMap(posNormRight), 1)).xyz);
	vec3 bottom = vec3((chunk.inverseTransform * dvec4(posNormBottom * GetHeightMap(posNormBottom), 1)).xyz);
	return normalize(cross(normalize(right - currentVertex), normalize(currentVertex - bottom)));
}

void main() {
	if (genCol >= computeSize || genRow >= computeSize) return;
	
	// Vertex
	dvec3 posNorm = normalize((chunk.transform * dvec4(GetVertex(currentIndex), 1)).xyz);
	
	// Height from topology algorithm
	dvec2 heightAndFeature = GetHeightMapAndFeature(posNorm);
	double height = heightAndFeature.x;
	double feature = heightAndFeature.y;
	if (feature == TERRAIN_FEATURE_LAVA) {
		chunk.temperature[currentIndex].temperature = 2000;
	}
	
	// Position
	dvec3 position = (chunk.inverseTransform * dvec4(posNorm * height, 1)).xyz;
	vertices[Xindex].vertex = float(position.x);
	vertices[Yindex].vertex = float(position.y);
	vertices[Zindex].vertex = float(position.z);
	
	// Normal
	#ifdef TERRAIN_MESH_GENERATE_SMOOTH_NORMALS
		vec3 normal = ComputeNormal();
		float slope = pow(max(0, dot(normal, vec3(0,1,0))), 4);
		if (uint64_t(normals) != 0) {
			normals[Xindex].normal = normal.x;
			normals[Yindex].normal = normal.y;
			normals[Zindex].normal = normal.z;
		}
	#else
		float slope = 1;
	#endif
	
	// Color/Splat
	vec4 splat = GetSplat(posNorm, height, slope, feature);
	colors[currentIndex].color = u8vec4(vec4(GetColor(posNorm, height, slope, feature, splat), 1) * 255.0f);
	
	// Height from Texture
	if (chunk.triangleSize < SMOOTH_SHADING_TRIANGLE_SIZE_THRESHOLD) {
		float bumpDisplacement[4];
		uint heights[4];
		bumpDisplacement[0] = chunk.texHeightDisplacement.x * splat.x;
		heights[0] = chunk.tex.x + Height;
		bumpDisplacement[1] = chunk.texHeightDisplacement.y * splat.y;
		heights[1] = chunk.tex.y + Height;
		bumpDisplacement[2] = chunk.texHeightDisplacement.z * splat.z;
		heights[2] = chunk.tex.z + Height;
		bumpDisplacement[3] = chunk.texHeightDisplacement.w * splat.w;
		heights[3] = chunk.tex.w + Height;
		dvec2 uvD = (chunk.uvOffset + dvec2(uvs[currentIndex].uv) * chunk.uvMult) * chunk.planetFaceSize;
		vec2 uv = vec2(fract(uvD / NEAR_TEXTURE_SPAN_METERS));
		for (uint i = 0; i < 4; ++i) {
			height += double(texture(textures[heights[i]], uv).r) * bumpDisplacement[i] - bumpDisplacement[i]/2;
		}
	}
	
	// Sand/Dust
	if (feature == TERRAIN_FEATURE_WAVY_SAND) {
		float sandWaves = 1 - pow(length(splat), 0.125);
		if (sandWaves > 0.01) {
			u64vec3 pos = u64vec3(posNorm * height * 1000 + 10000000000.0);
			double bump = perlint64f(pos * u64vec3(6,3,1), 4000, 4000, 8) * double(sandWaves);
			splat *= smoothstep(0.05, 0.0, float(bump));
			height += bump * 0.2;
		}
	}
	
	// Final Position
	position = (chunk.inverseTransform * dvec4(posNorm * height, 1)).xyz;
	vertices[Xindex].vertex = float(position.x);
	vertices[Yindex].vertex = float(position.y);
	vertices[Zindex].vertex = float(position.z);
	
	// Final Splat
	chunk.splats[currentIndex].splat = u8vec4(splat * 255.0);
	
	// Skirt
	int32_t skirtIndex = -1;
	if (genCol == 0) {
		skirtIndex = int(genRow);
	} else if (genCol == chunk.vertexSubdivisions) {
		skirtIndex = int(chunk.vertexSubdivisions*3 - genRow);
	} else if (genRow == 0) {
		skirtIndex = int(chunk.vertexSubdivisions*4 - genCol);
	} else if (genRow == chunk.vertexSubdivisions) {
		skirtIndex = int(chunk.vertexSubdivisions + genCol);
	}
	if (skirtIndex != -1) {
		skirtIndex = int(computeSize*computeSize + skirtIndex);
		
		posNorm = normalize((chunk.transform * dvec4(GetVertex(skirtIndex), 1)).xyz);
		height = min(height, GetHeightMap(posNorm));
		position = (chunk.inverseTransform * dvec4(posNorm * height, 1)).xyz;
		vertices[skirtIndex * 3 + 0].vertex = float(position.x);
		vertices[skirtIndex * 3 + 1].vertex = float(position.y) - chunk.skirtOffset;
		vertices[skirtIndex * 3 + 2].vertex = float(position.z);
		#ifdef TERRAIN_MESH_GENERATE_SMOOTH_NORMALS
			if (uint64_t(normals) != 0) {
				normals[skirtIndex * 3 + 0].normal = normals[Xindex].normal;
				normals[skirtIndex * 3 + 1].normal = normals[Yindex].normal;
				normals[skirtIndex * 3 + 2].normal = normals[Zindex].normal;
			}
		#endif
		colors[skirtIndex].color = colors[currentIndex].color;
		chunk.splats[skirtIndex].splat = chunk.splats[currentIndex].splat;
	}
}
