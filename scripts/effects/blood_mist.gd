extends Node2D

var particles: Array[Dictionary] = []
var max_lifetime := 0.34

func setup(spray_direction: Vector2, intensity: float, color := Color("b30325"), cone := 0.72) -> void:
	var direction := spray_direction.normalized()
	var count := clampi(roundi(10.0 + intensity * 9.0), 10, 34)
	for i in range(count):
		var angle := randf_range(-cone, cone)
		var speed := randf_range(17.0, 38.0) * clampf(intensity, 0.65, 2.4)
		var velocity := direction.rotated(angle) * speed
		velocity += Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0))
		particles.append({
			"position": Vector2.ZERO,
			"velocity": velocity,
			"size": randf_range(0.45, 1.25),
			"life": randf_range(0.18, max_lifetime),
			"color": color.darkened(randf_range(0.0, 0.38)),
		})
	queue_redraw()

func _process(delta: float) -> void:
	var alive_particles: Array[Dictionary] = []
	for particle in particles:
		particle.position += particle.velocity * delta
		particle.velocity *= exp(-7.5 * delta)
		particle.life -= delta
		if particle.life > 0.0:
			alive_particles.append(particle)
	particles = alive_particles
	queue_redraw()
	if particles.is_empty(): queue_free()

func _draw() -> void:
	for particle in particles:
		var alpha: float = clampf(particle.life / max_lifetime, 0.0, 1.0)
		var color: Color = particle.color
		color.a = alpha * 0.82
		var trail: Vector2 = -particle.velocity.normalized() * minf(2.6, particle.velocity.length() * 0.045)
		draw_line(particle.position, particle.position + trail, color, maxf(0.5, particle.size * 0.65))
		draw_circle(particle.position, particle.size, color)
