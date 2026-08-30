class_name PixelLiquidSystem
extends Node2D

## Shared sparse pixel surface for every non-blood liquid in a room. Liquid
## hazards remain small controller nodes; their visible footprint lives here so
## water, oil and chemicals never fall back to smooth vector circles.

const CHUNK_SIZE := 32
const PIXELS_PER_CHUNK := CHUNK_SIZE * CHUNK_SIZE
const LIQUID_KINDS := [&"water", &"oil", &"spill", &"cleaner", &"fuel", &"coolant", &"foam"]
const SURFACE_KINDS := [&"water", &"oil", &"spill", &"cleaner", &"fuel", &"coolant", &"foam", &"fire", &"smoke", &"ash", &"dust"]
const REACTIVE_KINDS := [&"oil", &"spill", &"cleaner", &"fuel", &"coolant", &"foam", &"fire", &"smoke"]
const PROFILE := {
	&"water": {"evaporation": 5, "spread": 1.0, "conductive": true, "flammable": false},
	&"oil": {"evaporation": 0, "spread": 0.46, "conductive": false, "flammable": true},
	&"spill": {"evaporation": 1, "spread": 0.68, "conductive": true, "flammable": false},
	&"cleaner": {"evaporation": 8, "spread": 0.82, "conductive": true, "flammable": false},
	&"fuel": {"evaporation": 3, "spread": 0.92, "conductive": false, "flammable": true},
	&"coolant": {"evaporation": 2, "spread": 0.74, "conductive": true, "flammable": false},
	&"foam": {"evaporation": 5, "spread": 0.66, "conductive": false, "flammable": false},
	&"fire": {"evaporation": 0, "spread": 0.0, "conductive": false, "flammable": false},
	&"smoke": {"evaporation": 18, "spread": 0.0, "conductive": false, "flammable": false},
	&"ash": {"evaporation": 0, "spread": 0.0, "conductive": false, "flammable": false},
	&"dust": {"evaporation": 0, "spread": 0.0, "conductive": false, "flammable": false},
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
		for kind in PixelLiquidSystem.SURFACE_KINDS:
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
			for kind in PixelLiquidSystem.SURFACE_KINDS:
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
		for kind in PixelLiquidSystem.SURFACE_KINDS:
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
			&"fuel":
				var fuel := Color("f4a13b") if checker > 1 else Color("fff08a")
				fuel.a = 0.28 + density * 0.52
				return fuel
			&"coolant":
				return Color(0.32, 0.88, 1.0, 0.24 + density * 0.48) if checker > 0 else Color(0.8, 1.0, 1.0, 0.72)
			&"foam":
				return Color(0.82, 0.98, 1.0, 0.48 + density * 0.40) if checker > 1 else Color(1.0, 1.0, 1.0, 0.88)
			&"fire":
				return Color("ff3b28") if checker > 2 else (Color("ff9b32") if checker > 0 else Color("fff08a"))
			&"smoke":
				return Color(0.20, 0.18, 0.23, 0.20 + density * 0.42) if checker > 0 else Color(0.55, 0.52, 0.57, 0.34)
			&"ash":
				return Color(0.16, 0.14, 0.17, 0.40 + density * 0.34) if checker > 0 else Color(0.42, 0.39, 0.42, 0.62)
			&"dust":
				return Color(0.66, 0.58, 0.46, 0.24 + density * 0.38) if checker > 1 else Color(0.88, 0.79, 0.62, 0.56)
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
var actor_surface_cooldowns: Dictionary = {}
var reaction_accumulator := 0.0
var drain_accumulator := 0.0
var reaction_cells: Dictionary = {}
var drain_specs: Array[Dictionary] = []

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
	reaction_accumulator += delta
	drain_accumulator += delta
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
	if reaction_accumulator >= 0.10:
		reaction_accumulator = fmod(reaction_accumulator, 0.10)
		_process_reactions(480)
	if drain_accumulator >= 0.25:
		drain_accumulator = fmod(drain_accumulator, 0.25)
		_process_drains()

func emit_burst(origin: Vector2, kind: StringName, direction := Vector2.RIGHT, strength := 1.0) -> void:
	if kind not in SURFACE_KINDS: return
	var forward := direction.normalized() if direction.length_squared() > 0.01 else Vector2.RIGHT
	var count := clampi(roundi(12.0 + strength * 12.0), 12, 34)
	for index in count:
		var ray := forward.rotated(randf_range(-1.15, 1.15))
		var reach := randf_range(2.0, 8.0 + strength * 8.0)
		var endpoint := _clip_to_solid(origin, origin + ray * reach)
		_stamp_sparse_line(origin + ray * 1.5, endpoint, kind, clampi(roundi(100.0 + strength * 82.0), 90, 240), 0.38)

func deposit_source(origin: Vector2, kind: StringName, radius: float, strength: float, flow_direction := Vector2.ZERO) -> void:
	if kind not in SURFACE_KINDS: return
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
	if kind not in SURFACE_KINDS: return
	var cell := Vector2i(floori(world_position.x), floori(world_position.y))
	var chunk := _get_or_create_chunk(_chunk_coordinate(cell))
	chunk.add_local(_local_cell(cell), kind, amount)
	if kind in [&"water", &"cleaner", &"coolant"]: _mix_with_blood(world_position, amount, flow_direction)
	if kind in REACTIVE_KINDS: _queue_reaction(cell)

func ignite_near(world_position: Vector2, radius := 5.0, strength := 1.0) -> int:
	var ignited := 0
	for y in range(floori(world_position.y - radius), ceili(world_position.y + radius) + 1):
		for x in range(floori(world_position.x - radius), ceili(world_position.x + radius) + 1):
			var cell := Vector2i(x, y)
			if Vector2(cell).distance_squared_to(world_position) > radius * radius: continue
			var fuel_load := _amount_cell(cell, &"fuel") + _amount_cell(cell, &"oil")
			if fuel_load <= 18 and Vector2(cell).distance_to(world_position) > 2.2: continue
			_add_cell(cell, &"fire", clampi(roundi(92.0 + strength * 92.0), 80, 255))
			ignited += 1
	if ignited == 0:
		_add_cell(Vector2i(floori(world_position.x), floori(world_position.y)), &"fire", clampi(roundi(120.0 * strength), 72, 220))
		ignited = 1
	return ignited

func register_drain(world_position: Vector2, radius := 9.0, efficiency := 1.0) -> void:
	for spec in drain_specs:
		if (spec.position as Vector2).distance_to(world_position) < 2.0: return
	drain_specs.append({"position": world_position, "radius": radius, "efficiency": efficiency})

func has_smoke_between(world_start: Vector2, world_end: Vector2) -> bool:
	var distance := world_start.distance_to(world_end)
	var steps := maxi(1, ceili(distance / 5.0))
	for index in range(steps + 1):
		var point := world_start.lerp(world_end, float(index) / float(steps))
		if amount_near(point, 3.0, &"smoke") > 150: return true
	return false

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
				for kind in SURFACE_KINDS:
					var removal := _tool_removal(kind, tool_name, power)
					var removed := chunk.remove_local(local, kind, removal)
					if removed <= 0: continue
					cleaned = true
					# The washer erases most contamination but visibly drives a small
					# remainder forward, making drains and room layout tactically useful.
					if tool_name == "pressure_washer" and kind in [&"water", &"oil", &"spill", &"fuel", &"coolant", &"foam"]:
						var push := segment.normalized() if segment.length_squared() > 0.01 else Vector2.RIGHT
						add_liquid_pixel(Vector2(cell) + push * 5.0, kind, roundi(float(removed) * 0.18), push)
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
	return amount_near(world_position, radius, &"oil") + amount_near(world_position, radius, &"fuel") > 48

func consume_flammable(world_position: Vector2, radius: float, amount := 80) -> int:
	return remove_near(world_position, radius, &"oil", amount) + remove_near(world_position, radius, &"fuel", amount)

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
		var fire_load := amount_near(actor.global_position, 2.5, &"fire")
		if fire_load > 80 and actor.has_method("take_damage") and float(actor_surface_cooldowns.get(id, 0.0)) <= 0.0:
			actor_surface_cooldowns[id] = 0.8
			var away := movement.normalized() if movement.length_squared() > 0.01 else Vector2.RIGHT
			actor.take_damage(1, actor.global_position - away * 4.0)
		if movement.length() < 1.5: continue
		var kind := _dominant_kind_near(actor.global_position, 3.0)
		if kind == &"": continue
		if actor is CharacterBody2D:
			var traction := 0.54 if kind in [&"oil", &"fuel", &"coolant"] else (0.84 if kind in [&"water", &"cleaner", &"foam"] else 0.72)
			(actor as CharacterBody2D).velocity = (actor as CharacterBody2D).velocity.lerp((actor as CharacterBody2D).velocity.limit_length((actor as CharacterBody2D).velocity.length() * traction), 0.16)
		var backward := -movement.normalized()
		# Two hard pixels behind the feet read as wet/oily prints without adding nodes.
		add_liquid_pixel(actor.global_position + backward * 3.0 + backward.orthogonal(), kind, 62, backward)
		add_liquid_pixel(actor.global_position + backward * 5.0 - backward.orthogonal(), kind, 42, backward)
		if movement.length() > 5.0:
			add_liquid_pixel(actor.global_position + backward.orthogonal() * 3.0, kind, 34, backward)
	for id in actor_tracks.keys():
		if actor_surface_cooldowns.has(id): actor_surface_cooldowns[id] = maxf(0.0, float(actor_surface_cooldowns[id]) - 0.12)
		if not alive_ids.has(id):
			actor_tracks.erase(id)
			actor_surface_cooldowns.erase(id)

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
		if kind in [&"fire", &"smoke", &"ash", &"dust"]: return 0
		return maxi(8, power * (30 if kind in [&"water", &"cleaner", &"foam", &"coolant"] else 18))
	if tool_name == "pressure_washer":
		if kind in [&"ash", &"dust"]: return 0
		return maxi(6, power * (42 if kind in [&"fire", &"smoke"] else (18 if kind in [&"oil", &"fuel"] else 26)))
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
	return chunk.amount_at(local, &"water") + chunk.amount_at(local, &"spill") + chunk.amount_at(local, &"cleaner") + chunk.amount_at(local, &"coolant")

func _queue_reaction(cell: Vector2i) -> void:
	reaction_cells[cell] = true
	for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]: reaction_cells[cell + offset] = true

