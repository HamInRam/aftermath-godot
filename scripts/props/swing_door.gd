class_name SwingDoor
extends RigidBody2D

@export_range(0.1, 8.0, 0.1) var actor_push_scale := 1.8
@export_range(0.1, 8.0, 0.1) var projectile_push_scale := 2.4

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func receive_projectile_impact(impact_velocity: Vector2, world_point: Vector2) -> void:
	var impulse := impact_velocity.normalized() * projectile_push_scale
	apply_impulse(impulse, to_local(world_point))

func _on_body_entered(body: Node) -> void:
	if body is CharacterBody2D and not body.is_in_group("bullet"):
		var actor := body as CharacterBody2D
		var push_direction := actor.velocity.normalized()
		if push_direction.length_squared() < 0.001:
			push_direction = (global_position - actor.global_position).normalized()
		var strength := maxf(1.0, actor.velocity.length() / 45.0) * actor_push_scale
		apply_impulse(push_direction * strength, to_local(actor.global_position))
