class_name SwingDoor
extends RigidBody2D

const SPLINTER_SCENE := preload("res://scenes/effects/door_splinters.tscn")

@export_range(0.1, 12.0, 0.1) var actor_push_scale := 3.2
@export_range(0.1, 12.0, 0.1) var projectile_push_scale := 7.5
@export_range(0.25, 1.55, 0.05) var max_open_angle := 1.4
@export_range(1.0, 10.0, 0.25) var max_angular_speed := 5.0
@export_range(0.5, 5.0, 0.1) var knockdown_angular_speed := 1.0
@export_range(0.5, 5.0, 0.1) var lethal_angular_speed := 3.2
@export_range(1.0, 20.0, 0.5) var swing_impulse := 8.5
var impact_cooldown := 0.0
var splinter_cooldown := 0.0
var projectile_lethal_window := 0.0

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 8
	$HitArea.body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	impact_cooldown = maxf(0.0, impact_cooldown - delta)
	splinter_cooldown = maxf(0.0, splinter_cooldown - delta)
	projectile_lethal_window = maxf(0.0, projectile_lethal_window - delta)

func receive_projectile_impact(impact_velocity: Vector2, world_point: Vector2) -> void:
	freeze = false
	projectile_lethal_window = 0.22
	kick_door(world_point, impact_velocity.normalized(), projectile_push_scale)
	_spawn_splinters(impact_velocity.normalized())
	_emit_impact_feedback(1.3, 105.0, 0.12)

func receive_actor_push(push_velocity: Vector2, world_point: Vector2) -> void:
	# Passive CharacterBody2D contact stays blocked; E calls slam_door explicitly.
	return

func slam_door(pusher_position: Vector2, pusher_velocity: Vector2, fallback_direction: Vector2) -> void:
	if absf(angular_velocity) > 0.65: return
	var speed_ratio := clampf(pusher_velocity.length() / 115.0, 0.0, 1.0)
	var side := signf((pusher_position - global_position).dot(Vector2.RIGHT.rotated(global_rotation).orthogonal()))
	if is_zero_approx(side): side = 1.0
	var tangent := Vector2.RIGHT.rotated(global_rotation) * -side
	var push_direction := pusher_velocity.normalized() if pusher_velocity.length_squared() > 1.0 else fallback_direction.normalized()
	if push_direction.dot(tangent) < 0.2: push_direction = tangent
	var leaf_point := global_position + Vector2(0, 14).rotated(global_rotation)
	freeze = false
	var swing_sign := signf((leaf_point - global_position).cross(push_direction))
	if is_zero_approx(swing_sign): swing_sign = -side
	angular_velocity = swing_sign * lerpf(0.8, max_angular_speed * 0.9, speed_ratio)
	if speed_ratio > 0.65: _spawn_splinters(push_direction)
	_emit_impact_feedback(lerpf(1.05, 1.55, speed_ratio), lerpf(65.0, 120.0, speed_ratio), 0.3)

func kick_door(impact_position: Vector2, impact_direction: Vector2, force_scale := 1.0) -> void:
	freeze = false
	var lever := impact_position - global_position
	var torque := lever.cross(impact_direction.normalized() * swing_impulse * force_scale)
	apply_torque_impulse(torque)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemy") and body.has_method("take_damage") and projectile_lethal_window > 0.0 and absf(angular_velocity) >= lethal_angular_speed:
		body.take_door_hit((body.global_position - global_position).normalized(), "kill")
		projectile_lethal_window = 0.0
		_spawn_splinters((body.global_position - global_position).normalized())
		_emit_impact_feedback(1.5, 110.0, 0.18)
		angular_velocity *= 0.3
	elif body.is_in_group("enemy") and body.has_method("take_door_hit") and absf(angular_velocity) >= knockdown_angular_speed:
		body.take_door_hit((body.global_position - global_position).normalized(), "knockdown")
		_emit_impact_feedback(1.35, 105.0, 0.18)
		angular_velocity *= 0.35
	elif body.is_in_group("enemy") and body.has_method("apply_stagger") and absf(angular_velocity) >= 0.45:
		var push_direction := Vector2.RIGHT.rotated(global_rotation) * signf(angular_velocity)
		body.apply_stagger(push_direction, 0.55)
		_emit_impact_feedback(1.2, 85.0, 0.2)

func _spawn_splinters(direction: Vector2) -> void:
	if splinter_cooldown > 0.0 or get_tree().current_scene == null: return
	splinter_cooldown = 0.12
	var splinters = SPLINTER_SCENE.instantiate()
	splinters.global_position = global_position + Vector2(0, 16).rotated(global_rotation)
	splinters.setup(direction)
	get_tree().current_scene.add_child(splinters)

func _emit_impact_feedback(intensity: float, hearing_radius: float, cooldown_duration: float) -> void:
	if impact_cooldown > 0.0: return
	impact_cooldown = cooldown_duration
	Events.door_impact.emit(global_position, intensity)
	Events.combat_noise.emit(global_position, hearing_radius, "door")

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	state.angular_velocity = clampf(state.angular_velocity, -max_angular_speed, max_angular_speed)
	var angle := wrapf(rotation, -PI, PI)
	var parent_rotation: float = get_parent().global_rotation
	if angle > max_open_angle:
		state.transform = Transform2D(parent_rotation + max_open_angle, state.transform.origin)
		state.angular_velocity = minf(0.0, state.angular_velocity)
	elif angle < -max_open_angle:
		state.transform = Transform2D(parent_rotation - max_open_angle, state.transform.origin)
		state.angular_velocity = maxf(0.0, state.angular_velocity)
