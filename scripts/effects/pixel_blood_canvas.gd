class_name PixelBloodCanvas
extends Node2D

signal cleaning_layer_changed(world_position: Vector2, layer: String, progress: float)
signal cleaning_region_completed(world_position: Vector2)

## Sparse room-scale blood simulation. Every occupied world pixel stores blood,
## water, age and forensic residue. Visuals are uploaded in 32x32 nearest-filtered
## chunks, so combat can paint thousands of hard pixels without thousands of nodes.

const CHUNK_SIZE := 32
const PIXELS_PER_CHUNK := CHUNK_SIZE * CHUNK_SIZE
const FRESH := Color("c7072d")
const DARK := Color("4b0318")
const DILUTED := Color("dd7b86")
const UV_GLOW := Color("78ff8a")

class PixelBloodChunk extends Node2D:
	var canvas: PixelBloodCanvas
	var chunk_coordinate := Vector2i.ZERO
	var blood := PackedByteArray()
	var water := PackedByteArray()
	var age := PackedByteArray()
	var residue := PackedByteArray()
	var active_pixels := PackedInt32Array()
	var active_flags := PackedByteArray()
	var dirty_pixels := PackedInt32Array()
	var dirty_flags := PackedByteArray()
	var initial_load := 0.0
	var blood_load := 0
	var residue_load := 0
	var ultraviolet_visible := false
	var dirty := false
	var registered := false
	var image: Image
	var texture: ImageTexture
	var sprite: Sprite2D

	func configure(owner_canvas: PixelBloodCanvas, coordinate: Vector2i) -> void:
		canvas = owner_canvas
		chunk_coordinate = coordinate
		position = Vector2(coordinate * PixelBloodCanvas.CHUNK_SIZE) + Vector2.ONE * (PixelBloodCanvas.CHUNK_SIZE * 0.5)
		z_as_relative = true
		add_to_group("pixel_blood_chunk")
		add_to_group("blood_source")
		blood.resize(PixelBloodCanvas.PIXELS_PER_CHUNK); blood.fill(0)
		water.resize(PixelBloodCanvas.PIXELS_PER_CHUNK); water.fill(0)
		age.resize(PixelBloodCanvas.PIXELS_PER_CHUNK); age.fill(0)
		residue.resize(PixelBloodCanvas.PIXELS_PER_CHUNK); residue.fill(0)
		active_flags.resize(PixelBloodCanvas.PIXELS_PER_CHUNK); active_flags.fill(0)
		dirty_flags.resize(PixelBloodCanvas.PIXELS_PER_CHUNK); dirty_flags.fill(0)
		image = Image.create(PixelBloodCanvas.CHUNK_SIZE, PixelBloodCanvas.CHUNK_SIZE, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		texture = ImageTexture.create_from_image(image)
		sprite = Sprite2D.new()
		sprite.centered = false
		sprite.position = -Vector2.ONE * (PixelBloodCanvas.CHUNK_SIZE * 0.5)
		sprite.use_parent_material = true
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.texture = texture
		add_child(sprite)

	func _mark_active(index: int) -> void:
		if active_flags[index] != 0: return
		active_flags[index] = 1
		active_pixels.append(index)

	func _mark_dirty(index: int) -> void:
		dirty = true
		if dirty_flags[index] != 0: return
		dirty_flags[index] = 1
		dirty_pixels.append(index)

	func add_local_pixel(local_cell: Vector2i, amount: int, new_water := 0, new_age := 0) -> int:
		if local_cell.x < 0 or local_cell.y < 0 or local_cell.x >= PixelBloodCanvas.CHUNK_SIZE or local_cell.y >= PixelBloodCanvas.CHUNK_SIZE: return 0
		var index := local_cell.y * PixelBloodCanvas.CHUNK_SIZE + local_cell.x
		var before := int(blood[index])
		var after := clampi(before + amount, 0, 255)
		blood[index] = after
		water[index] = maxi(int(water[index]), clampi(new_water, 0, 255))
		age[index] = mini(int(age[index]), clampi(new_age, 0, 255)) if before > 0 else clampi(new_age, 0, 255)
		var added := after - before
		blood_load += added
		initial_load += float(maxi(0, added))
		if after > 0 or water[index] > 0 or residue[index] > 0: _mark_active(index)
		_mark_dirty(index)
		if after > 0 and not registered:
			registered = true
			CleanupRegistry.register_target(self)
		return added

	func clean_local_pixel(local_cell: Vector2i, removal: int, tool_name: String) -> int:
		if local_cell.x < 0 or local_cell.y < 0 or local_cell.x >= PixelBloodCanvas.CHUNK_SIZE or local_cell.y >= PixelBloodCanvas.CHUNK_SIZE: return 0
		var index := local_cell.y * PixelBloodCanvas.CHUNK_SIZE + local_cell.x
		var before := int(blood[index])
		var residue_before := int(residue[index])
		if before <= 0 and residue_before <= 0: return 0
		var removed := mini(before, maxi(1, removal))
		if removed > 0:
			blood[index] = before - removed
			blood_load -= removed
			water[index] = 255
			if tool_name == "pressure_washer":
				var washed_residue := mini(residue_before, maxi(8, removal / 2))
				residue[index] = residue_before - washed_residue
				residue_load -= washed_residue
			else:
				var forensic_gain := mini(34, maxi(2, removed / 6))
				var residue_after := maxi(residue_before, forensic_gain)
				residue[index] = residue_after
				residue_load += residue_after - residue_before
		elif tool_name == "pressure_washer" and residue_before > 0:
			var washed_residue := mini(residue_before, maxi(10, removal))
			residue[index] = residue_before - washed_residue
			residue_load -= washed_residue
			water[index] = 220
			removed = washed_residue
		_mark_active(index)
		_mark_dirty(index)
		return removed

	func apply_external_water(local_cell: Vector2i, amount: int) -> int:
		if local_cell.x < 0 or local_cell.y < 0 or local_cell.x >= PixelBloodCanvas.CHUNK_SIZE or local_cell.y >= PixelBloodCanvas.CHUNK_SIZE: return 0
		var index := local_cell.y * PixelBloodCanvas.CHUNK_SIZE + local_cell.x
		var blood_before := int(blood[index])
		var water_before := int(water[index])
		water[index] = maxi(water_before, clampi(amount, 0, 255))
		# Running water thins the source without deleting the forensic event. Part
		# of that mass is moved downstream by the owning canvas below.
		var lifted := mini(blood_before, maxi(0, amount / 18))
		if lifted > 0:
			blood[index] = blood_before - lifted
			blood_load -= lifted
		if blood[index] > 0 or water[index] > 0 or residue[index] > 0: _mark_active(index)
		if lifted > 0 or int(water[index]) != water_before: _mark_dirty(index)
		return lifted

	func tick_surface() -> void:
		# Only occupied/wet/residual cells age. Empty cells never enter this sparse
		# list, so a room with many blood chunks no longer scans 1024 cells/chunk.
		var survivors := PackedInt32Array()
		for index in active_pixels:
			if active_flags[index] == 0: continue
			var changed := false
			if blood[index] > 0:
				var next_age := mini(255, int(age[index]) + 5)
				changed = next_age / 48 != int(age[index]) / 48
				age[index] = next_age
			if water[index] > 0:
				water[index] = maxi(0, int(water[index]) - 34)
				changed = true
			if blood[index] > 0 or water[index] > 0 or residue[index] > 0:
				survivors.append(index)
			else:
				active_flags[index] = 0
			if changed: _mark_dirty(index)
		active_pixels = survivors

	func flush_texture() -> void:
		if not dirty: return
		dirty = false
		# Preserve the exact same RGBA image, but repaint only cells changed since
		# the last upload instead of rebuilding the complete 32x32 chunk.
		var pending := dirty_pixels
		dirty_pixels = PackedInt32Array()
		for index in pending:
			dirty_flags[index] = 0
			image.set_pixel(index % PixelBloodCanvas.CHUNK_SIZE, index / PixelBloodCanvas.CHUNK_SIZE, _pixel_color(index))
		texture.update(image)

	func _pixel_color(index: int) -> Color:
		var amount := float(blood[index]) / 255.0
		var wetness := float(water[index]) / 255.0
		if amount > 0.0:
			var coagulation := floorf(clampf(float(age[index]) / 255.0, 0.0, 0.999) * 4.0) / 3.0
			var color := FRESH.lerp(DARK, coagulation)
			# Density is also a visible cleaning layer: a deliberate first pass peels
			# dark mass into a brighter diluted film before UV-only residue remains.
			var thinning := clampf((0.58 - amount) / 0.58, 0.0, 1.0)
			color = color.lerp(DILUTED, clampf(thinning * 0.72 + wetness * 0.58, 0.0, 0.88))
			color.a = clampf(0.24 + amount * 0.76, 0.0, 1.0)
			return color
		if wetness > 0.0:
			return Color(0.58, 0.75, 0.78, wetness * 0.12)
		if ultraviolet_visible and residue[index] > 0:
			var residue_strength := float(residue[index]) / 255.0
			return Color(UV_GLOW, 0.18 + residue_strength * 0.72)
		return Color.TRANSPARENT

	func clean_step() -> void:
		clean_stroke(global_position, Vector2.RIGHT, 4, "mop")

	func clean_at(world_position: Vector2, power := 1) -> bool:
		return canvas.clean_stroke(world_position, world_position, 3.5, power, "mop")

	func clean_stroke(world_position: Vector2, stroke_direction: Vector2, power: int, tool_name: String) -> bool:
		var start := world_position - stroke_direction.normalized() * 2.0 if stroke_direction.length_squared() > 0.01 else world_position
		return canvas.clean_stroke(start, world_position, 4.0 if tool_name == "mop" else 7.0, power, tool_name)

	func set_ultraviolet_visible(enabled: bool) -> void:
		if ultraviolet_visible == enabled: return
		ultraviolet_visible = enabled
		# UV changes only residual pixels; blood/wet pixels render identically.
		for index in active_pixels:
			if residue[index] > 0: _mark_dirty(index)

	func get_debug_active_pixel_count() -> int:
		return active_pixels.size()

	func get_debug_dirty_pixel_count() -> int:
		return dirty_pixels.size()

	func is_ultraviolet_residue() -> bool:
		return blood_load <= 0 and residue_load > 0

	func get_cleanup_type() -> String: return "blood"
	func get_cleanup_cost() -> int: return maxi(3, ceili(initial_load / 480.0))
	func get_cleanup_progress() -> float:
		if initial_load <= 0.0: return 1.0
		var forensic_load := float(residue_load) * 0.25
		return clampf(1.0 - (float(blood_load) + forensic_load) / initial_load, 0.0, 1.0)

	func get_cleaning_band() -> int:
		if blood_load > 0:
			var visible_ratio := clampf(float(blood_load) / maxf(1.0, initial_load), 0.0, 1.0)
			return 3 if visible_ratio > 0.58 else 2
		if residue_load > 0: return 1
		return 0

	func get_feedback_position() -> Vector2:
		return Vector2(chunk_coordinate * PixelBloodCanvas.CHUNK_SIZE) + Vector2.ONE * (PixelBloodCanvas.CHUNK_SIZE * 0.5)

	func has_visible_or_residual_blood() -> bool:
		return blood_load > 0 or residue_load > 0

	func dispose_if_empty() -> void:
		if has_visible_or_residual_blood(): return
		if registered:
			CleanupRegistry.unregister_target(self)
			registered = false
		queue_free()

var chunks: Dictionary = {}
var growing_pools: Array[Dictionary] = []
var simulation_accumulator := 0.0
var texture_accumulator := 0.0
var surface_age_accumulator := 0.0
var evidence_layer := "ground"

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(true)

func configure(layer_name: String, draw_order: int) -> void:
	evidence_layer = layer_name
	z_index = draw_order

func _process(delta: float) -> void:
	simulation_accumulator += delta
	texture_accumulator += delta
	surface_age_accumulator += delta
	if simulation_accumulator >= 0.12:
		var step := simulation_accumulator
		simulation_accumulator = 0.0
		_update_pools(step)
	if texture_accumulator >= 1.0 / 24.0:
		texture_accumulator = 0.0
		for chunk in chunks.values():
			if is_instance_valid(chunk): (chunk as PixelBloodChunk).flush_texture()
	if surface_age_accumulator >= 1.0:
		surface_age_accumulator = fmod(surface_age_accumulator, 1.0)
		for chunk in chunks.values():
			if is_instance_valid(chunk): (chunk as PixelBloodChunk).tick_surface()

func deposit_drop(world_position: Vector2, strength := 0.5, direction := Vector2.RIGHT, surface_profile := {}) -> void:
	var amount := clampi(roundi(110.0 + strength * 130.0), 64, 240)
	var spread := clampf(float(surface_profile.get("spread", 1.0)), 0.75, 1.55)
	add_blood_pixel(world_position, amount)
	if direction.length_squared() > 0.01:
		var forward := direction.normalized()
		for step in range(1, clampi(roundi(1.0 + spread), 2, 3)):
			add_blood_pixel(world_position - forward * float(step), roundi(amount * (0.62 / float(step))))

func stamp_splatter(world_position: Vector2, direction: Vector2, intensity: float, pattern: String, cone: float, wound_kind := "") -> void:
	var forward := direction.normalized() if direction.length_squared() > 0.01 else Vector2.RIGHT
	var count := clampi(roundi(10.0 + intensity * 9.0), 8, 54)
	var reach := 7.0 + intensity * (8.0 if pattern == "fan" else 11.0)
	if wound_kind in ["crush", "execution"]: reach *= 0.62
	for index in range(count):
		var angle := randf_range(-cone, cone)
		if pattern == "radial": angle = randf_range(-PI, PI)
		var ray_direction := forward.rotated(angle)
		var distance := pow(randf(), 0.58) * reach
		if pattern == "line": distance *= 1.28
		var endpoint := world_position + ray_direction * distance
		if evidence_layer == "ground" and _blocked_by_solid(world_position, endpoint):
			var query := PhysicsRayQueryParameters2D.create(world_position, endpoint, 4)
			query.collide_with_areas = false
			var hit := get_world_2d().direct_space_state.intersect_ray(query)
			if not hit.is_empty(): endpoint = (hit.position as Vector2) - ray_direction
		var amount := clampi(roundi(72.0 + intensity * randf_range(42.0, 92.0)), 48, 255)
		if pattern == "line":
			# Firearm trails are separated droplets with occasional two-pixel tails,
			# never many overlapping rays that merge into one implausible solid stripe.
			add_blood_pixel(endpoint, amount)
			if index % 3 == 0: add_blood_pixel(endpoint - ray_direction, roundi(amount * 0.58))
		else:
			_stamp_sparse_line(world_position, endpoint, amount, 0.20)
		if index % 4 == 0: _stamp_disc(endpoint, 1.0 + intensity * 0.22, amount)
	_stamp_disc(world_position, 1.5 + intensity * 0.45, clampi(roundi(118.0 + intensity * 48.0), 80, 255))

func start_pool(world_position: Vector2, intensity: float, direction: Vector2, surface_profile := {}, violence_profile := {}) -> void:
	var spread := clampf(float(surface_profile.get("spread", 1.0)), 0.78, 1.55)
	var pool_bias := clampf(float(violence_profile.get("pool_bias", 1.0)), 0.75, 1.6)
	var target_radius := (5.0 + intensity * 4.2) * spread * pool_bias
	var flow := direction.normalized() if direction.length_squared() > 0.01 else Vector2.RIGHT
	growing_pools.append({
		"position": world_position,
		"direction": flow,
		"elapsed": 0.0,
		"duration": lerpf(7.5, 4.2, clampf(intensity / 2.2, 0.0, 1.0)),
		"radius": target_radius,
		"last_step": -1,
		"amount": clampi(roundi(150.0 + intensity * 38.0), 130, 255),
	})
	_stamp_disc(world_position, 2.0, 210)

func settle_all_pools() -> void:
	# Cleanup must operate on stable evidence. Finish any remaining seep in one
	# deterministic pass so a freshly wiped strip cannot refill behind the cursor.
	for pool in growing_pools:
		var center: Vector2 = pool["position"]
		var direction: Vector2 = pool["direction"]
		var radius := float(pool["radius"])
		var amount := int(pool["amount"])
		var side := direction.orthogonal()
		var extent := ceili(radius * 1.38)
		for y in range(-extent, extent + 1):
			for x in range(-extent, extent + 1):
				var offset := Vector2(x, y)
				var forward_distance := offset.dot(direction) / maxf(1.0, radius * 1.28)
				var side_distance := offset.dot(side) / maxf(1.0, radius * 0.82)
				var normalized_distance := forward_distance * forward_distance + side_distance * side_distance
				if normalized_distance > 1.0: continue
				# Sparse one-pixel holes keep the puddle organic without fragmenting its core.
				if normalized_distance > 0.55 and posmod(x * 13 + y * 7, 11) == 0: continue
				var point := center + offset
				if not _blocked_by_solid(center, point): add_blood_pixel(point, roundi(float(amount) * lerpf(1.0, 0.48, normalized_distance)))
	growing_pools.clear()

func stamp_drag_smear(world_position: Vector2, direction: Vector2, strength := 0.65) -> void:
	var forward := direction.normalized() if direction.length_squared() > 0.01 else Vector2.RIGHT
	_stamp_sparse_line(world_position - forward * 5.0, world_position + forward * 6.0, clampi(roundi(90.0 + strength * 110.0), 70, 200), 0.72)

func stamp_footprint(world_position: Vector2, direction: Vector2, left_foot: bool, strength: float, surface_profile := {}, smudged := false) -> void:
	var forward := direction.normalized() if direction.length_squared() > 0.01 else Vector2.RIGHT
	var side := forward.orthogonal() * (-1.0 if left_foot else 1.0)
	var length := 4 if smudged else 3
	var amount := clampi(roundi(70.0 + strength * 150.0), 48, 220)
	for step in range(length):
		var point := world_position + forward * float(step - 1) + side
		add_blood_pixel(point, roundi(amount * (1.0 - float(step) * 0.15)))
		if step < 2: add_blood_pixel(point + side, roundi(amount * 0.55))

func clean_stroke(world_start: Vector2, world_end: Vector2, brush_radius: float, power: int, tool_name: String) -> bool:
	var segment := world_end - world_start
	var steps := maxi(1, ceili(segment.length()))
	var touched: Dictionary = {}
	var touched_chunks: Dictionary = {}
	var cleaned := false
	var removal := maxi(12, power * (22 if tool_name == "pressure_washer" else 18))
	for step in range(steps + 1):
		var sample := world_start.lerp(world_end, float(step) / float(steps))
		var min_x := floori(sample.x - brush_radius)
		var max_x := ceili(sample.x + brush_radius)
		var min_y := floori(sample.y - brush_radius)
		var max_y := ceili(sample.y + brush_radius)
		for y in range(min_y, max_y + 1):
			for x in range(min_x, max_x + 1):
				var cell := Vector2i(x, y)
				if touched.has(cell) or Vector2(cell).distance_squared_to(sample) > brush_radius * brush_radius: continue
				touched[cell] = true
				var chunk := _find_chunk_for_cell(cell)
				if not is_instance_valid(chunk): continue
				var chunk_id := chunk.get_instance_id()
				if not touched_chunks.has(chunk_id): touched_chunks[chunk_id] = {"chunk": chunk, "before": chunk.get_cleaning_band()}
				var local_cell := _local_cell(cell)
				if chunk.clean_local_pixel(local_cell, removal, tool_name) > 0: cleaned = true
	_emit_cleaning_transitions(touched_chunks)
	for chunk in chunks.values():
		if is_instance_valid(chunk): (chunk as PixelBloodChunk).dispose_if_empty()
	return cleaned

func pressure_wash_at(world_position: Vector2, brush_radius: float, power: int, flow_direction := Vector2.RIGHT, washer_level := 0) -> bool:
	var touched_chunks: Dictionary = {}
	var cleaned := false
	var lifted_total := 0
	var direction := flow_direction.normalized() if flow_direction.length_squared() > 0.01 else Vector2.RIGHT
	for y in range(floori(world_position.y - brush_radius), ceili(world_position.y + brush_radius) + 1):
		for x in range(floori(world_position.x - brush_radius), ceili(world_position.x + brush_radius) + 1):
			var cell := Vector2i(x, y)
			var distance := Vector2(cell).distance_to(world_position)
			if distance > brush_radius: continue
			var chunk := _find_chunk_for_cell(cell)
			if not is_instance_valid(chunk): continue
			var chunk_id := chunk.get_instance_id()
			if not touched_chunks.has(chunk_id): touched_chunks[chunk_id] = {"chunk": chunk, "before": chunk.get_cleaning_band()}
			var local := _local_cell(cell)
			var edge_loss := 0.40 if washer_level >= 2 else 0.58
			var falloff := 1.0 - clampf(distance / maxf(1.0, brush_radius), 0.0, 1.0) * edge_loss
			var residue_bonus := 1.5 if washer_level >= 3 and int(touched_chunks[chunk_id].before) <= 2 else 1.0
			var lifted := chunk.apply_external_water(local, clampi(roundi(42.0 * falloff), 15, 42))
			var washed := chunk.clean_local_pixel(local, maxi(1, roundi(float(power) * 1.05 * falloff * residue_bonus)), "pressure_washer")
			lifted_total += lifted
			cleaned = cleaned or lifted > 0 or washed > 0
	if evidence_layer == "ground" and lifted_total > 0:
		# Washed blood does not vanish: a small fraction becomes a pale, broken
		# downstream trail before subsequent droplets dilute it away.
		var runoff_steps := 3 if washer_level >= 3 else 4
		var runoff_divisor := 1.75 if washer_level >= 3 else 1.0
		for step in range(1, runoff_steps + 1):
			var destination := world_position + direction * float(step * 2) + direction.orthogonal() * float((step % 2) * 2 - 1)
			if _blocked_by_solid(world_position, destination): break
			var cell := Vector2i(floori(destination.x), floori(destination.y))
			var runoff_chunk := _get_or_create_chunk(_chunk_coordinate(cell))
			runoff_chunk.add_local_pixel(_local_cell(cell), clampi(roundi(float(lifted_total) / (float(step * 5 + 4) * runoff_divisor)), 1, 22), 255, 0)
	_emit_cleaning_transitions(touched_chunks)
	for chunk in chunks.values():
		if is_instance_valid(chunk): (chunk as PixelBloodChunk).dispose_if_empty()
	return cleaned

func _emit_cleaning_transitions(touched_chunks: Dictionary) -> void:
	for record in touched_chunks.values():
		var touched_chunk: PixelBloodChunk = record.chunk
		if not is_instance_valid(touched_chunk): continue
		var before_band := int(record.before)
		var after_band := touched_chunk.get_cleaning_band()
		if after_band >= before_band: continue
		var layer_name := "THICK"
		if after_band == 2: layer_name = "DILUTED"
		elif after_band == 1: layer_name = "UV_RESIDUE"
		elif after_band == 0: layer_name = "CLEAN"
		cleaning_layer_changed.emit(touched_chunk.get_feedback_position(), layer_name, touched_chunk.get_cleanup_progress())
		if after_band == 0: cleaning_region_completed.emit(touched_chunk.get_feedback_position())

func has_blood_near(world_position: Vector2, radius: float) -> bool:
	var min_x := floori(world_position.x - radius)
	var max_x := ceili(world_position.x + radius)
	var min_y := floori(world_position.y - radius)
	var max_y := ceili(world_position.y + radius)
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var cell := Vector2i(x, y)
			if Vector2(cell).distance_squared_to(world_position) > radius * radius: continue
			var chunk := _find_chunk_for_cell(cell)
			if not is_instance_valid(chunk): continue
			var local := _local_cell(cell)
			var index := local.y * CHUNK_SIZE + local.x
			if chunk.blood[index] > 28: return true
	return false

func add_blood_pixel(world_position: Vector2, amount: int) -> void:
	var cell := Vector2i(floori(world_position.x), floori(world_position.y))
	var chunk := _get_or_create_chunk(_chunk_coordinate(cell))
	chunk.add_local_pixel(_local_cell(cell), amount)

func apply_external_water(world_position: Vector2, amount: int, flow_direction := Vector2.ZERO) -> void:
	var flow := flow_direction.normalized() if flow_direction.length_squared() > 0.01 else Vector2.RIGHT
	var lifted_total := 0
	var affected := false
	for y in range(floori(world_position.y - 1.5), ceili(world_position.y + 1.5) + 1):
		for x in range(floori(world_position.x - 1.5), ceili(world_position.x + 1.5) + 1):
			var cell := Vector2i(x, y)
			if Vector2(cell).distance_squared_to(world_position) > 2.5: continue
			var chunk := _find_chunk_for_cell(cell)
			if not is_instance_valid(chunk): continue
			var lifted := chunk.apply_external_water(_local_cell(cell), amount)
			lifted_total += lifted
			affected = affected or lifted > 0
	if affected and lifted_total > 0:
		# A pale, broken downstream tail is the visible result of diluted blood.
		for step in range(1, 4):
			if step == 2 and posmod(floori(world_position.x + world_position.y), 2) == 0: continue
			var destination := world_position + flow * float(step * 2)
			if not _blocked_by_solid(world_position, destination):
				var cell := Vector2i(floori(destination.x), floori(destination.y))
				var chunk := _get_or_create_chunk(_chunk_coordinate(cell))
				chunk.add_local_pixel(_local_cell(cell), maxi(4, lifted_total / (step + 2)), 255, 0)

func _stamp_disc(center: Vector2, radius: float, amount: int) -> void:
	var min_x := floori(center.x - radius)
	var max_x := ceili(center.x + radius)
	var min_y := floori(center.y - radius)
	var max_y := ceili(center.y + radius)
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var distance := Vector2(x, y).distance_to(center)
			if distance <= radius:
				add_blood_pixel(Vector2(x, y), roundi(float(amount) * lerpf(1.0, 0.42, distance / maxf(1.0, radius))))

func _stamp_sparse_line(start: Vector2, finish: Vector2, amount: int, density: float) -> void:
	var distance := start.distance_to(finish)
	var steps := maxi(1, ceili(distance))
	for step in range(steps + 1):
		if step > 0 and step < steps and randf() > density: continue
		var point := start.lerp(finish, float(step) / float(steps))
		add_blood_pixel(point, roundi(float(amount) * lerpf(1.0, 0.44, float(step) / float(steps))))

func _update_pools(delta: float) -> void:
	var active: Array[Dictionary] = []
	for pool in growing_pools:
		pool.elapsed = float(pool.elapsed) + delta
		var progress := clampf(float(pool.elapsed) / float(pool.duration), 0.0, 1.0)
		var growth_step := floori(progress * 18.0)
		if growth_step > int(pool.last_step):
			pool.last_step = growth_step
			var radius := float(pool.radius) * sqrt(progress)
			var previous_radius := float(pool.radius) * sqrt(maxf(0.0, progress - 1.0 / 18.0))
			var pool_direction: Vector2 = pool["direction"]
			var pool_side := pool_direction.orthogonal()
			var pool_position: Vector2 = pool["position"]
			var extent := ceili(radius * 1.4)
			for y in range(-extent, extent + 1):
				for x in range(-extent, extent + 1):
					var offset := Vector2(x, y)
					var forward_distance := offset.dot(pool_direction) / maxf(1.0, radius * 1.28)
					var side_distance := offset.dot(pool_side) / maxf(1.0, radius * 0.82)
					var normalized_distance := forward_distance * forward_distance + side_distance * side_distance
					if normalized_distance > 1.0: continue
					if previous_radius > 1.0:
						var previous_forward := offset.dot(pool_direction) / maxf(1.0, previous_radius * 1.28)
						var previous_side := offset.dot(pool_side) / maxf(1.0, previous_radius * 0.82)
						if previous_forward * previous_forward + previous_side * previous_side <= 1.0: continue
					if normalized_distance > 0.60 and posmod(x * 13 + y * 7 + growth_step * 3, 17) == 0: continue
					var point := pool_position + offset
					if not _blocked_by_solid(pool_position, point): add_blood_pixel(point, roundi(float(pool.amount) * lerpf(1.0, 0.5, normalized_distance)))
		if progress < 1.0: active.append(pool)
	growing_pools = active

func _chunk_coordinate(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(float(cell.x) / float(CHUNK_SIZE)), floori(float(cell.y) / float(CHUNK_SIZE)))

func _local_cell(cell: Vector2i) -> Vector2i:
	return Vector2i(posmod(cell.x, CHUNK_SIZE), posmod(cell.y, CHUNK_SIZE))

func _find_chunk_for_cell(cell: Vector2i) -> PixelBloodChunk:
	var coordinate := _chunk_coordinate(cell)
	var chunk := chunks.get(coordinate) as PixelBloodChunk
	if not is_instance_valid(chunk): return null
	return chunk

func _get_or_create_chunk(coordinate: Vector2i) -> PixelBloodChunk:
	var chunk := chunks.get(coordinate) as PixelBloodChunk
	if is_instance_valid(chunk): return chunk
	chunk = PixelBloodChunk.new()
	chunks[coordinate] = chunk
	add_child(chunk)
	chunk.configure(self, coordinate)
	chunk.tree_exited.connect(func() -> void:
		if chunks.get(coordinate) == chunk: chunks.erase(coordinate)
	, CONNECT_ONE_SHOT)
	return chunk

func _blocked_by_solid(start: Vector2, finish: Vector2) -> bool:
	if evidence_layer != "ground" or start.distance_squared_to(finish) <= 1.0: return false
	var query := PhysicsRayQueryParameters2D.create(start, finish, 4)
	query.collide_with_areas = false
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func get_debug_pixel_count() -> int:
	var total := 0
	for chunk in chunks.values():
		if is_instance_valid(chunk):
			for amount in (chunk as PixelBloodChunk).blood:
				if amount > 0: total += 1
	return total

func get_debug_occupied_positions(maximum := 4096) -> PackedVector2Array:
	var positions := PackedVector2Array()
	for coordinate in chunks:
		var chunk_coordinate: Vector2i = coordinate
		var chunk := chunks[coordinate] as PixelBloodChunk
		if not is_instance_valid(chunk): continue
		for index in range(PIXELS_PER_CHUNK):
			if chunk.blood[index] <= 0: continue
			var local := Vector2i(index % CHUNK_SIZE, floori(float(index) / float(CHUNK_SIZE)))
			positions.append(Vector2(chunk_coordinate * CHUNK_SIZE + local))
			if positions.size() >= maximum: return positions
	return positions

func get_blood_amount(world_position: Vector2) -> int:
	var cell := Vector2i(floori(world_position.x), floori(world_position.y))
	var chunk := _find_chunk_for_cell(cell)
	if not is_instance_valid(chunk): return 0
	var local := _local_cell(cell)
	return int(chunk.blood[local.y * CHUNK_SIZE + local.x])

func get_residue_amount(world_position: Vector2) -> int:
	var cell := Vector2i(floori(world_position.x), floori(world_position.y))
	var chunk := _find_chunk_for_cell(cell)
	if not is_instance_valid(chunk): return 0
	var local := _local_cell(cell)
	return int(chunk.residue[local.y * CHUNK_SIZE + local.x])

func get_cleaning_layer(world_position: Vector2) -> String:
	var cell := Vector2i(floori(world_position.x), floori(world_position.y))
	var chunk := _find_chunk_for_cell(cell)
	if not is_instance_valid(chunk): return "CLEAN"
	match chunk.get_cleaning_band():
		3: return "THICK"
		2: return "DILUTED"
		1: return "UV_RESIDUE"
	return "CLEAN"

func get_wetness(world_position: Vector2) -> int:
	var cell := Vector2i(floori(world_position.x), floori(world_position.y))
	var chunk := _find_chunk_for_cell(cell)
	if not is_instance_valid(chunk): return 0
	var local := _local_cell(cell)
	return int(chunk.water[local.y * CHUNK_SIZE + local.x])
