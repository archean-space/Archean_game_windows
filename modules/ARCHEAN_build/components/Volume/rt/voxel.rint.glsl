#define SHADER_RINT
#include "game/graphics/common.inc.glsl"
#include "../../../common.inc.glsl"

#define EPSILON 0.001

float VoxelClosestHitDDA() {
	COMPUTE_BOX_INTERSECTION // retrieves T1 and T2
	VolumeData volumeData = VolumeData(AABB.data);
	
	const float startT = max(gl_RayTminEXT, T1 + EPSILON);
	const int maxIterations = 7;
	const int maxIterations_hd = 10;
	const vec3 rayDir = gl_ObjectRayDirectionEXT;
	const vec3 stepDir = sign(rayDir);
	const ivec3 iStepDir = ivec3(stepDir);
	const vec3 rayOrigin = gl_ObjectRayOriginEXT - AABB_MIN;
	const vec3 rayPos = (rayOrigin + rayDir * startT);
	const vec3 stepSize = abs(1.0 / rayDir);
	
	ivec3 iPos = ivec3(floor(rayPos));
	
	// Calculate initial tMax values (distance to first intersection for each axis)
	vec3 tMax = stepDir * (vec3(iPos) - rayPos + (stepDir * 0.5 + 0.5)) * stepSize;
	
	float currentDepth = max(0, T1);
	
	for (int i = 0; i < maxIterations; i++) {
		if (IsValidVoxel(iPos)) {
			// Find axis of next crossing
			float depth = min(min(tMax.x, tMax.y), tMax.z) + startT;
			uint voxelIndex = VOXEL_INDEX(iPos.x, iPos.y, iPos.z);
			uint64_t occupancy = volumeData.occupancy[voxelIndex];
			if (occupancy != 0) {
				if (occupancy == VOXEL_FULL) {
					if (depth > gl_RayTmaxEXT) {
						depth = gl_RayTmaxEXT;
					}
					return currentDepth;
				} else {
					// HD voxels
					vec3 localPos = fract(rayPos) * VOXELS_HD;
					ivec3 hdPos = ivec3(floor(localPos));
					vec3 hdStepSize = stepSize / VOXELS_HD;
					// Align to HD voxel boundaries
					vec3 hdTMax = stepDir * (vec3(hdPos) - localPos + (stepDir * 0.5 + 0.5)) * hdStepSize;
					hdTMax += currentDepth; // Offset by current main voxel depth
					
					float hdCurrentDepth = currentDepth;
					for (int j = 0; j < maxIterations_hd && IsValidVoxelHD(hdPos); j++) {
						float hdDepth = min(min(hdTMax.x, hdTMax.y), hdTMax.z) - currentDepth;
						if (hdDepth > depth - currentDepth) break;
						if (hdDepth > gl_RayTmaxEXT - currentDepth) {
							hdDepth = gl_RayTmaxEXT - currentDepth;
						}
						
						uint voxelIndexHD = VOXEL_INDEX_HD(hdPos.x, hdPos.y, hdPos.z);
						if ((occupancy & (1ul << voxelIndexHD)) != 0) {
							return hdCurrentDepth;
						}
						
						hdCurrentDepth = hdDepth + currentDepth;
						bvec3 mask = equal(hdTMax - currentDepth, vec3(hdDepth));
						hdTMax += vec3(mask) * hdStepSize;
						hdPos += ivec3(mask) * iStepDir;
					}
				}
			}
			if (depth > gl_RayTmaxEXT) {
				break;
			}
			currentDepth = depth;
			// Step to next voxel
			bvec3 mask = equal(tMax, vec3(depth));
			tMax += vec3(mask) * stepSize;
			iPos += ivec3(mask) * iStepDir;
		} else {
			break;
		}
	}
	return -1;
}

void main() {
	float voxelDepth = VoxelClosestHitDDA();
	if (voxelDepth >= 0) {
		reportIntersectionEXT(max(gl_RayTminEXT, voxelDepth), 0);
	}
}
