class_name SwingDoor
extends RigidBody2D

@export_range(0.1, 12.0, 0.1) var actor_push_scale := 3.2
@export_range(0.1, 12.0, 0.1) var projectile_push_scale := 7.5
@export_range(0.25, 1.55, 0.05) var max_open_angle := 1.4

func receive_projectile_impact(impact_velocity: Vector2, world_point: Vector2) -> void:
	var impulse := impact_velocity.normalized() * projectile_push_scale
	apply_impulse(impulse, world_point - global_position)

func receive_actor_push(push_velocity: Vector2, world_point: Vector2) -> void:
	if push_velocity.length_squared() < 0.001: return
	var force := push_velocity.limit_length(100.0) * actor_push_scale
	apply_force(force, world_point - global_position)

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	var angle := wrapf(rotation, -PI, PI)
	var parent_rotation: float = get_parent().global_rotation
	if angle > max_open_angle:
		state.transform = Transform2D(parent_rotation + max_open_angle, state.transform.origin)
		state.angular_velocity = minf(0.0, state.angular_velocity)
	elif angle < -max_open_angle:
		state.transform = Transform2D(parent_rotation - max_open_angle, state.transform.origin)
		state.angular_velocity = maxf(0.0, state.angular_velocity)
