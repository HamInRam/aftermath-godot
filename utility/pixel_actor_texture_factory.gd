@static_unload
class_name PixelActorTextureFactory
extends RefCounted

const ACTOR_ART := preload("res://utility/pixel_actor_art.gd")
static var _cache: Dictionary = {}

static func clear_cache() -> void:
	_cache.clear()

static func get_frame(role: String) -> ImageTexture:
	var normalized := "hound" if role.to_lower() == "dog" else role.to_lower()
	if _cache.has(normalized): return _cache[normalized]
	var hands: Array[Vector2] = [Vector2(5.3, 2.8), Vector2(8.0, -1.5)]
	if normalized in ["melee", "bleeder"]: hands = [Vector2(6, 3), Vector2(2.5, -4)]
	# The editor/compatibility texture is the same native silhouette the live rig
	# paints. It is never a substitute for the articulated runtime body.
	var pixels := ACTOR_ART.hound_pixels(0.0) if normalized == "hound" else ACTOR_ART.human_pixels(normalized, 0.0, hands)
	var texture := ImageTexture.create_from_image(ACTOR_ART.to_image(pixels))
	_cache[normalized] = texture
	return texture
