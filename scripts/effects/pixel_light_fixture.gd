class_name PixelLightFixture
extends Node2D

var tint := Color("a85078")
var identity_seed := 0
var elapsed := 0.0
var current_frame := -1
var frame_textures: Array[ImageTexture] = []
var fixture_sprite: Sprite2D

func configure(source_color: Color, seed: int) -> void:
	tint = source_color
	identity_seed = seed
	if is_instance_valid(fixture_sprite): _rebuild_frames()

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 8
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	fixture_sprite = Sprite2D.new()
	fixture_sprite.centered = false
	fixture_sprite.position = Vector2(-9, -9)
	fixture_sprite.use_parent_material = true
	fixture_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(fixture_sprite)
	_rebuild_frames()

func _process(delta: float) -> void:
	elapsed += delta
	var next_frame := floori(elapsed / 0.24) % 4
	if next_frame != current_frame and next_frame < frame_textures.size():
		current_frame = next_frame
		fixture_sprite.texture = frame_textures[current_frame]

func _rebuild_frames() -> void:
	frame_textures.clear()
	for frame in range(4): frame_textures.append(_build_frame(frame))
	current_frame = floori(elapsed / 0.24) % 4
	fixture_sprite.texture = frame_textures[current_frame]

func _build_frame(frame: int) -> ImageTexture:
	var image := Image.create(19, 19, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	# A readable five-pixel practical lamp: dark socket, coloured emitter and a
	# single white core. No vector circle or filtered sprite is involved.
	for point in [Vector2(-1,-1), Vector2(0,-1), Vector2(1,-1), Vector2(-1,0), Vector2(1,0), Vector2(-1,1), Vector2(0,1), Vector2(1,1)]:
		_set_image_pixel(image, Vector2i(point), Color(tint.r, tint.g, tint.b, 0.82))
	_set_image_pixel(image, Vector2i.ZERO, Color(1.0, 0.96, 0.87, 1.0))
	# Sparse single-pixel halo points expose the light radius without drawing a
	# smooth disc. Their slow phase change reads as dust crossing the fixture.
	var phase_seed := identity_seed + frame
	for y in range(-9, 10):
		for x in range(-9, 10):
			var distance_squared := x * x + y * y
			if distance_squared < 13 or distance_squared > 81: continue
			var hash := absi(x * 17 + y * 31 + phase_seed * 43)
			if hash % 17 != 0: continue
			var alpha := 0.16 if distance_squared < 42 else 0.08
			_set_image_pixel(image, Vector2i(x, y), Color(tint.r, tint.g, tint.b, alpha))
	return ImageTexture.create_from_image(image)

func _set_image_pixel(image: Image, point: Vector2i, color: Color) -> void:
	var pixel := point + Vector2i(9, 9)
	if pixel.x >= 0 and pixel.y >= 0 and pixel.x < 19 and pixel.y < 19: image.set_pixelv(pixel, color)