func _process_reactions(limit: int) -> void:
	var processed := 0
	for value in reaction_cells.keys():
		if processed >= limit: break
		var cell: Vector2i = value
		reaction_cells.erase(cell)
		_react_cell(cell)
		processed += 1

func _react_cell(cell: Vector2i) -> void:
	var fire := _amount_cell(cell, &"fire")
	var water := _amount_cell(cell, &"water") + _amount_cell(cell, &"coolant")
	var foam := _amount_cell(cell, &"foam")
	var fuel := _amount_cell(cell, &"fuel") + _amount_cell(cell, &"oil")
	var cleaner := _amount_cell(cell, &"cleaner")
	var spill := _amount_cell(cell, &"spill")
	if cleaner > 40 and (spill > 30 or _amount_cell(cell, &"oil") > 30):
		var neutralized := mini(28, mini(cleaner, maxi(spill, _amount_cell(cell, &"oil"))))
		_remove_cell(cell, &"cleaner", neutralized)
		_remove_cell(cell, &"spill", neutralized)
		_remove_cell(cell, &"oil", neutralized)
		_add_cell(cell, &"foam", neutralized)
	if fire > 0:
		var suppression := water + foam * 2
		if suppression > 40:
			_remove_cell(cell, &"fire", clampi(suppression / 5, 18, 90))
			_remove_cell(cell, &"foam", 10)
			_remove_cell(cell, &"water", 8)
			_add_cell(cell, &"smoke", 18)
		else:
			var burned := mini(32, fuel)
			if burned > 0:
				var oil_here := _amount_cell(cell, &"oil")
				_remove_cell(cell, &"oil", mini(burned, oil_here))
				_remove_cell(cell, &"fuel", burned)
				_add_cell(cell, &"fire", 24)
				_add_cell(cell, &"ash", maxi(3, burned / 4))
				for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var next: Vector2i = cell + offset
					if _amount_cell(next, &"fuel") + _amount_cell(next, &"oil") > 24:
						_add_cell(next, &"fire", 54)
			else:
				_remove_cell(cell, &"fire", 26)
			_add_cell(cell + Vector2i(0, -2), &"smoke", 26)
	if _amount_cell(cell, &"smoke") > 0:
		var drift := cell + Vector2i((posmod(cell.x + cell.y, 3) - 1), -1)
		var moved := _remove_cell(cell, &"smoke", 18)
		if moved > 0: _add_cell(drift, &"smoke", maxi(1, moved - 3))
	if _cell_has_reactive_material(cell): _queue_reaction(cell)

