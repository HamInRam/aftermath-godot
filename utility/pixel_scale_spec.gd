class_name PixelScaleSpec
extends RefCounted

# The world keeps an 8 px simulation tile while authored art follows the
# measured 16 px reference grid. Characters use 32 px animation canvases with
# narrow 24-29 px occupied silhouettes and weapon-safe transparent margins.
const WORLD_TILE_PX := 8
const REFERENCE_SCALE := 2
const REFERENCE_TILE_PX := WORLD_TILE_PX * REFERENCE_SCALE
const ACTOR_CANVAS_PX := 32
const ACTOR_CORE_MIN_PX := 24
const ACTOR_CORE_MAX_PX := 29
const ACTOR_RUNTIME_SCALE := 0.82
const ACTOR_RUNTIME_CORE_MIN_PX := ACTOR_CORE_MIN_PX * ACTOR_RUNTIME_SCALE
const ACTOR_RUNTIME_CORE_MAX_PX := ACTOR_CORE_MAX_PX * ACTOR_RUNTIME_SCALE
const DOOR_LEAF_PX := 16
const CORRIDOR_MIN_PX := 24
const CORRIDOR_MAX_PX := 32

static func validate() -> bool:
	return REFERENCE_TILE_PX == 16 \
		and DOOR_LEAF_PX == WORLD_TILE_PX * 2 \
		and CORRIDOR_MIN_PX == WORLD_TILE_PX * 3 \
		and CORRIDOR_MAX_PX == WORLD_TILE_PX * 4
