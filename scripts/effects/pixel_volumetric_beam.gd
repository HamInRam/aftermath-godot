class_name PixelVolumetricBeam
extends Node2D

const WALL_MASK := 4
const RAY_COUNT := 17

var beam_color := Color("a85078", 0.15)
var beam_length := 104.0
var half_angle := 0.24
var base_rotation := PI * 0.5
var sweep_amount := 0.08
var sweep_speed := 0.42
var phase := 0.0
var elapsed := 0.0
var rebuild_remaining := 0.0
var frame_seed := 0
var ray_lengths := PackedFloat32Array()
var beam_image: Image
var beam_texture: ImageTexture
var beam_sprite: Sprite2D
var image_half_height := 1

func configure(tint: Color, length_px: float, spread_radians: float, direction: float, identity_seed: int) -> void:
	beam_color = Color(tint.r, tint.g, tint.b, 0.15)
	beam_length = length_px
	half_angle = spread_radians
	base_rotation = direction
	phase = float(posmod(identity_seed, 97)) / 97.0 * TAU
	rotation = base_rotation
	frame_seed = identity_seed
	if is_instance_valid(beam_sprite): _recreate_texture_surface()

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -3
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	ray_lengths.resize(RAY_COUNT)
	beam_sprite = Sprite2D.new()
	beam_sprite.centered = false
	beam_sprite.use_parent_material = true
	beam_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(beam_sprite)
	_recreate_texture_surface()
	call_deferred("_rebuild_occlusion")

func _process(delta: float) -> void:
	elapsed += delta
	rotation = snappedf(base_rotation + sin(elapsed * sweep_speed + phase) * sweep_amount, PI / 128.0)
	rebuild_remaining -= delta
	if rebuild_remaining <= 0.0:
		rebuild_remaining = 0.16
		frame_seed += 1
		_rebuild_occlusion()

func _rebuild_occlusion() -> void:
	if not is_inside_tree(): return
	var space := get_world_2d().direct_space_state
	for index in RAY_COUNT:
		var ratio := float(index) / float(RAY_COUNT - 1)
		var local_angle := lerpf(-half_angle, half_angle, ratio)
		var endpoint := global_position + Vector2.RIGHT.rotated(global_rotation + local_angle) * beam_length
		var hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(global_position, endpoint, WALL_MASK))
		ray_lengths[index] = global_position.distance_to(hit.position) - 2.0 if not hit.is_empty() else beam_length
	_rebuild_texture()

func _recreate_texture_surface() -> void:
	image_half_height = ceili(tan(half_angle) * beam_length) + 2
	var width := ceili(beam_length) + 2
	var height := image_half_height * 2 + 1
	beam_image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	beam_image.fill(Color.TRANSPARENT)
	beam_texture = ImageTexture.create_from_image(beam_image)
	beam_sprite.texture = beam_texture
	beam_sprite.position = Vector2(0.0, -float(image_half_height))

func _rebuild_texture() -> void:
	if ray_lengths.size() != RAY_COUNT: return
	if beam_image == null or beam_image.get_width() < ceili(beam_length): _recreate_texture_surface()
	beam_image.fill(Color.TRANSPARENT)
	for x in range(4, ceili(beam_length)):
		var local_half_width := tan(half_angle) * float(x)
		for y in range(-floori(local_half_width), ceili(local_half_width) + 1):
			var local_angle := atan2(float(y), float(x))
			var ray_ratio := clampf((local_angle + half_angle) / (half_angle * 2.0), 0.0, 1.0) * float(RAY_COUNT - 1)
			var low := floori(ray_ratio)
			var high := mini(RAY_COUNT - 1, low + 1)
			var allowed_length := lerpf(ray_lengths[low], ray_lengths[high], ray_ratio - float(low))
			if float(x) > allowed_length: continue
			var hash := absi(x * 17 + y * 31 + frame_seed * 43)
			var edge_ratio := absf(float(y)) / maxf(1.0, local_half_width)
			var distance_ratio := float(x) / beam_length
			var density := 2 if distance_ratio < 0.45 else (3 if distance_ratio < 0.75 else 4)
			if hash % density != 0: continue
			var alpha := beam_color.a * (1.0 - distance_ratio * 0.46) * (1.0 - edge_ratio * 0.48)
			var tint := Color(beam_color.r, beam_color.g, beam_color.b, alpha)
			if hash % 23 == 0: tint = Color(1.0, 0.94, 0.82, alpha * 1.35)
			var image_y := y + image_half_height
			if image_y >= 0 and image_y < beam_image.get_height(): beam_image.set_pixel(x, image_y, tint)
	# Two one-pixel rails make the cone direction readable without a soft edge.
	var edge_length := minf(beam_length, ray_lengths[0])
	_raster_line(Vector2i(3, image_half_height - 1), Vector2i(roundi(edge_length), image_half_height - roundi(tan(half_angle) * edge_length)), Color(beam_color.r, beam_color.g, beam_color.b, 0.045))
	edge_length = minf(beam_length, ray_lengths[RAY_COUNT - 1])
	_raster_line(Vector2i(3, image_half_height + 1), Vector2i(roundi(edge_length), image_half_height + roundi(tan(half_angle) * edge_length)), Color(beam_color.r, beam_color.g, beam_color.b, 0.045))
	beam_texture.update(beam_image)

func _raster_line(start: Vector2i, finish: Vector2i, tint: Color) -> void:
	var delta := finish - start
	var steps := maxi(absi(delta.x), absi(delta.y))
	if steps <= 0: return
	for step in range(steps + 1):
		var point := Vector2(start).lerp(Vector2(finish), float(step) / float(steps)).round()
		var pixel := Vector2i(point)
		if pixel.x >= 0 and pixel.y >= 0 and pixel.x < beam_image.get_width() and pixel.y < beam_image.get_height():
			beam_image.set_pixelv(pixel, tint)
