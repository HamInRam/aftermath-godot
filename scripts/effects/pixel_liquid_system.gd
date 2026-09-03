class_name PixelLiquidSystem
extends Node2D

## Shared sparse pixel surface for every non-blood liquid in a room. Liquid
## hazards remain small controller nodes; their visible footprint lives here so
## water, oil and chemicals never fall back to smooth vector circles.

const CHUNK_SIZE := 32
const PIXELS_PER_CHUNK := CHUNK_SIZE * CHUNK_SIZE
const MAX_JET_PARTICLES := 112
const JET_FIXED_STEP := 1.0 / 60.0
const LIQUID_KINDS := [&"water", &"oil", &"spill", &"cleaner"]
const PROFILE := {
	&"water": {"evaporation": 5, "spread": 1.0, "conductive": true, "flammable": false},
	&"oil": {"evaporation": 0, "spread": 0.46, "conductive": false, "flammable": true},
	&"spill": {"evaporation": 1, "spread": 0.68, "conductive": true, "flammable": false},
	&"cleaner": {"evaporation": 8, "spread": 0.82, "conductive": true, "flammable": false},
}

class PixelLiquidChunk extends Node2D:
	var system: PixelLiquidSystem
	var chunk_coordinate := Vector2i.ZERO
	var channels: Dictionary = {}
	var age := PackedByteArray()
	var dirty := true
	var image: Image
	var texture: ImageTexture
	var sprite: Sprite2D

	func configure(owner_system: PixelLiquidSystem, coordinate: Vector2i) -> void:
		system = owner_system
		chunk_coordinate = coordinate
		position = Vector2(coordinate * PixelLiquidSystem.CHUNK_SIZE)
		for kind in PixelLiquidSystem.LIQUID_KINDS:
			var data := PackedByteArray()
			data.resize(PixelLiquidSystem.PIXELS_PER_CHUNK)
			data.fill(0)
			channels[kind] = data
		age.resize(PixelLiquidSystem.PIXELS_PER_CHUNK)
		age.fill(0)
		image = Image.create(PixelLiquidSystem.CHUNK_SIZE, PixelLiquidSystem.CHUNK_SIZE, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		texture = ImageTexture.create_from_image(image)
		sprite = Sprite2D.new()
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.texture = texture
		add_child(sprite)
		add_to_group("pixel_liquid_chunk")

	func add_local(local_cell: Vector2i, kind: StringName, amount: int) -> int:
		if not channels.has(kind): return 0
		var index := local_cell.y * PixelLiquidSystem.CHUNK_SIZE + local_cell.x
		var data := channels[kind] as PackedByteArray
		var before := int(data[index])
		var after := clampi(before + amount, 0, 255)
		data[index] = after
		channels[kind] = data
		if after > before: age[index] = 0
		dirty = dirty or after != before
		return after - before

	func remove_local(local_cell: Vector2i, kind: StringName, amount: int) -> int:
		if not channels.has(kind): return 0
		var index := local_cell.y * PixelLiquidSystem.CHUNK_SIZE + local_cell.x
		var data := channels[kind] as PackedByteArray
		var before := int(data[index])
		var removed := mini(before, maxi(0, amount))
		data[index] = before - removed
		channels[kind] = data
		dirty = dirty or removed > 0
		return removed

	func amount_at(local_cell: Vector2i, kind: StringName = &"") -> int:
		var index := local_cell.y * PixelLiquidSystem.CHUNK_SIZE + local_cell.x
		if kind != &"" and channels.has(kind): return int((channels[kind] as PackedByteArray)[index])
		var total := 0
		for channel in channels.values(): total += int((channel as PackedByteArray)[index])
		return mini(255, total)

	func evaporate() -> bool:
		var occupied := false
		for index in PixelLiquidSystem.PIXELS_PER_CHUNK:
			var pixel_active := false
			for kind in PixelLiquidSystem.LIQUID_KINDS:
				var data := channels[kind] as PackedByteArray
				var value := int(data[index])
				if value > 0:
					var loss := int((PixelLiquidSystem.PROFILE[kind] as Dictionary).evaporation)
					data[index] = maxi(0, value - loss)
					channels[kind] = data
					pixel_active = pixel_active or data[index] > 0
					dirty = dirty or loss > 0
			age[index] = mini(255, int(age[index]) + 4) if pixel_active else 0
			occupied = occupied or pixel_active
		return occupied

	func flush_texture() -> void:
		if not dirty: return
		dirty = false
		for y in PixelLiquidSystem.CHUNK_SIZE:
			for x in PixelLiquidSystem.CHUNK_SIZE:
				var index := y * PixelLiquidSystem.CHUNK_SIZE + x
				image.set_pixel(x, y, _pixel_color(index, x, y))
		texture.update(image)

	func _pixel_color(index: int, x: int, y: int) -> Color:
		var dominant: StringName = &""
		var dominant_amount := 0
		for kind in PixelLiquidSystem.LIQUID_KINDS:
			var value := int((channels[kind] as PackedByteArray)[index])
			if value > dominant_amount:
				dominant_amount = value
				dominant = kind
		if dominant_amount <= 0: return Color.TRANSPARENT
		var density := float(dominant_amount) / 255.0
		var checker := posmod(x + y + chunk_coordinate.x * 3 + chunk_coordinate.y * 5, 7)
		match dominant:
			&"water":
				var water := Color("48cce0") if checker > 0 else Color("d8fbff")
				water.a = 0.16 + density * (0.32 if checker > 0 else 0.46)
				return water
			&"oil":
				var oil := Color("18101e") if checker > 1 else (Color("9b3fb5") if checker == 0 else Color("2a8791"))
				oil.a = 0.44 + density * 0.42
				return oil
			&"cleaner":
				return Color(0.58, 0.96, 1.0, 0.18 + density * 0.34) if checker > 1 else Color(0.92, 1.0, 1.0, 0.62)
			_:
				var chemical := Color("72dc73") if checker > 0 else Color("d9ff75")
				chemical.a = 0.24 + density * 0.46
				return chemical

var chunks: Dictionary = {}
var texture_accumulator := 0.0
var surface_accumulator := 0.0
var contact_accumulator := 0.0
var actor_tracks: Dictionary = {}
var jet_accumulator := 0.0
var jet_particles: Array[Dictionary] = []
var jet_sequence := 0
var pressure_target := Vector2.INF
var pressure_sustain := 0.0
var pressure_emit_gap := 1.0
var pressure_stability := 0.0

func _ready() -> void:
	add_to_group("pixel_liquid_system")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -1
	set_process(true)

static func get_or_create(tree: SceneTree) -> Node2D:
	var existing := tree.get_first_node_in_group("pixel_liquid_system") as Node2D
	if is_instance_valid(existing): return existing
	var system := (load("res://scripts/effects/pixel_liquid_system.gd") as Script).new() as Node2D
	system.name = "PixelLiquidSystem"
	var parent := tree.current_scene if tree.current_scene != null else tree.root
	parent.add_child(system)
	return system

func _process(delta: float) -> void:
	texture_accumulator += delta
	surface_accumulator += delta
	contact_accumulator += delta
	pressure_emit_gap += delta
	if pressure_emit_gap > 0.18:
		pressure_sustain = move_toward(pressure_sustain, 0.0, delta * 2.8)
		pressure_stability = move_toward(pressure_stability, 0.0, delta * 4.8)
	jet_accumulator += minf(delta, 0.1)
	while jet_accumulator >= JET_FIXED_STEP:
		jet_accumulator -= JET_FIXED_STEP
		_update_pressure_jets(JET_FIXED_STEP)
	if texture_accumulator >= 1.0 / 24.0:
		texture_accumulator = 0.0
		for chunk in chunks.values():
			if is_instance_valid(chunk): (chunk as PixelLiquidChunk).flush_texture()
	if surface_accumulator >= 1.0:
		surface_accumulator = fmod(surface_accumulator, 1.0)
		for chunk in chunks.values():
			if is_instance_valid(chunk) and not (chunk as PixelLiquidChunk).evaporate(): (chunk as PixelLiquidChunk).queue_free()
	if contact_accumulator >= 0.12:
		contact_accumulator = 0.0
		_update_actor_contacts()

func emit_pressure_stream(origin: Vector2, target: Vector2, brush_radius: float, power: int, washer_level := 0) -> float:
	var segment := target - origin
	if segment.length_squared() <= 4.0: return pressure_stability
	washer_level = clampi(washer_level, 0, 3)
	var continuing := pressure_target != Vector2.INF and pressure_target.distance_to(target) <= maxf(4.0, brush_radius * 0.7) and pressure_emit_gap <= 0.18
	pressure_sustain = pressure_sustain + maxf(pressure_emit_gap, 0.052) if continuing else 0.0
	var stability_time := 0.14 if washer_level >= 1 else 0.20
	pressure_stability = clampf(pressure_sustain / stability_time, 0.0, 1.0)
	pressure_target = target
	pressure_emit_gap = 0.0
	var forward := segment.normalized()
	var distance := minf(segment.length(), 40.0)
	var width_ratio := clampf((brush_radius - 3.2) / 4.8, 0.0, 1.0)
	var particle_count := clampi(roundi(lerpf(5.0, 8.0, width_ratio)), 5, 8)
	var stable_power := maxi(1, roundi(float(power) * lerpf(1.0, 1.35, pressure_stability)))
	for index in particle_count:
		if jet_particles.size() >= MAX_JET_PARTICLES: jet_particles.pop_front()
		jet_sequence += 1
		var lateral := randf_range(-brush_radius * 0.64, brush_radius * 0.64) * width_ratio
		var endpoint := target + forward.orthogonal() * lateral + forward * randf_range(-1.5, 1.5)
		var ray := origin.direction_to(endpoint)
		var speed := randf_range(154.0, 205.0) * (1.15 if washer_level >= 1 else 1.0)
		jet_particles.append({
			"position": origin + ray * float(index % 3),
			"previous": origin,
			"direction": ray,
			"speed": speed,
			"remaining": minf(origin.distance_to(endpoint), distance + 3.0),
			"power": stable_power,
			"radius": maxf(2.4 if washer_level >= 2 else 1.9, brush_radius * lerpf(0.31, 0.46, width_ratio)),
			"amount": clampi(roundi(44.0 + float(power) * 2.4), 42, 76),
			"sequence": jet_sequence,
			"washer_level": washer_level,
			"stability": pressure_stability,
		})
	queue_redraw()
	return pressure_stability

func _update_pressure_jets(delta: float) -> void:
	if jet_particles.is_empty(): return
	var active: Array[Dictionary] = []
	for particle in jet_particles:
		var previous: Vector2 = particle.position
		var travel := minf(float(particle.speed) * delta, float(particle.remaining))
		var next := previous + (particle.direction as Vector2) * travel
		var hit := _raycast_solid(previous, next)
		particle.previous = previous
		particle.remaining = float(particle.remaining) - travel
		if not hit.is_empty():
			particle.position = (hit.position as Vector2) - (particle.direction as Vector2) * 0.6
			_pressure_impact(particle, hit.normal as Vector2)
		elif float(particle.remaining) <= 0.01:
			particle.position = next
			_pressure_impact(particle, -(particle.direction as Vector2))
		else:
			particle.position = next
			active.append(particle)
	jet_particles = active
	queue_redraw()

func _pressure_impact(particle: Dictionary, surface_normal: Vector2) -> void:
	var position: Vector2 = particle.position
	var direction: Vector2 = particle.direction
	var radius := float(particle.radius)
	var amount := int(particle.amount)
	# The moving jet resolves other surface liquids only when it physically arrives;
	# fresh water is deposited afterwards so the floor remains visibly wet.
	clean_stroke(position, position, radius, int(particle.power), "pressure_washer")
	_add_liquid_pixel_raw(position, &"water", amount)
	var side := (surface_normal.normalized() if surface_normal.length_squared() > 0.01 else direction.orthogonal()).orthogonal()
	var splash_count := clampi(roundi(radius * 1.45), 2, 6)
	for index in splash_count:
		var sign_value := -1.0 if index % 2 == 0 else 1.0
		var offset := side * sign_value * float(1 + index / 2)
		if index >= 3: offset += -direction * float(index % 3)
		_add_liquid_pixel_raw(position + offset, &"water", maxi(12, amount - index * 7))
	var blood_system := get_tree().get_first_node_in_group("blood_system")
	if is_instance_valid(blood_system) and blood_system.has_method("pressure_wash_pixel_water"):
		blood_system.pressure_wash_pixel_water(position, radius, int(particle.power), direction, int(particle.washer_level))

func _draw() -> void:
	# Every airborne droplet is rendered as an integer-aligned 1x1 source pixel.
	# Sampling the short previous-to-current segment creates a coherent hose stream
	# without antialiased lines, textures or one scene node per droplet.
	for particle in jet_particles:
		var previous := to_local(particle.previous as Vector2)
		var current := to_local(particle.position as Vector2)
		var length := previous.distance_to(current)
		var steps := clampi(ceili(length), 1, 4)
		for step in range(steps + 1):
			var point := previous.lerp(current, float(step) / float(steps)).floor()
			var bright := posmod(int(particle.sequence) + step, 4) == 0 or (float(particle.stability) >= 0.75 and step % 2 == 0)
			var color := Color(0.86, 0.98, 1.0, 0.92) if bright else Color(0.25, 0.78, 0.92, 0.78)
			draw_rect(Rect2(point, Vector2.ONE), color, true)

func _raycast_solid(start: Vector2, finish: Vector2) -> Dictionary:
	if start.distance_squared_to(finish) <= 0.01: return {}
	var query := PhysicsRayQueryParameters2D.create(start, finish, 4)
	query.collide_with_areas = false
	return get_world_2d().direct_space_state.intersect_ray(query)

func get_debug_jet_count() -> int:
	return jet_particles.size()

func get_debug_pressure_stability() -> float:
	return pressure_stability

func reset_pressure_stream() -> void:
	pressure_target = Vector2.INF
	pressure_sustain = 0.0
	pressure_emit_gap = 1.0
	pressure_stability = 0.0

func emit_burst(origin: Vector2, kind: StringName, direction := Vector2.RIGHT, strength := 1.0) -> void:
	if kind not in LIQUID_KINDS: return
	var forward := direction.normalized() if direction.length_squared() > 0.01 else Vector2.RIGHT
	var count := clampi(roundi(12.0 + strength * 12.0), 12, 34)
	for index in count:
		var ray := forward.rotated(randf_range(-1.15, 1.15))
		var reach := randf_range(2.0, 8.0 + strength * 8.0)
		var endpoint := _clip_to_solid(origin, origin + ray * reach)
		_stamp_sparse_line(origin + ray * 1.5, endpoint, kind, clampi(roundi(100.0 + strength * 82.0), 90, 240), 0.38)

func deposit_source(origin: Vector2, kind: StringName, radius: float, strength: float, flow_direction := Vector2.ZERO) -> void:
	if kind not in LIQUID_KINDS: return
	var spread_scale := float((PROFILE[kind] as Dictionary).spread)
	var effective_radius := maxf(2.0, radius * spread_scale)
	var forward := flow_direction.normalized() if flow_direction.length_squared() > 0.01 else Vector2.RIGHT.rotated(randf_range(-PI, PI))
	var drop_count := clampi(roundi(5.0 + effective_radius * 0.46), 5, 18)
	add_liquid_pixel(origin, kind, clampi(roundi(86.0 + strength * 86.0), 72, 220), forward)
	for index in drop_count:
		var angle := randf_range(-PI, PI)
		var distance := sqrt(randf()) * effective_radius
		if flow_direction.length_squared() > 0.01:
			angle = forward.angle() + randf_range(-1.22, 1.22)
			distance *= randf_range(0.55, 1.28)
		var point := _clip_to_solid(origin, origin + Vector2.RIGHT.rotated(angle) * distance)
		add_liquid_pixel(point, kind, clampi(roundi(58.0 + strength * randf_range(40.0, 105.0)), 44, 210), forward)

func add_liquid_pixel(world_position: Vector2, kind: StringName, amount: int, flow_direction := Vector2.ZERO) -> void:
	if kind not in LIQUID_KINDS: return
	_add_liquid_pixel_raw(world_position, kind, amount)
	if kind in [&"water", &"cleaner"]: _mix_with_blood(world_position, amount, flow_direction)

func _add_liquid_pixel_raw(world_position: Vector2, kind: StringName, amount: int) -> void:
	if kind not in LIQUID_KINDS: return
	var cell := Vector2i(floori(world_position.x), floori(world_position.y))
	var chunk := _get_or_create_chunk(_chunk_coordinate(cell))
	chunk.add_local(_local_cell(cell), kind, amount)

func clean_stroke(world_start: Vector2, world_end: Vector2, brush_radius: float, power: int, tool_name: String) -> bool:
	var segment := world_end - world_start
	var steps := maxi(1, ceili(segment.length()))
	var touched: Dictionary = {}
	var cleaned := false
	for step in range(steps + 1):
		var sample := world_start.lerp(world_end, float(step) / float(steps))
		for y in range(floori(sample.y - brush_radius), ceili(sample.y + brush_radius) + 1):
			for x in range(floori(sample.x - brush_radius), ceili(sample.x + brush_radius) + 1):
				var cell := Vector2i(x, y)
				if touched.has(cell) or Vector2(cell).distance_squared_to(sample) > brush_radius * brush_radius: continue
				touched[cell] = true
				var chunk := _find_chunk_for_cell(cell)
				if not is_instance_valid(chunk): continue
				var local := _local_cell(cell)
				for kind in LIQUID_KINDS:
					var removal := _tool_removal(kind, tool_name, power)
					if chunk.remove_local(local, kind, removal) > 0: cleaned = true
	return cleaned

func stamp_cleaning_stroke(world_start: Vector2, world_end: Vector2, tool_name: String) -> void:
	var kind: StringName = &"water" if tool_name == "pressure_washer" else &"cleaner"
	var segment := world_end - world_start
	var steps := maxi(1, ceili(segment.length()))
	for step in range(steps + 1):
		var point := world_start.lerp(world_end, float(step) / float(steps))
		add_liquid_pixel(point, kind, 34 if kind == &"water" else 24, segment)
		if step % 3 == 0: add_liquid_pixel(point + segment.normalized().orthogonal(), kind, 18, segment)

func remove_near(world_position: Vector2, radius: float, kind: StringName, amount: int) -> int:
	var removed := 0
	for y in range(floori(world_position.y - radius), ceili(world_position.y + radius) + 1):
		for x in range(floori(world_position.x - radius), ceili(world_position.x + radius) + 1):
			var cell := Vector2i(x, y)
			if Vector2(cell).distance_squared_to(world_position) > radius * radius: continue
			var chunk := _find_chunk_for_cell(cell)
			if is_instance_valid(chunk): removed += chunk.remove_local(_local_cell(cell), kind, amount)
	return removed

func amount_near(world_position: Vector2, radius: float, kind: StringName = &"") -> int:
	var total := 0
	for y in range(floori(world_position.y - radius), ceili(world_position.y + radius) + 1):
		for x in range(floori(world_position.x - radius), ceili(world_position.x + radius) + 1):
			var cell := Vector2i(x, y)
			if Vector2(cell).distance_squared_to(world_position) > radius * radius: continue
			var chunk := _find_chunk_for_cell(cell)
			if is_instance_valid(chunk): total += chunk.amount_at(_local_cell(cell), kind)
	return total

func has_liquid_near(world_position: Vector2, radius: float, kinds := PackedStringArray()) -> bool:
	var query_kinds: Array[StringName] = LIQUID_KINDS if kinds.is_empty() else Array(kinds).map(func(value): return StringName(value))
	for kind in query_kinds:
		if amount_near(world_position, radius, kind) > 24: return true
	return false

func has_conductive_connection(source_position: Vector2, target_position: Vector2, maximum_distance := 42.0) -> bool:
	if source_position.distance_to(target_position) > maximum_distance: return false
	var start := _nearest_conductive_cell(source_position, 7)
	var goal := _nearest_conductive_cell(target_position, 6)
	if start == Vector2i(2147483647, 2147483647) or goal == Vector2i(2147483647, 2147483647): return false
	var frontier: Array[Vector2i] = [start]
	var visited := {start: true}
	var limit := 1400
	while not frontier.is_empty() and limit > 0:
		limit -= 1
		var cell := frontier.pop_front() as Vector2i
		if cell.distance_squared_to(goal) <= 4: return true
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i(-1,-1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(1,1)]:
			var next: Vector2i = cell + (offset as Vector2i)
			if visited.has(next) or Vector2(next).distance_to(source_position) > maximum_distance: continue
			if _conductive_amount(next) < 20: continue
			visited[next] = true
			frontier.append(next)
	return false

func is_flammable_near(world_position: Vector2, radius: float) -> bool:
	return amount_near(world_position, radius, &"oil") > 48

func consume_flammable(world_position: Vector2, radius: float, amount := 80) -> int:
	return remove_near(world_position, radius, &"oil", amount)

func get_debug_pixel_count(kind: StringName = &"") -> int:
	var total := 0
	for coordinate in chunks:
		var chunk := chunks[coordinate] as PixelLiquidChunk
		if not is_instance_valid(chunk): continue
		for index in PIXELS_PER_CHUNK:
			if kind == &"":
				if chunk.amount_at(Vector2i(index % CHUNK_SIZE, index / CHUNK_SIZE)) > 0: total += 1
			elif int((chunk.channels[kind] as PackedByteArray)[index]) > 0: total += 1
	return total

func _update_actor_contacts() -> void:
	var actors: Array[Node] = []
	actors.append_array(get_tree().get_nodes_in_group("player"))
	actors.append_array(get_tree().get_nodes_in_group("enemy"))
	var alive_ids: Dictionary = {}
	for actor_node in actors:
		if not actor_node is Node2D: continue
		var actor := actor_node as Node2D
		var id := actor.get_instance_id()
		alive_ids[id] = true
		var last: Vector2 = actor_tracks.get(id, actor.global_position)
		var movement := actor.global_position - last
		actor_tracks[id] = actor.global_position
		if movement.length() < 1.5: continue
		var kind := _dominant_kind_near(actor.global_position, 3.0)
		if kind == &"": continue
		if actor is CharacterBody2D:
			var traction := 0.58 if kind == &"oil" else (0.84 if kind in [&"water", &"cleaner"] else 0.72)
			(actor as CharacterBody2D).velocity = (actor as CharacterBody2D).velocity.lerp((actor as CharacterBody2D).velocity.limit_length((actor as CharacterBody2D).velocity.length() * traction), 0.16)
		var backward := -movement.normalized()
		# Two hard pixels behind the feet read as wet/oily prints without adding nodes.
		add_liquid_pixel(actor.global_position + backward * 3.0 + backward.orthogonal(), kind, 62, backward)
		add_liquid_pixel(actor.global_position + backward * 5.0 - backward.orthogonal(), kind, 42, backward)
		if movement.length() > 5.0:
			add_liquid_pixel(actor.global_position + backward.orthogonal() * 3.0, kind, 34, backward)
	for id in actor_tracks.keys():
		if not alive_ids.has(id): actor_tracks.erase(id)

func _dominant_kind_near(world_position: Vector2, radius: float) -> StringName:
	var best: StringName = &""
	var best_amount := 30
	for kind in LIQUID_KINDS:
		var amount := amount_near(world_position, radius, kind)
		if amount > best_amount:
			best_amount = amount
			best = kind
	return best

func _mix_with_blood(world_position: Vector2, amount: int, flow_direction: Vector2) -> void:
	var blood_system := get_tree().get_first_node_in_group("blood_system")
	if is_instance_valid(blood_system) and blood_system.has_method("apply_pixel_water"):
		blood_system.apply_pixel_water(world_position, amount, flow_direction)

func _tool_removal(kind: StringName, tool_name: String, power: int) -> int:
	if tool_name == "mop":
		return maxi(8, power * (30 if kind in [&"water", &"cleaner"] else 18))
	if tool_name == "pressure_washer":
		return maxi(6, power * (18 if kind == &"oil" else 26))
	return 0

func _nearest_conductive_cell(world_position: Vector2, search_radius: int) -> Vector2i:
	var origin := Vector2i(floori(world_position.x), floori(world_position.y))
	var best := Vector2i(2147483647, 2147483647)
	var best_distance := INF
	for y in range(-search_radius, search_radius + 1):
		for x in range(-search_radius, search_radius + 1):
			var cell := origin + Vector2i(x, y)
			if _conductive_amount(cell) < 20: continue
			var distance := Vector2(cell).distance_squared_to(world_position)
			if distance < best_distance:
				best_distance = distance
				best = cell
	return best

func _conductive_amount(cell: Vector2i) -> int:
	var chunk := _find_chunk_for_cell(cell)
	if not is_instance_valid(chunk): return 0
	var local := _local_cell(cell)
	return chunk.amount_at(local, &"water") + chunk.amount_at(local, &"spill") + chunk.amount_at(local, &"cleaner")

func _stamp_sparse_line(start: Vector2, finish: Vector2, kind: StringName, amount: int, density: float) -> void:
	var steps := maxi(1, ceili(start.distance_to(finish)))
	for step in range(steps + 1):
		if step > 0 and step < steps and randf() > density: continue
		add_liquid_pixel(start.lerp(finish, float(step) / float(steps)), kind, roundi(float(amount) * lerpf(1.0, 0.4, float(step) / float(steps))), finish - start)

func _clip_to_solid(start: Vector2, finish: Vector2) -> Vector2:
	if start.distance_squared_to(finish) <= 1.0: return finish
	var query := PhysicsRayQueryParameters2D.create(start, finish, 4)
	query.collide_with_areas = false
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty(): return finish
	return (hit.position as Vector2) - start.direction_to(finish)

func _chunk_coordinate(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(float(cell.x) / CHUNK_SIZE), floori(float(cell.y) / CHUNK_SIZE))

func _local_cell(cell: Vector2i) -> Vector2i:
	return Vector2i(posmod(cell.x, CHUNK_SIZE), posmod(cell.y, CHUNK_SIZE))

func _find_chunk_for_cell(cell: Vector2i) -> PixelLiquidChunk:
	return chunks.get(_chunk_coordinate(cell)) as PixelLiquidChunk

func _get_or_create_chunk(coordinate: Vector2i) -> PixelLiquidChunk:
	var chunk := chunks.get(coordinate) as PixelLiquidChunk
	if is_instance_valid(chunk): return chunk
	chunk = PixelLiquidChunk.new()
	chunks[coordinate] = chunk
	add_child(chunk)
	chunk.configure(self, coordinate)
	chunk.tree_exited.connect(func() -> void:
		if chunks.get(coordinate) == chunk: chunks.erase(coordinate)
	, CONNECT_ONE_SHOT)
	return chunk
