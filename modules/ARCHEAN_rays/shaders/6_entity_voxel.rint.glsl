// #define SHADER_RINT
// #include "common.inc.glsl"

// hitAttributeEXT hit {
// 	float t2;
// 	VOXEL_INDEX_TYPE voxelIndex;
// };

// void NextStepDDA(inout bvec3 bNormalMask, inout ivec3 iPos, inout vec3 travelDist, in ivec3 iStepDir, in vec3 stepSize) {
// 	bNormalMask = lessThanEqual(travelDist.xyz, min(travelDist.yzx, travelDist.zxy));
// 	iPos += ivec3(bNormalMask) * iStepDir;
// 	travelDist += vec3(bNormalMask) * stepSize;
// }
// void ReportIntersection(in vec3 pos, in vec3 rayOrigin, in vec3 rayDir, in bvec3 bNormalMask, in ivec3 iStepDir, in float voxelSize) {
// 	// Compute actual T
	
// 	if (voxelSize == 1) {
// 		const vec3 tbot = (pos + voxelSize - rayOrigin) / rayDir;
// 		const vec3 ttop = (pos - rayOrigin) / rayDir;
// 		const vec3 tmin = min(ttop, tbot);
// 		const vec3 tmax = max(ttop, tbot);
// 		const float t1 = max(tmin.x, max(tmin.y, tmin.z));
// 		t2 = min(tmax.x, min(tmax.y, tmax.z));
// 		// Store Normal Index in gl_HitKindEXT
// 		uint8_t normalIndex = uint8_t(
// 			int(bNormalMask.x) * (3 - 3 * max(0, iStepDir.x))
// 			+ int(bNormalMask.y) * (4 - 3 * max(0, iStepDir.y))
// 			+ int(bNormalMask.z) * (5 - 3 * max(0, iStepDir.z))
// 		);
// 		reportIntersectionEXT(t1, normalIndex);
// 	} else {
// 		const vec3 tbot = (pos + voxelSize - rayOrigin) / rayDir;
// 		const vec3 ttop = (pos - rayOrigin) / rayDir;
// 		const vec3 tmin = min(ttop, tbot);
// 		const vec3 tmax = max(ttop, tbot);
// 		const float t1 = max(tmin.x, max(tmin.y, tmin.z));
// 		t2 = min(tmax.x, min(tmax.y, tmax.z));
// 		uint8_t normalIndex = uint8_t(
// 			int(bNormalMask.x) * (3 - 3 * max(0, iStepDir.x))
// 			+ int(bNormalMask.y) * (4 - 3 * max(0, iStepDir.y))
// 			+ int(bNormalMask.z) * (5 - 3 * max(0, iStepDir.z))
// 		);
// 		if (t1 > gl_RayTminEXT) {
// 			// Exterior
// 			reportIntersectionEXT(t1, normalIndex);
// 		} else {
// 			// Interior
// 			reportIntersectionEXT(t2, normalIndex);
// 		}
// 	}
// }
// const int maxIterations_hd = VOXEL_GRID_SIZE_HD * 3 + 1;
// const float maxHdVoxelDistance = 100;
// void main() {
// 	if (AABB.data == 0) {
// 		DEBUG_RAY_INT_TIME
// 		return;
// 	}
// 	COMPUTE_BOX_INTERSECTION // retrieves T1 and T2
// 	if (T1 < T2 && T2 > 0) {
// 		bool rayIsGi = RAY_IS_GI;
// 		bool rayIsShadow = RAY_IS_SHADOW;
// 		ChunkVoxelData voxelData = ChunkVoxelData(AABB.data);
// 		if (voxelData.voxelSize == 0) {
// 			DEBUG_RAY_INT_TIME
// 			return;
// 		}
// 		const float startT = max(gl_RayTminEXT, T1 - EPSILON * voxelData.voxelSize * 10);
// 		const float endT   = min(gl_RayTmaxEXT, T2 + EPSILON * voxelData.voxelSize * 10);
// 		const bool enableHdVoxels = voxelData.voxelSize == 1 && startT < maxHdVoxelDistance && !rayIsGi;
// 		const int maxIterations = int(ceil(endT - startT)) * 3 + 1;
// 		const vec3 gridOffset = vec3(VOXEL_GRID_OFFSET) + vec3(voxelData.aabbOffset) * voxelData.voxelSize;
// 		const vec3 rayDir = gl_ObjectRayDirectionEXT;
// 		const vec3 stepDir = sign(rayDir);
// 		const ivec3 iStepDir = ivec3(stepDir);
// 		const vec3 rayOrigin = gl_ObjectRayOriginEXT - gridOffset;
// 		const vec3 rayPos = (rayOrigin + rayDir * startT) / voxelData.voxelSize;
// 		const vec3 stepSize = abs(1.0 / rayDir);
// 		const ivec3 iOutOfBound = ivec3((rayOrigin + gl_ObjectRayDirectionEXT * endT) / voxelData.voxelSize) + iStepDir;
// 		ivec3 iPos = ivec3(floor(rayPos));
// 		bvec3 bNormalMask = bvec3(false);
// 		vec3 travelDist = (stepDir * (vec3(iPos) - rayPos) + (stepDir * 0.5) + 0.5) * stepSize;
// 		for (int i = 0; i < maxIterations; i++) {
// 			if (IsValidVoxel(iPos, gridOffset)) {
// 				voxelIndex = VoxelIndex(iPos.x, iPos.y, iPos.z);
// 				const uint64_t fill = voxelData.fill[voxelIndex];
// 				if (fill != VOXEL_EMPTY) {
// 					if (fill == VOXEL_FULL || !enableHdVoxels) {
// 						if (!rayIsShadow || voxelData.type[voxelIndex] != 0) {
// 							ReportIntersection(vec3(iPos) * voxelData.voxelSize, rayOrigin, rayDir, bNormalMask, iStepDir, voxelData.voxelSize);
// 						}
// 						DEBUG_RAY_INT_TIME
// 						return;
// 					} else {
						
