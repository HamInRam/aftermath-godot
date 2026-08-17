class_name SwingDoor
extends RigidBody2D

const SPLINTER_SCENE := preload("res://scenes/effects/door_splinters.tscn")

enum DoorState { CLOSED, SLAM_OPENING, OPEN }

@export_range(0.5, 1.57, 0.01) var max_open_angle := 1.5
@export_range(8.0, 30.0, 0.5) var slam_speed := 25.0
@export_range(2.0, 12.0, 0.5) var gentle_speed := 8.0
@export_range(20.0, 140.0, 1.0) var dangerous_speed_threshold := 81.0
@export_range(0.5, 3.0, 0.1) var knockdown_speed := 1.0

var current_state := DoorState.CLOSED
var target_rotation := 0.0
var hit_bodies := {}
var current_open_speed := 8.0
var door_pusher: Node2D
var is_dangerous := false

func _ready() -> void:
	freeze = true
	$PanelCollision.disabled = false

func _physics_process(delta: float) -> void:
	if current_state != DoorState.SLAM_OPENING: return
	var previous_rotation := rotation
	rotation = move_toward(rotation, target_rotation, current_open_speed * delta)
	var actual_speed := absf(angle_difference(previous_rotation, rotation)) / maxf(delta, 0.0001)
	if is_dangerous and actual_speed >= knockdown_speed:
		for body in $HitArea.get_overlapping_bodies():
			if body == door_pusher or not body.is_in_group("enemy") or hit_bodies.has(body.get_instance_id()): continue
			hit_bodies[body.get_instance_id()] = true
			if body.has_method("take_door_hit"):
				var hit_direction: Vector2 = (body.global_position - global_position).normalized()
				body.take_door_hit(hit_direction, "knockdown")
				Events.door_impact.emit(global_position, 1.35)
	if absf(rotation - target_rotation) <= 0.01:
		rotation = target_rotation
		current_state = DoorState.OPEN
		$PanelCollision.set_deferred("disabled", false)
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
	target_rotation = side * max_open_angle
	is_dangerous = pusher_velocity.length() >= dangerous_speed_threshold
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
	splinters.global_position = global_position + Vector2(0, 14).rotated(global_rotation)
	splinters.setup(direction)
	get_tree().current_scene.add_child(splinters)
