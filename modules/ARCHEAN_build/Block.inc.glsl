// ALSO INCLUDED IN GLSL

#include "xenon/graphics/interface.inc.glsl"
#ifdef __cplusplus
	#pragma once
	using namespace glm;
	#include <cstring>
#endif

// #define BLOCK_TYPE_BEVEL_ENABLED

BUFFER_REFERENCE_STRUCT_READONLY(4) BlockColor {
	aligned_uint8_t r;
	aligned_uint8_t g;
	aligned_uint8_t b;
	#ifdef __cplusplus
		uint8_t opacity : 4;
		uint8_t roughness : 3;
		uint8_t metallic : 1;
		bool IsTransparent() const { return opacity < 15; }
	#else
		aligned_uint8_t a;
		// opacity = (float(a & 0xf) + 1) / 16.0
		// roughness = float((a >> 4) & 0x7) / 7.0
		// metallic = float(a >> 7)
	#endif
};
STATIC_ASSERT_SIZE(BlockColor, 4)

// 16 bytes (128 bits)
BUFFER_REFERENCE_STRUCT_READONLY(16) Block {
	
	// 8 bytes (64 bits)
	aligned_uint8_t type; // 256 types & orientations
	aligned_uint8_t color[7]; // 256 materials (color + roughness + metallic)
	
	#ifdef __cplusplus
		// 4 bytes (32 bits)
		/*UNUSED*/uint32_t _damage : 8; // 256 states
		/*UNUSED*/uint32_t material : 8; // 256 alloys
		uint32_t extra : 4; // 16 states
		uint32_t size_x : 4; // from 0.25 to 4.0 meter
		uint32_t size_y : 4;
		uint32_t size_z : 4;
	
		// 2 bytes (16 bits)
		union {
			uint16_t id;
			struct {
				uint16_t x : 5; // supports up to 8x8x8 meters frame size on a 25 cm grid
				uint16_t y : 5;
				uint16_t z : 5;
				uint16_t _ : 1;
			} position;
		};
		
		Block(uint16_t id_ = 0) : type(0), color{0,0,0,0,0,0,0}, _damage(0), material(0), extra(0), size_x(0), size_y(0), size_z(0), id(id_) {}
		
		vec3 GetPosition() const {
			return vec3(position.x, position.y, position.z) * 0.25f;
		}
		
		vec3 GetCenterOfMass() const {
			return GetSize() * 0.5f;
		}
		
		vec3 GetSize() const {
			return vec3(size_x, size_y, size_z) * 0.25f + 0.25f;
		}
		
		double GetMass() const {
			if (type == 255/*ENTITY_OCCUPANCY_INDEX*/) return 0;
			double size = double((size_x+1) * (size_y+1) * (size_z+1)) * (type==0? 1.0:0.5);
			switch (material) {
			case 0: // Composite
				return size * 0.250;
			case 1: // Concrete
				return size * 10.0;
			case 2: // Steel
				return size * 1.0;
			case 3: // Aluminum
				return size * 0.500;
			case 4: // Glass
				return size * 1.0;
			case 5: // Lead
				return size * 150.0;
			default:
				return size;
			}
		}
		
		// for better handling of drag, lift and bouyancy
		double GetVolumeDisplacementRatio() const {
			if (type == 255/*ENTITY_OCCUPANCY_INDEX*/) return 0;
			switch (material) {
			case 0: // Composite
				return 0.2 * (type==0? 1.0:0.5);
			case 1: // Concrete
				return 0.25 * (type==0? 1.0:0.5);
			case 2: // Steel
				return 0.01 * (type==0? 1.0:0.5);
			case 3: // Aluminum
				return 0.01 * (type==0? 1.0:0.5);
			case 4: // Glass
				return 0.02 * (type==0? 1.0:0.5);
			case 5: // Lead
				return 1.0 * (type==0? 1.0:0.5);
			default:
				return 1.00 * (type==0? 1.0:0.5);
			}
		}
		
		double GetFrictionCoefficient() const {
			switch (material) {
			case 0: // Composite
				return 0.05;
			case 1: // Concrete
				return 0.5;
			case 2: // Steel
				return 0.2;
			case 3: // Aluminum
				return 0.2;
			case 4: // Glass
				return 0.1;
			case 5: // Lead
				return 0.2;
			default:
				return 0.2;
			}
		}
		
		void SetOccupancy(const glm::ivec3& a, const glm::ivec3& b) {
			position.x = uint16_t(glm::clamp(glm::min(a.x, b.x), 0, 11));
			position.y = uint16_t(glm::clamp(glm::min(a.y, b.y), 0, 11));
			position.z = uint16_t(glm::clamp(glm::min(a.z, b.z), 0, 11));
			size_x = uint16_t(glm::clamp(glm::max(a.x, b.x) - position.x, 0, 15/*11 - position.x*/));
			size_y = uint16_t(glm::clamp(glm::max(a.y, b.y) - position.y, 0, 15/*11 - position.y*/));
			size_z = uint16_t(glm::clamp(glm::max(a.z, b.z) - position.z, 0, 15/*11 - position.z*/));
		}
		
		void SetSpan(const glm::ivec3& pos, const glm::ivec3& size) {
			SetPositionSpan(pos);
			SetSizeSpan(size);
		}
		
		void SetPositionSpan(const glm::ivec3& pos) {
			position.x = uint16_t(glm::clamp(pos.x, 0, 11));
			position.y = uint16_t(glm::clamp(pos.y, 0, 11));
			position.z = uint16_t(glm::clamp(pos.z, 0, 11));
		}
		
		void SetSizeSpan(const glm::ivec3& size) {
			size_x = uint16_t(glm::clamp(size.x, 0, 15));
			size_y = uint16_t(glm::clamp(size.y, 0, 15));
			size_z = uint16_t(glm::clamp(size.z, 0, 15));
		}
		
		glm::ivec3 GetPositionSpan() const {
			return glm::ivec3(position.x, position.y, position.z);
		}
		
		glm::ivec3 GetSizeSpan() const {
			return glm::ivec3(size_x, size_y, size_z);
		}
		
		static void MakeOccupancySpan(const glm::ivec3& a, const glm::ivec3& b, glm::ivec3& positionSpan, glm::ivec3& sizeSpan) {
			positionSpan.x = glm::min(a.x, b.x);
			positionSpan.y = glm::min(a.y, b.y);
			positionSpan.z = glm::min(a.z, b.z);
			sizeSpan.x = glm::max(a.x, b.x) - positionSpan.x;
			sizeSpan.y = glm::max(a.y, b.y) - positionSpan.y;
			sizeSpan.z = glm::max(a.z, b.z) - positionSpan.z;
		}
		
		static vec3 GetPositionFromSpan(const glm::ivec3& positionSpan) {
			return vec3(positionSpan.x, positionSpan.y, positionSpan.z) * 0.25f;
		}
		
		static vec3 GetSizeFromSpan(const glm::ivec3& sizeSpan) {
			return vec3(sizeSpan.x, sizeSpan.y, sizeSpan.z) * 0.25f + 0.25f;
		}
		
		bool IsDifferentShapeOrSize (const Block& other) const {
			return type != other.type || id != other.id || size_x != other.size_x || size_y != other.size_y || size_z != other.size_z;
		}
		
		bool IsSameShapeAndSize (const Block& other) const {
			return !IsDifferentShapeOrSize(other);
		}
		
		bool IsDifferent (const Block& other) const {
			return IsDifferentShapeOrSize(other) || _damage != other._damage || extra != other.extra || material != other.material || memcmp(color, other.color, sizeof(color)) != 0;
		}
		
		bool HasSameOccupancy (const Block& other) {
			const glm::ivec3 startA = glm::ivec3(position.x, position.y, position.z);
			const glm::ivec3 endA = glm::ivec3(position.x + size_x, position.y + size_y, position.z + size_z);
			const glm::ivec3 startB = glm::ivec3(other.position.x, other.position.y, other.position.z);
			const glm::ivec3 endB = glm::ivec3(other.position.x + other.size_x, other.position.y + other.size_y, other.position.z + other.size_z);
			if (startA.x != startB.x || startA.y != startB.y || startA.z != startB.z) return false;
			if (endA.x != endB.x || endA.y != endB.y || endA.z != endB.z) return false;
			return true;
		}
		
	#else
		uint32_t data;
		// damage = float(data&0x3F)/63.0
		// dirt = float((data>>6)&0x3)/3.0
		// extra = float((data>>8)&0xf)/15.0
		uint16_t id;
	#endif
	
	// 2 bytes (16 bits)
	aligned_uint16_t temperature; // 0.0 to 6'553.5 kelvin with a precision of 0.1 degrees
};
STATIC_ASSERT_ALIGNED16_SIZE(Block, 16)
