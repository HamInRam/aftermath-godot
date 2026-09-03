extends Node2D

signal droplet_settled(world_position: Vector2, strength: float, direction: Vector2)

var particles: Array[Dictionary] = []
var max_lifetime := 0.34
var deposits_remaining := 16
var trajectories_prepared := false
var trajectory_raycast_count := 0

func setup(spray_direction: Vector2, intensity: float, color := NeonPalette.BLOOD_FRESH, cone := 0.72, deposit_count := 16) -> void:
	var direction := spray_direction.normalized()
	deposits_remaining = clampi(deposit_count, 2, 24)
	var count := clampi(roundi(18.0 + intensity * 16.0), 18, 76)
	for i in range(count):
		var angle := randf_range(-cone, cone)
		var speed := randf_range(32.0, 78.0) * clampf(intensity, 0.65, 3.5)
		var velocity := direction.rotated(angle) * speed
		velocity += Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0))
		particles.append({
			"position": Vector2.ZERO,
			"velocity": velocity,
			"size": randf_range(0.45, 1.25),
			"life": randf_range(0.18, max_lifetime),
			"color": color.darkened(randf_range(0.0, 0.38)),
			"impact_distance": INF,
			"impact_position": Vector2.INF,
		})
	queue_redraw()

func _process(delta: float) -> void:
	if not trajectories_prepared: _prepare_trajectories()
	var alive_particles: Array[Dictionary] = []
	for particle in particles:
		var previous_life: float = particle.life
		var previous_position: Vector2 = particle.position
		var next_position: Vector2 = previous_position + particle.velocity * delta
		var impact_distance := float(particle.impact_distance)
		if impact_distance < INF and next_position.length() >= impact_distance and deposits_remaining > 0:
			var travel_direction: Vector2 = particle.velocity.normalized()
			droplet_settled.emit(to_global(particle.impact_position), clampf(float(particle.size) / 1.25, 0.25, 1.0), travel_direction)
			deposits_remaining -= 1
			continue
		particle.position = next_position
		particle.velocity *= exp(-7.5 * delta)
		particle.life -= delta
		if particle.life > 0.0:
			alive_particles.append(particle)
		elif previous_life > 0.0 and deposits_remaining > 0 and randf() < 0.48:
			var travel_direction: Vector2 = particle.velocity.normalized()
			droplet_settled.emit(to_global(particle.position), clampf(float(particle.size) / 1.25, 0.25, 1.0), travel_direction)
			deposits_remaining -= 1
	particles = alive_particles
	queue_redraw()
	if particles.is_empty(): queue_free()

func _prepare_trajectories() -> void:
	if trajectories_prepared: return
	trajectories_prepared = true
	# Damping changes speed but never direction. One ray to the analytically
	# predicted endpoint is therefore equivalent to per-frame segment rays, while
	# eliminating dozens of physics queries per visible droplet.
	for particle in particles:
		var velocity: Vector2 = particle.velocity
		if velocity.length_squared() <= 0.001: continue
		var lifetime := float(particle.life)
		var travel_distance := velocity.length() * (1.0 - exp(-7.5 * lifetime)) / 7.5
		var direction := velocity.normalized()
		var query := PhysicsRayQueryParameters2D.create(global_position, global_position + direction * travel_distance, 4)
		query.collide_with_areas = false
		var collision := get_world_2d().direct_space_state.intersect_ray(query)
		trajectory_raycast_count += 1
		if collision.is_empty(): continue
		var local_impact := to_local(collision.position - direction)
		particle.impact_position = local_impact
		particle.impact_distance = local_impact.length()

func get_debug_trajectory_raycast_count() -> int:
	return trajectory_raycast_count

func _draw() -> void:
	for particle in particles:
		var alpha: float = clampf(particle.life / max_lifetime, 0.0, 1.0)
		var color: Color = particle.color
		color.a = alpha * 0.82
		var pixel_position := Vector2(roundi(particle.position.x), roundi(particle.position.y))
		var trail_direction: Vector2 = -particle.velocity.normalized() if particle.velocity.length_squared() > 0.01 else Vector2.ZERO
		var trail_length := clampi(roundi(minf(3.0, particle.velocity.length() * 0.045)), 0, 3)
		for step in range(1, trail_length + 1):
			var trail_pixel := Vector2(roundi(pixel_position.x + trail_direction.x * step), roundi(pixel_position.y + trail_direction.y * step))
			draw_rect(Rect2(trail_pixel, Vector2.ONE), Color(color, color.a * (1.0 - float(step) / float(trail_length + 1))))
		draw_rect(Rect2(pixel_position, Vector2.ONE), color)
