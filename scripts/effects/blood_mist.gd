extends Node2D

signal droplet_settled(world_position: Vector2, strength: float, direction: Vector2)

var particles: Array[Dictionary] = []
var max_lifetime := 0.34
var deposits_remaining := 10

func setup(spray_direction: Vector2, intensity: float, color := Color("b30325"), cone := 0.72) -> void:
	var direction := spray_direction.normalized()
	var count := clampi(roundi(20.0 + intensity * 16.0), 20, 60)
	for i in range(count):
		var angle := randf_range(-cone, cone)
		var speed := randf_range(28.0, 66.0) * clampf(intensity, 0.65, 2.4)
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
		var previous_life: float = particle.life
		particle.position += particle.velocity * delta
		particle.velocity *= exp(-7.5 * delta)
		particle.life -= delta
		if particle.life > 0.0:
			alive_particles.append(particle)
		elif previous_life > 0.0 and deposits_remaining > 0 and randf() < 0.48:
			droplet_settled.emit(to_global(particle.position), clampf(float(particle.size) / 1.25, 0.25, 1.0), particle.velocity.normalized())
			deposits_remaining -= 1
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
