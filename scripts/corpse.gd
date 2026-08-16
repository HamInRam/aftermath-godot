extends CharacterBody2D

var spin := 0.0

func setup(facing: float, impact_direction := Vector2.ZERO, knockback := 0.0) -> void:
	rotation = facing + randf_range(-0.35, 0.35)
	velocity = impact_direction.normalized() * knockback
	spin = randf_range(-2.5, 2.5) * clampf(knockback / 24.0, 0.4, 1.8)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if velocity.length_squared() < 0.1:
		velocity = Vector2.ZERO
		set_physics_process(false)
		return
	var collision := move_and_collide(velocity * delta)
	if collision != null:
		velocity = velocity.slide(collision.get_normal()) * 0.3
		spin *= 0.35
	velocity = velocity.move_toward(Vector2.ZERO, 95.0 * delta)
	rotation += spin * delta
	spin = move_toward(spin, 0.0, 7.0 * delta)

func _draw() -> void:
	draw_rect(Rect2(-5, -2, 10, 4), Color("1b171e"))
	draw_rect(Rect2(-3, -2, 6, 4), Color("7c235b"))
	draw_circle(Vector2(4, 0), 2.0, Color("a87168"))
	draw_rect(Rect2(-6, -3, 3, 2), Color("302331"))
	draw_rect(Rect2(-6, 1, 3, 2), Color("302331"))
