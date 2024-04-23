#extension GL_EXT_buffer_reference2 : require

layout(local_size_x = CLUTTER_COMPUTE_SIZE) in;

void main() {
	uint index = gl_GlobalInvocationID.x;
	
	AabbData rock = aabbData[nonuniformEXT(index)];
	if (rock.data != 0) return;
	
	uint clutterSeed = InitRandomSeed(uint(clutterData), index);

	double barycentricVertical = double(RandomFloat(clutterSeed));
	double barycentricHorizontal = double(RandomFloat(clutterSeed));
	
	// Size
	vec3 rockSize = vec3(float(clamp(chunk.triangleSize * 0.5, 0.02, 0.2))) * (0.5f + RandomFloat(clutterSeed) * 0.5) * vec3(
		RandomFloat(clutterSeed),
		RandomFloat(clutterSeed),
		RandomFloat(clutterSeed)
	);
	float minDim = max(0.02f, length(rockSize) * 0.25f);
	if (rockSize.x < minDim) rockSize.x += minDim;
	if (rockSize.y < minDim) rockSize.y += minDim;
	if (rockSize.z < minDim) rockSize.z += minDim;
	if (rockSize.y > rockSize.x) {
		float tmp = rockSize.y;
		rockSize.y = rockSize.x;
		rockSize.x = tmp;
	}
	if (rockSize.y > rockSize.z) {
		float tmp = rockSize.y;
		rockSize.y = rockSize.z;
		rockSize.z = tmp;
	}
	
	// Position
	dvec3 posNorm = normalize(topLeftPos + (topRightPos - topLeftPos) * barycentricHorizontal + (bottomLeftPos - topLeftPos) * barycentricVertical);
	double height = GetHeightMap(posNorm);
	
	// Density
	if (RandomFloat(clutterSeed) > GetClutterDensity(posNorm, height)) {
		return;
	}
	
	double altitude = height + double(rockSize.y)*0.4;
	dvec3 posOnPlanet = posNorm * altitude;
	vec3 rockPos = vec4(chunk.inverseTransform * dvec4(posOnPlanet, 1)).xyz;
	
	rock.aabb[0] = rockPos.x - rockSize.x;
	rock.aabb[1] = rockPos.y - rockSize.y;
	rock.aabb[2] = rockPos.z - rockSize.z;
	rock.aabb[3] = rockPos.x + rockSize.x;
	rock.aabb[4] = rockPos.y + rockSize.y;
	rock.aabb[5] = rockPos.z + rockSize.z;
	rock.data = uint64_t(clutterSeed);
}
