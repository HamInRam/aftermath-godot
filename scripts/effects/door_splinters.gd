extends Node2D

var particles: Array[Dictionary] = []
var lifetime := 0.55

func setup(direction: Vector2) -> void:
	var forward := direction.normalized()
	for index in range(12):
		particles.append({
			"position": Vector2.ZERO,
			"velocity": forward.rotated(randf_range(-0.9, 0.9)) * randf_range(28.0, 72.0),
			"spin": randf_range(-8.0, 8.0),
			"angle": randf_range(-PI, PI),
			"size": Vector2(randf_range(1.0, 3.0), 1.0),
		})
	queue_redraw()

func _process(delta: float) -> void:
	lifetime -= delta
	for particle in particles:
		particle.position += particle.velocity * delta
		particle.velocity = particle.velocity.move_toward(Vector2.ZERO, 90.0 * delta)
		particle.angle += particle.spin * delta
	queue_redraw()
	if lifetime <= 0.0: queue_free()

func _draw() -> void:
	var alpha := clampf(lifetime / 0.55, 0.0, 1.0)
	for particle in particles:
		draw_set_transform(particle.position, particle.angle)
		draw_rect(Rect2(-particle.size * 0.5, particle.size), Color(0.72, 0.42, 0.17, alpha))
	draw_set_transform(Vector2.ZERO, 0.0)
