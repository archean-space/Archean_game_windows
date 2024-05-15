#ifdef __cplusplus
	#pragma once
#endif

#if 0 // 8-bit indexing
	/* 
	TerrainStack (Renderable)
		a Stack consists of 256 chunks vertically
		a Chunk contains 8x4x8 = 256 voxels of 1m
		a Voxel contains 4x4x4 = 64 smaller voxels of 25cm
	*/
	#define VOXEL_INDEX_BITS_XZ 3
	#define VOXEL_INDEX_BITS_Y 2
#else // 16-bit indexing (with padding)
	/* 
	TerrainStack (Renderable)
		a Stack consists of 64 chunks vertically
		a Chunk contains 16x16x16 = 4096 voxels of 1m
		a Voxel contains 4x4x4 = 64 smaller voxels of 25cm
	*/
	#define VOXEL_INDEX_BITS_XZ 4
	#define VOXEL_INDEX_BITS_Y 4
#endif

#define VOXELS_CHUNK_TOTAL_HEIGHT 1024
#define VOXEL_GRID_OFFSET -0.5 // -0.5 to put the center of voxels on integer grid

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#if (VOXEL_INDEX_BITS_XZ+VOXEL_INDEX_BITS_XZ+VOXEL_INDEX_BITS_Y == 8) || (VOXEL_INDEX_BITS_XZ+VOXEL_INDEX_BITS_XZ+VOXEL_INDEX_BITS_Y == 16)
	#define VOXEL_INDEX_PADDING 0
#else
	#if (VOXEL_INDEX_BITS_XZ+VOXEL_INDEX_BITS_XZ+VOXEL_INDEX_BITS_Y) < 8
		#define VOXEL_INDEX_PADDING (8 - (VOXEL_INDEX_BITS_XZ+VOXEL_INDEX_BITS_XZ+VOXEL_INDEX_BITS_Y))
	#else
		#define VOXEL_INDEX_PADDING (16 - (VOXEL_INDEX_BITS_XZ+VOXEL_INDEX_BITS_XZ+VOXEL_INDEX_BITS_Y))
	#endif
#endif
#define VOXEL_INDEX_TOTAL_BITS (VOXEL_INDEX_BITS_XZ + VOXEL_INDEX_BITS_XZ + VOXEL_INDEX_BITS_Y + VOXEL_INDEX_PADDING)
#if VOXEL_INDEX_TOTAL_BITS == 8
	#define VOXEL_INDEX_TYPE uint8_t
#else
	#if VOXEL_INDEX_TOTAL_BITS == 16
		#define VOXEL_INDEX_TYPE uint16_t
	#endif
#endif
#define VOXEL_GRID_SIZE_HD 4
#define VOXELS_XZ (1 << VOXEL_INDEX_BITS_XZ)
#define VOXELS_Y (1 << VOXEL_INDEX_BITS_Y)
#define VOXELS_X VOXELS_XZ
#define VOXELS_Z VOXELS_XZ
#define VOXELS_CHUNK_Y_SUBDIVISIONS (VOXELS_CHUNK_TOTAL_HEIGHT / VOXELS_Y)
#define VOXELS_PER_SUBCHUNK (VOXELS_X*VOXELS_Y*VOXELS_Z)
#define VOXEL_CHUNK_TOTAL_HEIGHT (VOXELS_CHUNK_Y_SUBDIVISIONS*VOXELS_Y)
#if VOXELS_CHUNK_Y_SUBDIVISIONS <= 256
	#define SubChunkIndex uint8_t
#else
	#define SubChunkIndex uint16_t
#endif
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#define VOXEL_EMPTY 0
#ifdef _WIN32
	#define VOXEL_FULL 0xffffffffffffffffull
#else
	#define VOXEL_FULL 0xfffffffffffffffful
#endif

#ifdef __cplusplus // C++
	#include <stdint.h>
	#include <glm/glm.hpp>
	#include <xenon/graphics/interface.inc.glsl>
	static_assert(sizeof(VOXEL_INDEX_TYPE) == 2);
	union VoxelIndex {
		VOXEL_INDEX_TYPE index;
		struct {
			VOXEL_INDEX_TYPE x : VOXEL_INDEX_BITS_XZ;
			VOXEL_INDEX_TYPE z : VOXEL_INDEX_BITS_XZ;
			VOXEL_INDEX_TYPE y : VOXEL_INDEX_BITS_Y;
			#if VOXEL_INDEX_PADDING > 0
				VOXEL_INDEX_TYPE _ : VOXEL_INDEX_PADDING;
			#endif
		};
		VoxelIndex(VOXEL_INDEX_TYPE index_ = 0) noexcept : index(index_) {
			assert(index < VOXELS_PER_SUBCHUNK);
		}
		VoxelIndex(const glm::ivec3& p) noexcept : x(p.x), z(p.z), y(p.y)
			#if VOXEL_INDEX_PADDING > 0
				,_(0)
			#endif
		{
			assert(p.x >= 0);
			assert(p.z >= 0);
			assert(p.y >= 0);
			assert(p.x < VOXELS_X);
			assert(p.z < VOXELS_Z);
			assert(p.y < VOXELS_Y);
			assert(index < VOXELS_PER_SUBCHUNK);
			assert(p.x == x);
			assert(p.y == y);
			assert(p.z == z);
			#if VOXEL_INDEX_PADDING > 0
				assert(_ == 0);
			#endif
		}
		operator glm::ivec3() const noexcept {
			return {x,y,z};
		}
		glm::ivec3 Position() const noexcept {
			return {x,y,z};
		}
		operator VOXEL_INDEX_TYPE() const noexcept {
			assert(index < VOXELS_PER_SUBCHUNK);
			return index;
		}
		VoxelIndex operator + (const glm::ivec3& offset) const noexcept {
			return glm::ivec3{x,y,z} + offset;
		}
		bool Continue() {
			if (index == VOXELS_PER_SUBCHUNK-1) return false;
			++index;
			return true;
		}
	};
	STATIC_ASSERT_SIZE(VoxelIndex, sizeof(VOXEL_INDEX_TYPE));
