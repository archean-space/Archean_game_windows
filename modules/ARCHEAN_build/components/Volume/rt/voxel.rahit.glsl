#define SHADER_RAHIT
#include "game/graphics/common.inc.glsl"
#include "../../../common.inc.glsl"

// #define EPSILON 0.001

// float VoxelDDA() {
// 	COMPUTE_BOX_INTERSECTION // retrieves T1 and T2
// 	VolumeData volumeData = VolumeData(AABB.data);
	
// 	// Traverse the volume using two levels of DDA
// 	// main voxels are 1x1x1 meters, can check occupancy using (IsValidVoxel(ivec3(x,y,z)) && volumeData.occupancy[VOXEL_INDEX(x,y,z)] != 0)
// 	// the occupancy is a uint64 with 1 bit per voxel forming 4x4x4 hd voxels (25cm diameter per hd voxel)
// 	// this implementation should recurse into the 4x4x4 hd voxels when a main voxel is not empty
// 	// Voxels are a translucent volume, we want to accumulate the total depth of occupied voxels, ignoring empty voxels, and stop when we reach endT
// 	// resulting voxel depth should be the precise distance the ray traveled through occupied voxels, in meters
	
// 	const float startT = max(gl_RayTminEXT, T1 + EPSILON);
// 	const float max_distance = ray.hitDistance - startT;
// 	const int maxIterations = 7;
// 	const int maxIterations_hd = 10;
// 	const vec3 rayDir = gl_ObjectRayDirectionEXT;
// 	const vec3 stepDir = sign(rayDir);
// 	const ivec3 iStepDir = ivec3(stepDir);
// 	const vec3 rayOrigin = gl_ObjectRayOriginEXT - AABB_MIN;
// 	const vec3 rayPos = (rayOrigin + rayDir * startT);
// 	const vec3 stepSize = abs(1.0 / rayDir);
	
// 	ivec3 iPos = ivec3(floor(rayPos));
	
// 	// Calculate initial tMax values (distance to first intersection for each axis)
// 	vec3 tMax = stepDir * (vec3(iPos) - rayPos + (stepDir * 0.5 + 0.5)) * stepSize;
	
// 	float voxelDepth = 0.0;
// 	float currentDepth = 0.0;
	
// 	for (int i = 0; i < maxIterations; i++) {
// 		if (IsValidVoxel(iPos)) {
// 			// Find axis of next crossing
// 			float depth = min(min(tMax.x, tMax.y), tMax.z);
// 			uint voxelIndex = VOXEL_INDEX(iPos.x, iPos.y, iPos.z);
// 			uint64_t occupancy = volumeData.occupancy[voxelIndex];
// 			if (occupancy != 0) {
// 				if (occupancy == VOXEL_FULL) {
// 					if (depth > max_distance) {
// 						depth = max_distance;
// 					}
// 					voxelDepth += depth - currentDepth;
// 				} else {
// 					// HD voxels
// 					vec3 localPos = fract(rayPos + rayDir * (currentDepth + EPSILON)) * VOXELS_HD;
// 					ivec3 hdPos = ivec3(floor(localPos));
// 					vec3 hdStepSize = stepSize / VOXELS_HD;
// 					// Align to HD voxel boundaries
// 					vec3 hdTMax = stepDir * (vec3(hdPos) - localPos + (stepDir * 0.5 + 0.5)) * hdStepSize;
// 					hdTMax += currentDepth; // Offset by current main voxel depth
					
// 					float hdCurrentDepth = currentDepth;
// 					for (int j = 0; j < maxIterations_hd && IsValidVoxelHD(hdPos); j++) {
// 						float hdDepth = min(min(hdTMax.x, hdTMax.y), hdTMax.z) - currentDepth;
// 						if (hdDepth > depth - currentDepth) break;
// 						if (hdDepth > max_distance - currentDepth) {
// 							hdDepth = max_distance - currentDepth;
// 						}
						
// 						uint voxelIndexHD = VOXEL_INDEX_HD(hdPos.x, hdPos.y, hdPos.z);
// 						if ((occupancy & (1ul << voxelIndexHD)) != 0) {
// 							voxelDepth += hdDepth - (hdCurrentDepth - currentDepth);
// 						}
						
// 						hdCurrentDepth = hdDepth + currentDepth;
// 						bvec3 mask = equal(hdTMax - currentDepth, vec3(hdDepth));
// 						hdTMax += vec3(mask) * hdStepSize;
// 						hdPos += ivec3(mask) * iStepDir;
// 					}
// 				}
// 			}
// 			if (depth >= max_distance) {
// 				break;
// 			}
// 			currentDepth = depth;
// 			// Step to next voxel
// 			bvec3 mask = equal(tMax, vec3(depth));
// 			tMax += vec3(mask) * stepSize;
// 			iPos += ivec3(mask) * iStepDir;
// 		} else {
// 			break;
// 		}
// 	}
// 	return voxelDepth;
// }

void main() {
	// if (AABB.data == 0) return;
	// float voxelDepth = VoxelDDA();
	// if (voxelDepth > 0) {
	// 	ray.emission += Heatmap(voxelDepth/7);
	// }
	RayIgnore();
}
