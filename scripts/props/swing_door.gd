class_name SwingDoor
extends RigidBody2D

@export_range(0.1, 12.0, 0.1) var actor_push_scale := 3.2
@export_range(0.1, 12.0, 0.1) var projectile_push_scale := 7.5
@export_range(0.25, 1.55, 0.05) var max_open_angle := 1.4
@export_range(1.0, 10.0, 0.25) var max_angular_speed := 5.0
@export_range(0.5, 5.0, 0.1) var lethal_angular_speed := 2.2
var impact_cooldown := 0.0

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 8
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	impact_cooldown = maxf(0.0, impact_cooldown - delta)

func receive_projectile_impact(impact_velocity: Vector2, world_point: Vector2) -> void:
	var impulse := impact_velocity.normalized() * projectile_push_scale
	apply_impulse(impulse, world_point - global_position)
	_emit_impact_feedback(1.2, 75.0, 0.12)

func receive_actor_push(push_velocity: Vector2, world_point: Vector2) -> void:
	if push_velocity.length_squared() < 0.001: return
	var speed_falloff := 1.0 - clampf(absf(angular_velocity) / max_angular_speed, 0.0, 0.82)
	var force := push_velocity.limit_length(115.0) * actor_push_scale * speed_falloff
	apply_force(force, world_point - global_position)
	if push_velocity.length() > 90.0 and absf(angular_velocity) < 0.65:
		_emit_impact_feedback(1.2, 65.0, 0.4)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemy") and body.has_method("take_damage") and absf(angular_velocity) >= lethal_angular_speed:
		body.take_damage(1, global_position)
		_emit_impact_feedback(1.5, 110.0, 0.18)
	elif body.is_in_group("enemy") and body.has_method("apply_stagger") and absf(angular_velocity) >= 0.45:
		var push_direction := Vector2.RIGHT.rotated(global_rotation) * signf(angular_velocity)
		body.apply_stagger(push_direction, 0.55)
		_emit_impact_feedback(1.2, 85.0, 0.2)

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
