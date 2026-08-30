class_name SwingDoor
extends RigidBody2D

const SPLINTER_SCENE := preload("res://scenes/effects/door_splinters.tscn")
const PIXELS := preload("res://utility/pixel_art_painter.gd")

enum DoorState { CLOSED, SLAM_OPENING, OPEN }

@export_range(0.5, 1.57, 0.01) var max_open_angle := 1.5
@export_range(8.0, 30.0, 0.5) var slam_speed := 25.0
@export_range(2.0, 12.0, 0.5) var gentle_speed := 8.0
@export_range(20.0, 140.0, 1.0) var dangerous_speed_threshold := 81.0
@export_range(0.5, 3.0, 0.1) var knockdown_speed := 1.0
@export_range(0.05, 0.3, 0.01) var dangerous_window := 0.14

var current_state := DoorState.CLOSED
var target_rotation := 0.0
var simulated_rotation := 0.0
var hit_bodies := {}
var current_open_speed := 8.0
var door_pusher: Node2D
var is_dangerous := false
var dangerous_time_remaining := 0.0

func _ready() -> void:
	add_to_group("tactical_door")
	freeze = true
	simulated_rotation = rotation
	$PanelCollision.disabled = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()

func _draw() -> void:
	# The leaf and its shadow are built from individual snapped cells. The old
	# Polygon2D presentation remains hidden in the scene only for compatibility.
	PIXELS.stipple_rect(self, Rect2(0, 2, 4, 16), Color(0.035, 0.02, 0.05, 0.48), 29, 3)
	PIXELS.material_panel(self, Rect2(-2, 0, 4, 16), Color("17131b"), Color("843f2b"), Color("c07340"), Color("4b251f"), 29, &"wood")
	for y in range(2, 14, 4): PIXELS.pixel(self, Vector2(0, y), Color("c07340"))
	PIXELS.pixel(self, Vector2(0, 13), Color("f2bf4c"))

func get_tactical_door_id() -> String:
	return "door:%d:%d" % [roundi(global_position.x / 8.0), roundi(global_position.y / 8.0)]

func get_safe_approach(actor_position: Vector2, lateral_sign := 0.0) -> Vector2:
	# Keep responders on their current side of the closed/opening threshold and
	# offset lateral roles away from the same center pixel.
	var passage_normal := Vector2.RIGHT.rotated(global_rotation)
	var side := signf((actor_position - global_position).dot(passage_normal))
	if is_zero_approx(side): side = 1.0
	var tangent := passage_normal.orthogonal()
	return global_position + passage_normal * side * 18.0 + tangent * lateral_sign * 11.0

func _physics_process(delta: float) -> void:
	if current_state != DoorState.SLAM_OPENING: return
	dangerous_time_remaining = maxf(0.0, dangerous_time_remaining - delta)
	if dangerous_time_remaining <= 0.0: is_dangerous = false
	var previous_rotation := rotation
	var remaining_ratio := clampf(absf(angle_difference(rotation, target_rotation)) / max_open_angle, 0.0, 1.0)
	var eased_speed := current_open_speed * lerpf(0.24, 1.0, smoothstep(0.0, 0.42, remaining_ratio))
	# Accumulate the physical angle continuously, then expose only authored
	# 5.625-degree frames. Snapping the accumulator itself made gentle doors
	# stall forever whenever one frame's delta was smaller than half a step.
	simulated_rotation = move_toward(simulated_rotation, target_rotation, eased_speed * delta)
	rotation = snappedf(simulated_rotation, PI / 32.0)
	var actual_speed := absf(angle_difference(previous_rotation, rotation)) / maxf(delta, 0.0001)
	if is_dangerous and actual_speed >= knockdown_speed:
		for body in $HitArea.get_overlapping_bodies():
			if body == door_pusher or hit_bodies.has(body.get_instance_id()): continue
			hit_bodies[body.get_instance_id()] = true
			if body.is_in_group("destructible_prop") and body.has_method("take_damage"):
				if body.has_method("receive_door_impact"):
					var door_direction: Vector2 = (body.global_position - global_position).normalized()
					body.receive_door_impact(door_direction, clampf(actual_speed / 8.0, 0.6, 1.8))
				else:
					body.take_damage(1, global_position)
				Events.door_impact.emit(global_position, 1.2)
				current_open_speed *= 0.72
			elif body.is_in_group("enemy") and body.has_method("take_door_hit"):
				var radial: Vector2 = (body.global_position - global_position).normalized()
				var swing_sign := signf(angle_difference(previous_rotation, rotation))
				var hit_direction: Vector2 = radial.orthogonal() * swing_sign
				body.take_door_hit(hit_direction, "knockdown")
				Events.door_impact.emit(global_position, 1.35)
				current_open_speed *= 0.48
				is_dangerous = false
	if absf(simulated_rotation - target_rotation) <= 0.01:
		rotation = target_rotation
		current_state = DoorState.OPEN
		# Doors are one-way state machines and never close again. Re-enabling the
		# full 16px panel here made the visually open leaf an invisible route
		# blocker in narrow authored rooms. The frame remains solid; the settled
		# leaf becomes presentation-only so both actors can reliably traverse it.
		$PanelCollision.set_deferred("disabled", true)
		door_pusher = null
		is_dangerous = false

func push_door_open(pusher_node: Node2D, pusher_velocity: Vector2) -> void:
	_begin_open(pusher_node, pusher_node.global_position, pusher_velocity)

func _begin_open(pusher_node: Node2D, pusher_position: Vector2, pusher_velocity: Vector2) -> void:
	if current_state != DoorState.CLOSED: return
	current_state = DoorState.SLAM_OPENING
	door_pusher = pusher_node
	hit_bodies.clear()
	$PanelCollision.set_deferred("disabled", true)
	var side_normal := Vector2.RIGHT.rotated(global_rotation)
	var side := signf((pusher_position - global_position).dot(side_normal))
	if is_zero_approx(side): side = 1.0
	simulated_rotation = rotation
	target_rotation = snappedf(side * max_open_angle, PI / 32.0)
	is_dangerous = pusher_velocity.length() >= dangerous_speed_threshold
	dangerous_time_remaining = dangerous_window if is_dangerous else 0.0
	current_open_speed = slam_speed if is_dangerous else gentle_speed
	if is_dangerous:
		_spawn_splinters(-side_normal * side)
		Events.door_impact.emit(global_position, 1.55)
		Events.publish_combat_noise(global_position, 100.0, "door")

func receive_projectile_impact(impact_velocity: Vector2, world_point: Vector2) -> void:
	var source_position := world_point - impact_velocity.normalized() * 4.0
	_begin_open(null, source_position, impact_velocity.limit_length(dangerous_speed_threshold + 1.0))

func _spawn_splinters(direction: Vector2) -> void:
	if get_tree().current_scene == null: return
	var splinters = SPLINTER_SCENE.instantiate()
	if not RuntimeBudget.try_add("debris", splinters, get_tree().current_scene): return
	splinters.global_position = global_position + Vector2(0, 14).rotated(global_rotation)
	splinters.setup(direction)