// 						// Aim Wireframe
// 						if (renderer.aim.tlasInstanceIndex == gl_InstanceID && renderer.aim.geometryIndex == gl_GeometryIndexEXT && renderer.aim.primitiveIndex == gl_PrimitiveID) {
// 							const vec3 tmin = min((vec3(iPos) - rayOrigin) / rayDir, (vec3(iPos) + voxelData.voxelSize - rayOrigin) / rayDir);
// 							const float T = max(gl_RayTminEXT, max(tmin.x, max(tmin.y, tmin.z)));
// 							const vec3 hitPosRelativeToStack = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * T;
// 							if (ivec3(round(renderer.aim.localPosition - renderer.aim.worldSpaceHitNormal*0.01)) == ivec3(round(hitPosRelativeToStack + gl_ObjectRayDirectionEXT * 0.01))) {
// 								const vec3 hitPosRelativeToVoxel = hitPosRelativeToStack - vec3(iPos) - gridOffset;
// 								const vec3 distFromCenter = abs(hitPosRelativeToVoxel - 0.5);
// 								const float thickness = renderer.wireframeThickness * xenonRendererData.config.renderScale * max(1, T);
// 								const float theshold = 0.5 - thickness;
// 								if (step(theshold, distFromCenter.x) + step(theshold, distFromCenter.y) + step(theshold, distFromCenter.z) > 1) {
// 									ReportIntersection(vec3(iPos) * voxelData.voxelSize, rayOrigin, rayDir, bNormalMask, iStepDir, voxelData.voxelSize);
// 									DEBUG_RAY_INT_TIME
// 									return;
// 								}
// 							}
// 						}
						
// 						const vec3 tmin = min((vec3(iPos) - rayOrigin) / rayDir, (vec3(iPos+1) - rayOrigin) / rayDir);
// 						const float T = max(gl_RayTminEXT, max(tmin.x, max(tmin.y, tmin.z)));
// 						const vec3 rayPos_hd = (rayOrigin + rayDir * T - vec3(iPos)) * VOXEL_GRID_SIZE_HD - stepDir*EPSILON;
						
// 						ivec3 iPos_hd = ivec3(floor(rayPos_hd));
// 						bvec3 bNormalMask_hd = bNormalMask;
// 						vec3 travelDist_hd = (stepDir * (vec3(iPos_hd) - rayPos_hd) + (stepDir * 0.5) + 0.5) * stepSize;
					
// 						for (int j = 0; j < maxIterations_hd; j++) {
// 							if (IsValidVoxelHD(iPos_hd)) {
// 								if ((fill & VoxelFillBitHD(iPos_hd)) != 0) {
// 									ReportIntersection((vec3(iPos_hd)/VOXEL_GRID_SIZE_HD + vec3(iPos)), rayOrigin, rayDir, bNormalMask_hd, iStepDir, 1.0/VOXEL_GRID_SIZE_HD);
// 									DEBUG_RAY_INT_TIME
// 									return;
// 								}
// 							}
// 							// Fast DDA
// 							NextStepDDA(bNormalMask_hd, iPos_hd, travelDist_hd, iStepDir, stepSize);
// 							// Early Exit when out of bounds
// 							if (iPos_hd.x == VOXEL_GRID_SIZE_HD || iPos_hd.y == VOXEL_GRID_SIZE_HD || iPos_hd.z == VOXEL_GRID_SIZE_HD) break;
// 						}
// 					}
// 				}
// 			}
// 			// Fast DDA
// 			NextStepDDA(bNormalMask, iPos, travelDist, iStepDir, stepSize);
// 			// Early Exit when out of bounds
// 			if (iPos.x == iOutOfBound.x || iPos.y == iOutOfBound.y || iPos.z == iOutOfBound.z) {
// 				DEBUG_RAY_INT_TIME
// 				return;
// 			}
// 		}
// 	}
	
// 	DEBUG_RAY_INT_TIME
// }

void main() {}
