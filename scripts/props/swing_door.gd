class_name SwingDoor
extends RigidBody2D

const SPLINTER_SCENE := preload("res://scenes/effects/door_splinters.tscn")

enum DoorState { CLOSED, SLAM_OPENING, OPEN }

@export_range(0.5, 1.57, 0.01) var max_open_angle := 1.5
@export_range(8.0, 30.0, 0.5) var slam_speed := 22.0
@export_range(0.5, 3.0, 0.1) var knockdown_speed := 1.0

var current_state := DoorState.CLOSED
var target_rotation := 0.0
var hit_bodies := {}

func _ready() -> void:
	freeze = true
	$PanelCollision.disabled = false

func _physics_process(delta: float) -> void:
	if current_state != DoorState.SLAM_OPENING: return
	var previous_rotation := rotation
	rotation = move_toward(rotation, target_rotation, slam_speed * delta)
	var actual_speed := absf(angle_difference(previous_rotation, rotation)) / maxf(delta, 0.0001)
	if actual_speed >= knockdown_speed:
		for body in $HitArea.get_overlapping_bodies():
			if not body.is_in_group("enemy") or hit_bodies.has(body.get_instance_id()): continue
			hit_bodies[body.get_instance_id()] = true
			if body.has_method("take_door_hit"):
				var hit_direction: Vector2 = (body.global_position - global_position).normalized()
				body.take_door_hit(hit_direction, "knockdown")
				Events.door_impact.emit(global_position, 1.35)
	if absf(rotation - target_rotation) <= 0.01:
		rotation = target_rotation
		current_state = DoorState.OPEN
		$PanelCollision.set_deferred("disabled", false)

func push_door_open(pusher_global_position: Vector2) -> void:
	if current_state != DoorState.CLOSED: return
	current_state = DoorState.SLAM_OPENING
	hit_bodies.clear()
	$PanelCollision.set_deferred("disabled", true)
	var side_normal := Vector2.RIGHT.rotated(global_rotation)
	var side := signf((pusher_global_position - global_position).dot(side_normal))
	if is_zero_approx(side): side = 1.0
	target_rotation = side * max_open_angle
	_spawn_splinters(-side_normal * side)
	Events.door_impact.emit(global_position, 1.55)
	Events.combat_noise.emit(global_position, 100.0, "door")

func receive_projectile_impact(impact_velocity: Vector2, world_point: Vector2) -> void:
	var source_position := world_point - impact_velocity.normalized() * 4.0
	push_door_open(source_position)

func _spawn_splinters(direction: Vector2) -> void:
	if get_tree().current_scene == null: return
	var splinters = SPLINTER_SCENE.instantiate()
	splinters.global_position = global_position + Vector2(0, 14).rotated(global_rotation)
	splinters.setup(direction)
	get_tree().current_scene.add_child(splinters)
