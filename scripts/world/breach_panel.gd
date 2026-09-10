class_name BreachPanel
extends StaticBody2D

var world: Node2D
var cells: Array[Vector2i] = []
var erosion := PixelErosionMask.new()
var shapes: Array[CollisionShape2D] = []
var light: LightOccluder2D
var opened := false
var pending := false
var last_direction := Vector2.RIGHT
var approach_a := Vector2.ZERO
var approach_b := Vector2.ZERO

func setup(owner_world: Node2D, occupied: Array[Vector2i], size: Vector2i) -> void:
	world = owner_world
	add_to_group("breach_panel")
	cells = occupied
	erosion.configure(Rect2i(Vector2i.ZERO,size))
	collision_layer = 4 | 32
	z_index = 3
	light = LightOccluder2D.new()
	light.occluder = OccluderPolygon2D.new()
	light.occluder.polygon = PackedVector2Array([Vector2.ZERO,Vector2(size.x,0),Vector2(size),Vector2(0,size.y)])
	add_child(light)
	erosion.rebuild_collision(self,shapes)

func receive_projectile_impact_context(velocity: Vector2, point: Vector2, _weapon: String, damage: int) -> void:
	if opened: return
	last_direction = velocity.normalized()
	var removed := erosion.chip(to_local(point),last_direction.rotated(-global_rotation),clampf(2.5 + sqrt(float(maxi(1,damage))) * .3,3.0,6.0))
	if removed == 0: return
	MicroDebrisField.for_scene(self).emit_impact(point,last_direction,"wood",1.0)
	if not pending:
		pending = true
		call_deferred("_rebuild")

func receive_thrown_impact(direction: Vector2, energy := 1.0) -> void:
	# Throws clear a larger central bite but use the same pixel/collision path.
	receive_projectile_impact_context(direction,to_global(Vector2(erosion.bounds.size) * .5),"thrown",roundi(energy * 90))

func _rebuild() -> void:
	pending = false
	if opened: return
	erosion.rebuild_collision(self,shapes)
	queue_redraw()
	if erosion.remaining() != 0: return
	opened = true
	light.visible = false
	MicroDebrisField.for_scene(self).emit_impact(to_global(Vector2(erosion.bounds.size)*.5),last_direction,"wood",2.0)
	world.open_breach(self)

func _draw() -> void:
	for y in range(erosion.bounds.size.y):
		for x in range(erosion.bounds.size.x):
			if not erosion.solid(Vector2i(x,y)): continue
			var color := Color("777777") if x % 4 else Color("363636")
			if y == 1 or y == erosion.bounds.size.y-2: color = Color("bbbbbb")
			draw_rect(Rect2(x,y,1,1),color)
