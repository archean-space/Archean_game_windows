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
	vec3 rockSize = clamp(vec3(float(chunk.triangleSize * 0.25)), vec3(0.05), vec3(0.5, 0.2, 0.5)) * vec3(
		(0.3f + RandomFloat(clutterSeed) * 0.7),
		(0.3f + RandomFloat(clutterSeed) * 0.7),
		(0.3f + RandomFloat(clutterSeed) * 0.7)
	);
	
	// Position
	dvec3 posNorm = normalize(topLeftPos + (topRightPos - topLeftPos) * barycentricHorizontal + (bottomLeftPos - topLeftPos) * barycentricVertical);
	double height = GetHeightMap(posNorm);
	
	// Density
	float inverseDensityProb = RandomFloat(clutterSeed);
	if (inverseDensityProb*inverseDensityProb > GetClutterDensity(posNorm, height)) {
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
