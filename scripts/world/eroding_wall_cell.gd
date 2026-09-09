class_name ErodingWallCell
extends StaticBody2D

var erosion := PixelErosionMask.new()
var world: Node2D
var cell := Vector2i.ZERO
var image: Image
var texture: ImageTexture
var shapes: Array[CollisionShape2D] = []
var pending := false
var light_shapes: Array[LightOccluder2D] = []

func setup(owner_world: Node2D, coordinate: Vector2i, pixels: Image) -> void:
	world = owner_world
	cell = coordinate
	image = pixels
	texture = ImageTexture.create_from_image(image)
	erosion.configure(Rect2i(0,0,8,8))
	collision_layer = 4 | 32
	collision_mask = 0
	z_index = 1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rebuild()

func receive_projectile_impact_context(velocity: Vector2, point: Vector2, _weapon: String, damage: int) -> void:
	# A normal hit removes a readable bite, not a pin-sized chip. Keep a hard
	# native-pixel cap so high HP damage never becomes room-sized destruction.
	var radius := clampf(1.8 + sqrt(float(maxi(1, damage))) * 0.24, 2.2, 4.2)
	var count := erosion.chip(to_local(point), velocity.rotated(-global_rotation), radius)
	if count == 0: return
	MicroDebrisField.for_scene(self).play_erosion_tick(point)
	MicroDebrisField.for_scene(self).emit_impact(point, velocity.normalized(), "concrete", clampf(float(count) / 10.0, 0.8, 1.8))
	if not pending:
		pending = true
		call_deferred("_rebuild")

func _rebuild() -> void:
	pending = false
	erosion.rebuild_collision(self, shapes)
	for pixel: Vector2i in erosion.removed: image.set_pixelv(pixel, Color.TRANSPARENT)
	texture.update(image)
	for light in light_shapes: light.queue_free()
	light_shapes.clear()
	for rect in erosion.rectangles():
		var light := LightOccluder2D.new()
		light.occluder = OccluderPolygon2D.new()
		var p := Vector2(rect.position)
		var s := Vector2(rect.size)
		light.occluder.polygon = PackedVector2Array([p,p+Vector2(s.x,0),p+s,p+Vector2(0,s.y)])
		add_child(light)
		light_shapes.append(light)
	queue_redraw()
	if erosion.remaining() == 0: world.finish_eroded_cell(cell)

func _draw() -> void:
	if texture != null: draw_texture(texture, Vector2.ZERO)
