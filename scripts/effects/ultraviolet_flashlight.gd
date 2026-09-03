class_name UltravioletFlashlight
extends Node2D

## A real world-space UV flashlight. The fan is built from short physics rays so
## its visible edge and the evidence mask share the same wall-clipped polygon.

const RANGE := 66.0
const HALF_ANGLE := 0.44
const RAY_COUNT := 25
const ORIGIN_OFFSET := 7.0

var world_polygon := PackedVector2Array()
var _was_active := false

func _ready() -> void:
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	show_behind_parent = true
	z_index = -3
	set_physics_process(true)

func _physics_process(_delta: float) -> void:
	var actor := get_parent()
	var active := is_instance_valid(actor) and bool(actor.get("cleanup_mode")) and bool(actor.get("ultraviolet_lamp_active"))
	if not active:
		if _was_active:
			world_polygon = PackedVector2Array()
			queue_redraw()
		_was_active = false
		visible = false
		return
	visible = true
	_was_active = true
	rebuild_geometry()

func rebuild_geometry() -> void:
	if not is_inside_tree(): return
	var origin := global_position + Vector2.RIGHT.rotated(global_rotation) * ORIGIN_OFFSET
	var polygon := PackedVector2Array([origin.round()])
	var space := get_world_2d().direct_space_state
	for index in range(RAY_COUNT):
		var weight := float(index) / float(RAY_COUNT - 1)
		var angle := lerpf(-HALF_ANGLE, HALF_ANGLE, weight)
		var direction := Vector2.RIGHT.rotated(global_rotation + angle)
		var endpoint := origin + direction * RANGE
		var query := PhysicsRayQueryParameters2D.create(origin, endpoint, 4)
		query.collide_with_areas = false
		var hit := space.intersect_ray(query)
		if not hit.is_empty(): endpoint = (hit.position as Vector2) - direction * 0.75
		polygon.append(endpoint.round())
	if polygon == world_polygon: return
	world_polygon = polygon
	queue_redraw()

func get_world_polygon() -> PackedVector2Array:
	if world_polygon.is_empty() and visible: rebuild_geometry()
	return world_polygon

func _draw() -> void:
	if world_polygon.size() < 3: return
	var local_polygon := PackedVector2Array()
	for point in world_polygon: local_polygon.append(to_local(point))
	# Two restrained additive layers make the beam readable without turning the
	# floor into a solid purple UI overlay.
	draw_colored_polygon(local_polygon, Color(0.32, 0.08, 0.56, 0.075))
	var inner := PackedVector2Array([local_polygon[0]])
	var center := floori(float(local_polygon.size() - 1) / 2.0)
	var span := 7
	for index in range(center - span, center + span + 1): inner.append(local_polygon[index])
	draw_colored_polygon(inner, Color(0.38, 0.12, 0.70, 0.045))
	draw_polyline(local_polygon.slice(1), Color(0.74, 0.43, 1.0, 0.24), 1.0, false)
