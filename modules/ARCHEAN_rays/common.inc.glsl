#include "game/graphics/common.inc.glsl"

// xenonRendererData.config.debugViewMode
#define RENDERER_DEBUG_VIEWMODE_NONE 0
#define RENDERER_DEBUG_VIEWMODE_RAYGEN_TIME 1
#define RENDERER_DEBUG_VIEWMODE_TRACE_RAY_COUNT 2
#define RENDERER_DEBUG_VIEWMODE_DIRECT_LIGHTS 3
#define RENDERER_DEBUG_VIEWMODE_ENVIRONMENT_AUDIO 4
#define RENDERER_DEBUG_VIEWMODE_ALPHA 5
#define RENDERER_DEBUG_VIEWMODE_SSAO 6
#define RENDERER_DEBUG_VIEWMODE_TEST 7
// the following debug modes only trace the first ray
#define RENDERER_DEBUG_VIEWMODE_DISTANCE 8
#define RENDERER_DEBUG_VIEWMODE_NORMALS_VIEWSPACE 9
#define RENDERER_DEBUG_VIEWMODE_NORMALS_WORLDSPACE 10
#define RENDERER_DEBUG_VIEWMODE_NORMALS_WORLDSPACE_INVERTED 11

#ifdef __cplusplus
	#define RENDERER_DEBUG_VIEWMODES_STR \
		"NONE",\
		"Ray Gen Time",\
		"Ray Trace Count",\
		"Direct Lights",\
		"Environment Audio",\
		"Alpha",\
		"SSAO",\
		"Test",\
		"Distance",\
		"Normals (Viewspace)",\
		"Normals (Worldspace)",\
		"Normals (Worldspace Inverted)",\
	
#endif

// // Up to 32 options
// #define RENDERER_OPTION_DIRECT_LIGHTING		(1u<< 0 )
// #define RENDERER_OPTION_INDIRECT_LIGHTING	(1u<< 1 )
// #define RENDERER_OPTION_GLASS_REFLECTIONS	(1u<< 2 )
// #define RENDERER_OPTION_GLASS_REFRACTION	(1u<< 3 )
// #define RENDERER_OPTION_WATER_REFLECTIONS	(1u<< 4 )
// #define RENDERER_OPTION_WATER_TRANSPARENCY	(1u<< 5 )
// #define RENDERER_OPTION_WATER_REFRACTION	(1u<< 6 )
// #define RENDERER_OPTION_WATER_WAVES			(1u<< 7 )
// #define RENDERER_OPTION_ATMOSPHERIC_SHADOWS	(1u<< 8 )
// #define RENDERER_OPTION_SPECULAR_SURFACES	(1u<< 9 )
// #define RENDERER_OPTION_RT_AMBIENT_LIGHTING	(1u<< 10 )
