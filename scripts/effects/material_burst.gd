class_name MaterialBurst
extends Node2D

var particles: Array[Dictionary] = []
var lifetime := 0.42

func setup(direction: Vector2, profile: Dictionary, intensity := 1.0) -> void:
	var forward := direction.normalized() if direction.length_squared() > 0.01 else Vector2.RIGHT
	var count := clampi(roundi(float(profile.get("burst", 10)) * intensity), 5, 24)
	for index in count:
		var velocity := forward.rotated(randf_range(-0.7, 0.7)) * randf_range(34.0, 112.0) * intensity
		particles.append({
			"position": Vector2.ZERO,
			"velocity": velocity,
			"double": index < 3,
			"color": profile.secondary if index % 4 == 0 else profile.primary,
		})
	z_index = 8
	queue_redraw()

func _process(delta: float) -> void:
	lifetime -= delta
	for particle in particles:
		particle.position += particle.velocity * delta
		particle.velocity = particle.velocity.move_toward(Vector2.ZERO, 150.0 * delta)
	queue_redraw()
	if lifetime <= 0.0: queue_free()

func _draw() -> void:
	var alpha := clampf(lifetime / 0.28, 0.0, 1.0)
	for particle in particles:
		var color: Color = particle.color
		color.a = alpha
		var point: Vector2 = Vector2(particle.position).round()
		draw_rect(Rect2(point, Vector2.ONE), color)
		if particle.double:
			var velocity: Vector2 = particle.velocity
			var tail := -velocity.normalized().round() if velocity.length_squared() > 0.01 else Vector2.LEFT
			draw_rect(Rect2(point + tail, Vector2.ONE), Color(color, color.a * 0.7))