func _process_drains() -> void:
	for spec in drain_specs:
		var position: Vector2 = spec.position
		var radius: float = float(spec.radius)
		var efficiency: float = float(spec.efficiency)
		for kind in [&"water", &"spill", &"cleaner", &"coolant", &"foam"]:
			remove_near(position, radius, kind, roundi(28.0 * efficiency))
		# Oil and fuel drain slowly, preserving their cleanup identity.
		remove_near(position, radius, &"oil", roundi(5.0 * efficiency))
		remove_near(position, radius, &"fuel", roundi(5.0 * efficiency))

func _cell_has_reactive_material(cell: Vector2i) -> bool:
	if _amount_cell(cell, &"fire") > 0 or _amount_cell(cell, &"smoke") > 0: return true
	return _amount_cell(cell, &"cleaner") > 0 and (_amount_cell(cell, &"spill") > 0 or _amount_cell(cell, &"oil") > 0)

func _amount_cell(cell: Vector2i, kind: StringName) -> int:
	var chunk := _find_chunk_for_cell(cell)
	return chunk.amount_at(_local_cell(cell), kind) if is_instance_valid(chunk) else 0

func _add_cell(cell: Vector2i, kind: StringName, amount: int) -> int:
	if amount <= 0 or kind not in SURFACE_KINDS: return 0
	var chunk := _get_or_create_chunk(_chunk_coordinate(cell))
	var added := chunk.add_local(_local_cell(cell), kind, amount)
	if added > 0 and kind in REACTIVE_KINDS: _queue_reaction(cell)
	return added

func _remove_cell(cell: Vector2i, kind: StringName, amount: int) -> int:
	var chunk := _find_chunk_for_cell(cell)
	return chunk.remove_local(_local_cell(cell), kind, amount) if is_instance_valid(chunk) else 0

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
