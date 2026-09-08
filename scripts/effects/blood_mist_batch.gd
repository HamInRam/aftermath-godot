class_name BloodMistBatch
extends Node2D

## Room-wide blood mist simulation. Every impact contributes the same hard
## one-pixel droplets, but all active sprays share one update loop and one
## MultiMesh draw submission instead of allocating a scene and draw list per hit.

const MAX_ACTIVE_PARTICLES := 2048
const MAX_TRAIL_PIXELS := 4
const MAX_DRAW_PIXELS := MAX_ACTIVE_PARTICLES * MAX_TRAIL_PIXELS
const INITIAL_DRAW_CAPACITY := 512
const DRAG := 7.5
const WALL_MASK := 4
const ANGLE_BUCKET_SIZE := PI / 48.0

var particles: Array[Dictionary] = []
var emission_remaining: Dictionary = {}
var emission_sequence := 0
var particle_batch: MultiMeshInstance2D
var draw_capacity := INITIAL_DRAW_CAPACITY

func _ready() -> void:
	particle_batch = MultiMeshInstance2D.new()
	particle_batch.name = "RoomBloodMistBatch"
	particle_batch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_2D
	instances.use_colors = true
	instances.mesh = quad
	instances.instance_count = draw_capacity
	instances.visible_instance_count = 0
	particle_batch.multimesh = instances
	add_child(particle_batch)
	set_process(false)

func emit_mist(world_position: Vector2, spray_direction: Vector2, intensity: float, _color: Color, cone: float, deposit_count: int) -> void:
	var direction := spray_direction.normalized() if spray_direction.length_squared() > 0.01 else Vector2.RIGHT
	var count := clampi(roundi(26.0 + intensity * 24.0), 26, 112)
	var available := MAX_ACTIVE_PARTICLES - particles.size()
	if available <= 0: return
	count = mini(count, available)
	emission_sequence += 1
	var emission_id := emission_sequence
	# Zero is a supported visual-only emission. Empowered ammunition uses it so
	# transient mist cannot settle as extra siphonable mass outside its ledger.
	emission_remaining[emission_id] = clampi(deposit_count, 0, 24)
	var origin := to_local(world_position)
	var pending: Array[Dictionary] = []
	var buckets: Dictionary = {}
	for index in count:
		var angle := direction.angle() + randf_range(-cone, cone)
		var particle_direction := Vector2.RIGHT.rotated(angle)
		var speed := randf_range(46.0, 106.0) * clampf(intensity, 0.65, 3.5)
		var velocity := particle_direction * speed + Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0))
		var life := randf_range(0.18, 0.34)
		var travel_distance := velocity.length() * (1.0 - exp(-DRAG * life)) / DRAG
		var bucket_id := roundi(velocity.angle() / ANGLE_BUCKET_SIZE)
		var record: Dictionary = buckets.get(bucket_id, {"direction": velocity.normalized(), "distance": 0.0})
		record.distance = maxf(float(record.distance), travel_distance)
		buckets[bucket_id] = record
		pending.append({
			"position": origin,
			"origin": origin,
			"velocity": velocity,
			"size": randf_range(0.45, 1.25),
			"life": life,
			"max_life": life,
			"color": NeonPalette.BLOOD_CRIMSON,
			"bucket": bucket_id,
			"impact_distance": INF,
			"travelled": 0.0,
			"emission": emission_id,
		})
	var bucket_hits: Dictionary = {}
	var space := get_world_2d().direct_space_state
	for bucket_id in buckets:
		var record: Dictionary = buckets[bucket_id]
		var ray_direction: Vector2 = record.direction
		var ray_distance := float(record.distance)
		var query := PhysicsRayQueryParameters2D.create(world_position, world_position + ray_direction * ray_distance, WALL_MASK)
		query.collide_with_areas = false
		var collision := space.intersect_ray(query)
		bucket_hits[bucket_id] = world_position.distance_to(collision.position) - 1.0 if not collision.is_empty() else INF
	for particle in pending:
		particle.impact_distance = float(bucket_hits.get(int(particle.bucket), INF))
		particles.append(particle)
	set_process(true)
	_refresh_batch()