#else // GLSL
	#define VoxelIndex(x,y,z) (VOXEL_INDEX_TYPE(x) | (VOXEL_INDEX_TYPE(z) << VOXEL_INDEX_BITS_XZ) | (VOXEL_INDEX_TYPE(y) << (VOXEL_INDEX_BITS_XZ+VOXEL_INDEX_BITS_XZ)))
	#define VoxelIndexHD(x,y,z) (uint8_t(x) | (uint8_t(z) << 2) | (uint8_t(y) << 4))
	#define VoxelFillBitHD(iPos) (1ul << VoxelIndexHD(iPos.x, iPos.y, iPos.z))
	#define VoxelIndex_iPos(index) ivec3(\
		int32_t(uint32_t(index) & ((1u << VOXEL_INDEX_BITS_XZ) - 1)),\
		int32_t((uint32_t(index) & (((1u << VOXEL_INDEX_BITS_Y) - 1) << (VOXEL_INDEX_BITS_XZ+VOXEL_INDEX_BITS_XZ))) >> (VOXEL_INDEX_BITS_XZ + VOXEL_INDEX_BITS_XZ)),\
		int32_t((uint32_t(index) & (((1u << VOXEL_INDEX_BITS_XZ) - 1) << VOXEL_INDEX_BITS_XZ)) >> VOXEL_INDEX_BITS_XZ)\
	)
#endif

struct Voxel {
	uint64_t fill;
	uint16_t type;
	uint8_t data;
	#ifdef __cplusplus
		Voxel(uint64_t fill_ = 0, uint16_t type_ = 0, uint8_t data_ = 0)
		: fill(fill_), type(type_), data(data_) {}
	#endif
};
BUFFER_REFERENCE_STRUCT_READONLY(16) ChunkVoxelData {
	aligned_uint64_t fill[VOXELS_PER_SUBCHUNK]; // bitfield for 4x4x4 hd voxels
	aligned_uint16_t type[VOXELS_PER_SUBCHUNK]; // points to a callable shader
	aligned_uint8_t data[VOXELS_PER_SUBCHUNK]; // arbitrary data for use by callable shader
	aligned_i32vec3 aabbOffset;
	aligned_uint32_t voxelSize;
	aligned_uint16_t bounds[6];
	aligned_uint32_t voxelCount;
};
STATIC_ASSERT_ALIGNED16_SIZE(ChunkVoxelData, (8+2+1)*VOXELS_PER_SUBCHUNK + 16 + 16);

#ifndef __cplusplus // GLSL
	// Voxel Surface Shaders
	struct VoxelSurface {
		vec4 color;
		vec3 normal;
		float diffuse;
		vec3 emission;
		float specular;
		vec3 posInVoxel;
		float metallic;
		vec2 uv;
		float ior;
		uint16_t voxelIndex;
		uint8_t voxelData;
		uint8_t voxelFace;
		uint64_t voxelFill;
		uint64_t chunkAddr;
		GeometryMaterial geometryInfo;
		uint64_t renderableData;
		float distance;
	};
#endif

#ifdef SHADER_RCHIT
	layout(location = VOXEL_SURFACE_CALLABLE_PAYLOAD) callableDataEXT VoxelSurface voxelSurface;
#endif
#ifdef SHADER_VOXEL_SURFACE
	layout(location = VOXEL_SURFACE_CALLABLE_PAYLOAD) callableDataInEXT VoxelSurface voxelSurface;
	layout (constant_id = 0) const uint32_t textureID = 0;
	vec4 SampleTexture(uint index) {
		return textureLod(textures[NON_UNIFORM_TEX_INDEX(textureID + index)], voxelSurface.uv, 0);
	}
#endif

#if defined(SHADER_RCHIT) || defined(SHADER_RAHIT) || defined(SHADER_RINT)
	bool IsValidVoxel(in ivec3 iPos, in vec3 gridOffset) {
		if (iPos.x < 0 || iPos.y < 0 || iPos.z < 0) return false;
		if (iPos.x >= VOXELS_X || iPos.y >= VOXELS_Y || iPos.z >= VOXELS_Z) return false;
		if (iPos.x < AABB_MIN.x - gridOffset.x) return false;
		if (iPos.y < AABB_MIN.y - gridOffset.y) return false;
		if (iPos.z < AABB_MIN.z - gridOffset.z) return false;
		if (iPos.x >= AABB_MAX.x - gridOffset.x) return false;
		if (iPos.y >= AABB_MAX.y - gridOffset.y) return false;
		if (iPos.z >= AABB_MAX.z - gridOffset.z) return false;
		return true;
	}
	bool IsValidVoxelHD(in ivec3 iPos) {
		if (iPos.x < 0 || iPos.y < 0 || iPos.z < 0) return false;
		if (iPos.x >= VOXEL_GRID_SIZE_HD || iPos.y >= VOXEL_GRID_SIZE_HD || iPos.z >= VOXEL_GRID_SIZE_HD) return false;
		return true;
	}
	const vec3[7] BOX_NORMAL_DIRS = {
		vec3(-1,0,0),
		vec3(0,-1,0),
		vec3(0,0,-1),
		vec3(+1,0,0),
		vec3(0,+1,0),
		vec3(0,0,+1),
		vec3(0)
	};
#endif
