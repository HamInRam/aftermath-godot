extends Node2D

var particles: Array[Dictionary] = []
var lifetime := 0.45

func setup(direction: Vector2) -> void:
	var forward := direction.normalized()
	for index in range(30):
		particles.append({
			"position": Vector2.ZERO,
			"velocity": forward.rotated(randf_range(-0.62, 0.62)) * randf_range(70.0, 160.0),
			"spin": randf_range(-8.0, 8.0),
			"angle": randf_range(-PI, PI),
			"double": index % 5 == 0,
		})
	queue_redraw()

func _process(delta: float) -> void:
	lifetime -= delta
	for particle in particles:
		particle.position += particle.velocity * delta
		particle.velocity = particle.velocity.move_toward(Vector2.ZERO, 260.0 * delta)
		particle.angle += particle.spin * delta
	queue_redraw()
	if lifetime <= 0.0: queue_free()

func _draw() -> void:
	var alpha := clampf(lifetime / 0.45, 0.0, 1.0)
	for particle in particles:
		var point: Vector2 = Vector2(particle.position).round()
		draw_rect(Rect2(point, Vector2.ONE), Color(0.72, 0.42, 0.17, alpha))
		if particle.double:
			var tail := Vector2.RIGHT.rotated(float(particle.angle)).round()
			draw_rect(Rect2(point + tail, Vector2.ONE), Color(0.48, 0.25, 0.12, alpha * 0.78))