func _process(delta: float) -> void:
	var survivors: Array[Dictionary] = []
	for particle in particles:
		var previous_life := float(particle.life)
		# Match the analytic drag distance used by the one-time wall queries.
		# Euler integration travelled too far at low frame rates, allowing impact
		# droplets to settle on the far side of a thin wall.
		var step := minf(maxf(delta, 0.0), maxf(previous_life, 0.0))
		var decay := exp(-DRAG * step)
		var travel := (particle.velocity as Vector2) * ((1.0 - decay) / DRAG)
		particle.position = (particle.position as Vector2) + travel
		particle.travelled = float(particle.travelled) + travel.length()
		particle.velocity = (particle.velocity as Vector2) * decay
		particle.life = previous_life - delta
		var emission_id := int(particle.emission)
		var remaining := int(emission_remaining.get(emission_id, 0))
		var impacted := float(particle.impact_distance) < INF and float(particle.travelled) >= float(particle.impact_distance)
		if impacted:
			var origin: Vector2 = particle.origin
			var direction := origin.direction_to(particle.position)
			particle.position = origin + direction * maxf(0.0, float(particle.impact_distance))
			if remaining > 0: _settle_particle(particle, emission_id, remaining)
			continue
		if float(particle.life) > 0.0:
			survivors.append(particle)
		elif previous_life > 0.0 and remaining > 0 and randf() < 0.48:
			_settle_particle(particle, emission_id, remaining)
	particles = survivors
	_prune_emissions()
	_refresh_batch()
	if particles.is_empty(): set_process(false)

func _settle_particle(particle: Dictionary, emission_id: int, remaining: int) -> void:
	emission_remaining[emission_id] = remaining - 1
	var velocity: Vector2 = particle.velocity
	var direction := velocity.normalized() if velocity.length_squared() > 0.01 else Vector2.RIGHT
	var owner := get_parent()
	if is_instance_valid(owner) and owner.has_method("spawn_micro_drop"):
		owner.spawn_micro_drop(to_global(particle.position), clampf(float(particle.size) / 1.25, 0.25, 1.0), direction)

func _prune_emissions() -> void:
	var alive: Dictionary = {}
	for particle in particles: alive[int(particle.emission)] = true
	for emission_id in emission_remaining.keys():
		if not alive.has(emission_id): emission_remaining.erase(emission_id)

func _refresh_batch() -> void:
	if not is_instance_valid(particle_batch): return
	_ensure_draw_capacity(mini(MAX_DRAW_PIXELS, particles.size() * MAX_TRAIL_PIXELS))
	var instances := particle_batch.multimesh
	var instance_index := 0
	for particle in particles:
		var max_life := maxf(0.001, float(particle.max_life))
		var alpha := clampf(float(particle.life) / max_life, 0.0, 1.0)
		var color: Color = particle.color
		color.a = alpha * 0.82
		var point := Vector2(particle.position).round()
		var velocity: Vector2 = particle.velocity
		var trail_direction := -velocity.normalized() if velocity.length_squared() > 0.01 else Vector2.ZERO
		var trail_length := clampi(roundi(minf(3.0, velocity.length() * 0.045)), 0, 3)
		for step in range(trail_length, 0, -1):
			if instance_index >= draw_capacity: break
			var trail_point := (point + trail_direction * float(step)).round() + Vector2(0.5, 0.5)
			instances.set_instance_transform_2d(instance_index, Transform2D(0.0, trail_point))
			instances.set_instance_color(instance_index, Color(color, color.a * (1.0 - float(step) / float(trail_length + 1))))
			instance_index += 1
		if instance_index >= draw_capacity: break
		instances.set_instance_transform_2d(instance_index, Transform2D(0.0, point + Vector2(0.5, 0.5)))
		instances.set_instance_color(instance_index, color)
		instance_index += 1
	instances.visible_instance_count = instance_index

func _ensure_draw_capacity(required: int) -> void:
	if required <= draw_capacity: return
	var next_capacity := draw_capacity
	while next_capacity < required:
		next_capacity = mini(MAX_DRAW_PIXELS, next_capacity * 2)
		if next_capacity >= MAX_DRAW_PIXELS: break
	draw_capacity = next_capacity
	particle_batch.multimesh.instance_count = draw_capacity

func get_debug_particle_count() -> int:
	return particles.size()

func get_debug_draw_submission_count() -> int:
	return 1 if not particles.is_empty() else 0
