class_name PixelActorTextureFactory
extends RefCounted

## Compatibility frames for editor previews, tests and any tool that expects a
## Sprite2D texture. Live actors are drawn by LifecyclePhysicsRig2D, but these
## frames are still authored cell-by-cell on the same native 16x16 grid.
static var _cache: Dictionary = {}

static func get_frame(role: String) -> ImageTexture:
	var normalized := role.to_lower()
	if _cache.has(normalized): return _cache[normalized]
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var palette := _palette(normalized)
	var body: Color = palette.body
	var accent: Color = palette.accent
	var skin: Color = palette.skin
	var shadow: Color = palette.shadow
	if normalized == "hound":
		_paint_rect(image, Rect2i(5, 5, 7, 6), body)
		_paint_rect(image, Rect2i(9, 4, 4, 4), skin)
		_paint_rect(image, Rect2i(4, 6, 2, 3), shadow)
		_put_pixel(image, 12, 5, accent)
		_put_pixel(image, 12, 7, shadow)
		_put_pixel(image, 5, 11, accent)
		_put_pixel(image, 10, 11, accent)
	else:
		# Strict top-down read: head at the forward edge, shoulders below it,
		# two separated hands and only two restrained locomotion pixels.
		_paint_rect(image, Rect2i(6, 3, 4, 4), skin)
		_paint_rect(image, Rect2i(5, 7, 6, 5), body)
		_paint_rect(image, Rect2i(4, 8, 2, 3), accent)
		_paint_rect(image, Rect2i(10, 8, 2, 3), accent)
		_put_pixel(image, 7, 4, skin.lightened(0.16))
		_put_pixel(image, 8, 4, shadow)
		_put_pixel(image, 6, 12, shadow)
		_put_pixel(image, 9, 12, shadow)
		if normalized == "heavy":
			_put_pixel(image, 4, 7, body)
			_put_pixel(image, 11, 7, body)
		elif normalized == "assault":
			_put_pixel(image, 5, 6, accent)
			_put_pixel(image, 10, 6, accent)
		elif normalized == "melee":
			_put_pixel(image, 3, 9, accent)
			_put_pixel(image, 12, 9, accent)
		elif normalized == "gunner":
			_paint_rect(image, Rect2i(10, 7, 4, 2), shadow)
	var texture := ImageTexture.create_from_image(image)
	_cache[normalized] = texture
	return texture

static func _palette(role: String) -> Dictionary:
	match role:
		"player": return {"body": Color("d8e2df"), "accent": Color("27c9ca"), "skin": Color("dfa47e"), "shadow": Color("191625")}
		"assault": return {"body": Color("9a5719"), "accent": Color("ff9a45"), "skin": Color("d79a76"), "shadow": Color("261727")}
		"heavy": return {"body": Color("41306e"), "accent": Color("a59cff"), "skin": Color("c78868"), "shadow": Color("181426")}
		"melee": return {"body": Color("7d163f"), "accent": Color("ff4f91"), "skin": Color("dd9a72"), "shadow": Color("21121d")}
		"hound": return {"body": Color("6e4a37"), "accent": Color("e8d8c8"), "skin": Color("a77857"), "shadow": Color("211814")}
		_: return {"body": Color("7c235b"), "accent": Color("f23d78"), "skin": Color("d59a75"), "shadow": Color("211421")}

static func _paint_rect(image: Image, area: Rect2i, color: Color) -> void:
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x): _put_pixel(image, x, y, color)

static func _put_pixel(image: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and x < image.get_width() and y >= 0 and y < image.get_height(): image.set_pixel(x, y, color)
