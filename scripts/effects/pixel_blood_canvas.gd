class_name PixelBloodCanvas
extends Node2D

const PRESSURE_WASH_REMOVAL_SCALE := 4.8
const PRESSURE_WASH_LEVEL_BONUS := 0.35

signal cleaning_layer_changed(world_position: Vector2, layer: String, progress: float)
signal cleaning_region_completed(world_position: Vector2)

## Sparse room-scale combat blood canvas. Every occupied world pixel is immutable
## crimson until siphoned. Chunks keep thousands of hard pixels inexpensive.

const CHUNK_SIZE := 32
const PIXELS_PER_CHUNK := CHUNK_SIZE * CHUNK_SIZE
const MAX_CHUNK_UPLOADS_PER_FRAME := 4
const POOL_OCCLUSION_RAYS := 32
const FRESH := NeonPalette.BLOOD_CRIMSON
const DARK := NeonPalette.BLOOD_CRIMSON
const DILUTED := NeonPalette.BLOOD_CRIMSON
const UV_GLOW := NeonPalette.BLOOD_CRIMSON

class PixelBloodChunk extends Node2D:
	var canvas: PixelBloodCanvas
	var chunk_coordinate := Vector2i.ZERO
	var blood := PackedByteArray()
	var siphon_cursor := 0
	var pollution := PackedByteArray()
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
	var ultraviolet_mode := 0 # 0 off, 1 wall-clipped polygon, 2 radial scan
	var ultraviolet_polygon := PackedVector2Array()
	var ultraviolet_origin := Vector2.ZERO
	var ultraviolet_radius := 0.0
	var ultraviolet_possible := false
	var dirty := false
	var upload_queued := false
	var registered := false
	var image: Image
	var texture: ImageTexture
	var sprite: Sprite2D
	var previous_texture: ImageTexture
	var transition_material: ShaderMaterial
	var transition_age := 0.08
	var disposal_pending := false
	var texture_upload_count := 0
	var history_upload_count := 0

	func configure(owner_canvas: PixelBloodCanvas, coordinate: Vector2i) -> void:
		canvas = owner_canvas
		chunk_coordinate = coordinate
		position = Vector2(coordinate * PixelBloodCanvas.CHUNK_SIZE) + Vector2.ONE * (PixelBloodCanvas.CHUNK_SIZE * 0.5)
		z_as_relative = true
		add_to_group("pixel_blood_chunk")
		add_to_group("blood_source")
		blood.resize(PixelBloodCanvas.PIXELS_PER_CHUNK); blood.fill(0)
		pollution.resize(PixelBloodCanvas.PIXELS_PER_CHUNK); pollution.fill(0)
		water.resize(PixelBloodCanvas.PIXELS_PER_CHUNK); water.fill(0)
		age.resize(PixelBloodCanvas.PIXELS_PER_CHUNK); age.fill(0)
		residue.resize(PixelBloodCanvas.PIXELS_PER_CHUNK); residue.fill(0)
		active_flags.resize(PixelBloodCanvas.PIXELS_PER_CHUNK); active_flags.fill(0)
		dirty_flags.resize(PixelBloodCanvas.PIXELS_PER_CHUNK); dirty_flags.fill(0)
		image = Image.create(PixelBloodCanvas.CHUNK_SIZE, PixelBloodCanvas.CHUNK_SIZE, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		texture = ImageTexture.create_from_image(image)
		previous_texture = ImageTexture.create_from_image(image)
		transition_material = ShaderMaterial.new()
		transition_material.shader = preload("res://shaders/blood_pixel_transition.gdshader")
		transition_material.set_shader_parameter("previous_mask", previous_texture)
		transition_material.set_shader_parameter("chunk_origin", Vector2(coordinate * PixelBloodCanvas.CHUNK_SIZE))
		sprite = Sprite2D.new()
		sprite.centered = false
		sprite.position = -Vector2.ONE * (PixelBloodCanvas.CHUNK_SIZE * 0.5)
		sprite.material = transition_material
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.texture = texture
		add_child(sprite)
		set_process(false)

	func _process(delta: float) -> void:
		transition_age = minf(0.08, transition_age + delta)
		transition_material.set_shader_parameter("removal_progress", transition_age / 0.08)
		if transition_age < 0.08: return
		set_process(false)
		if dirty:
			canvas.request_chunk_upload(self)
			return
		if disposal_pending and not has_visible_or_residual_blood() and not pollution.has(1): queue_free()

	func _mark_active(index: int) -> void:
		if active_flags[index] != 0: return
		active_flags[index] = 1
		active_pixels.append(index)

	func _mark_dirty(index: int) -> void:
		dirty = true
		if not upload_queued and is_instance_valid(canvas): canvas.request_chunk_upload(self)
		if dirty_flags[index] != 0: return
		dirty_flags[index] = 1
		dirty_pixels.append(index)

	func add_local_pixel(local_cell: Vector2i, amount: int, new_water := 0, new_age := 0) -> int:
		if local_cell.x < 0 or local_cell.y < 0 or local_cell.x >= PixelBloodCanvas.CHUNK_SIZE or local_cell.y >= PixelBloodCanvas.CHUNK_SIZE: return 0
		var index := local_cell.y * PixelBloodCanvas.CHUNK_SIZE + local_cell.x
		var before := int(blood[index])
		var after := clampi(before + amount, 0, 255)
		var was_polluted := pollution[index] > 0
		var next_water := maxi(int(water[index]), clampi(new_water, 0, 255))
		var next_age := mini(int(age[index]), clampi(new_age, 0, 255)) if before > 0 else clampi(new_age, 0, 255)
		# Overlapping pellets frequently hit already saturated pixels. Preserve
		# mass and freshness, but don't dirty unchanged texture data again.
		if after == before and next_water == water[index] and next_age == age[index] and (amount <= 0 or pollution[index] == 0): return 0
		blood[index] = after
		if amount > 0: pollution[index] = 0
		water[index] = next_water
		age[index] = next_age
		var added := after - before
		blood_load += added
		initial_load += float(maxi(0, added))
		if after > 0 or water[index] > 0 or residue[index] > 0: _mark_active(index)
		# Density affects ammo, not the opaque crimson presentation.
		if (before > 0) != (after > 0) or (was_polluted and pollution[index] == 0):
			_mark_dirty(index)
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

	func absorb_local_pixel(local_cell: Vector2i, removal: int) -> int:
		# Blood absorption is a combat resource transfer, not a cleanup pass. It
		# removes visible liquid without adding water or forensic residue, allowing
		# the same sparse pixel simulation to power both gore and the roguelike loop.
		if local_cell.x < 0 or local_cell.y < 0 or local_cell.x >= PixelBloodCanvas.CHUNK_SIZE or local_cell.y >= PixelBloodCanvas.CHUNK_SIZE: return 0
		var index := local_cell.y * PixelBloodCanvas.CHUNK_SIZE + local_cell.x
		var before := int(blood[index])
		if before <= 0: return 0
		var removed := mini(before, maxi(1, removal))
		blood[index] = before - removed
		blood_load -= removed
		# Keep the sparse slot reserved until the chunk is compacted or disposed.
		# Clearing the flag while its old index remained in active_pixels allowed
		# repeated deposit/absorb cycles to append duplicates without bound.
		_mark_active(index)
		if blood[index] == 0: _mark_dirty(index)
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
		upload_queued = false
		if not dirty: return
		# Finish the current removal batch before replacing its history. A 40ms
		# siphon tick must not truncate or restart the previous 80ms transition.
		if transition_age < 0.08: return
		dirty = false
		var changed := false
		var removed := false
		for index in dirty_pixels:
			var old := image.get_pixel(index % PixelBloodCanvas.CHUNK_SIZE, index / PixelBloodCanvas.CHUNK_SIZE)
			var next := _pixel_color(index)
			if old != next:
				changed = true
				if old.r > old.g + 0.1 and next.a == 0.0: removed = true
		if removed:
			previous_texture.update(image)
			history_upload_count += 1
		# Preserve the exact same RGBA image, but repaint only cells changed since
		# the last upload instead of rebuilding the complete 32x32 chunk.
		var pending := dirty_pixels
		dirty_pixels = PackedInt32Array()
		for index in pending:
			dirty_flags[index] = 0
			image.set_pixel(index % PixelBloodCanvas.CHUNK_SIZE, index / PixelBloodCanvas.CHUNK_SIZE, _pixel_color(index))
		if not changed:
			if disposal_pending and not has_visible_or_residual_blood() and not pollution.has(1): queue_free()
			return
		texture.update(image)
		texture_upload_count += 1
		if removed:
			transition_age = 0.0
			transition_material.set_shader_parameter("removal_progress", 0.0)
			set_process(true)

	func _pixel_color(index: int) -> Color:
		if pollution[index] > 0:
			var diagonal := index % 32 + index / 32 + (chunk_coordinate.x + chunk_coordinate.y) * 32
			return Color("999999") if posmod(diagonal, 7) == 0 else Color("242424")
		# Blood density remains simulation data for absorption. Every visible blood
		# pixel is the exact same opaque crimson—no aging, dilution or UV tint.
		return FRESH if blood[index] > 0 else Color.TRANSPARENT

	func _is_pixel_ultraviolet_lit(index: int) -> bool:
		if not ultraviolet_visible or not ultraviolet_possible: return false
		var local_cell := Vector2(index % PixelBloodCanvas.CHUNK_SIZE, index / PixelBloodCanvas.CHUNK_SIZE) + Vector2(0.5, 0.5)
		var world_point := canvas.to_global(Vector2(chunk_coordinate * PixelBloodCanvas.CHUNK_SIZE) + local_cell)
		if ultraviolet_mode == 1:
			return ultraviolet_polygon.size() >= 3 and Geometry2D.is_point_in_polygon(world_point, ultraviolet_polygon)
		if ultraviolet_mode == 2:
			return world_point.distance_squared_to(ultraviolet_origin) <= ultraviolet_radius * ultraviolet_radius
		return false

	func clean_step() -> void:
		clean_stroke(global_position, Vector2.RIGHT, 4, "mop")

	func clean_at(world_position: Vector2, power := 1) -> bool:
		return canvas.clean_stroke(world_position, world_position, 3.5, power, "mop")

	func clean_stroke(world_position: Vector2, stroke_direction: Vector2, power: int, tool_name: String) -> bool:
		var start := world_position - stroke_direction.normalized() * 2.0 if stroke_direction.length_squared() > 0.01 else world_position
		return canvas.clean_stroke(start, world_position, 4.0 if tool_name == "mop" else 7.0, power, tool_name)

	func set_ultraviolet_visible(enabled: bool) -> void:
		if enabled:
			set_ultraviolet_circle(global_position, 24.0)
		else:
			clear_ultraviolet()

	func set_ultraviolet_polygon(polygon: PackedVector2Array) -> void:
		var bounds := _polygon_bounds(polygon)
		var chunk_rect := Rect2(canvas.to_global(Vector2(chunk_coordinate * PixelBloodCanvas.CHUNK_SIZE)), Vector2.ONE * PixelBloodCanvas.CHUNK_SIZE)
		var possible := polygon.size() >= 3 and bounds.intersects(chunk_rect, true)
		if ultraviolet_mode == 1 and ultraviolet_polygon == polygon and ultraviolet_possible == possible: return
		ultraviolet_mode = 1
		ultraviolet_visible = true
		ultraviolet_polygon = polygon.duplicate()
		ultraviolet_possible = possible
		_mark_all_uv_pixels_dirty()

	func set_ultraviolet_circle(origin: Vector2, radius: float) -> void:
		var quantized_origin := origin.round()
		var quantized_radius := roundf(radius)
		var chunk_rect := Rect2(canvas.to_global(Vector2(chunk_coordinate * PixelBloodCanvas.CHUNK_SIZE)), Vector2.ONE * PixelBloodCanvas.CHUNK_SIZE)
		var nearest := Vector2(
			clampf(quantized_origin.x, chunk_rect.position.x, chunk_rect.end.x),
			clampf(quantized_origin.y, chunk_rect.position.y, chunk_rect.end.y)
		)
		var possible := nearest.distance_squared_to(quantized_origin) <= quantized_radius * quantized_radius
		if ultraviolet_mode == 2 and ultraviolet_origin == quantized_origin and is_equal_approx(ultraviolet_radius, quantized_radius) and ultraviolet_possible == possible: return
		ultraviolet_mode = 2
		ultraviolet_visible = true
		ultraviolet_origin = quantized_origin
		ultraviolet_radius = quantized_radius
		ultraviolet_possible = possible
		ultraviolet_polygon = PackedVector2Array()
		_mark_all_uv_pixels_dirty()

	func clear_ultraviolet() -> void:
		if ultraviolet_mode == 0 and not ultraviolet_visible: return
		ultraviolet_mode = 0
		ultraviolet_visible = false
		ultraviolet_possible = false
		ultraviolet_polygon = PackedVector2Array()
		_mark_all_uv_pixels_dirty()

	func _mark_all_uv_pixels_dirty() -> void:
		for index in active_pixels:
			if blood[index] > 0 or residue[index] > 0: _mark_dirty(index)

	func _polygon_bounds(polygon: PackedVector2Array) -> Rect2:
		if polygon.is_empty(): return Rect2()
		var bounds := Rect2(polygon[0], Vector2.ZERO)
		for index in range(1, polygon.size()): bounds = bounds.expand(polygon[index])
		return bounds

	func is_debug_pixel_ultraviolet_lit(local_cell: Vector2i) -> bool:
		if local_cell.x < 0 or local_cell.y < 0 or local_cell.x >= PixelBloodCanvas.CHUNK_SIZE or local_cell.y >= PixelBloodCanvas.CHUNK_SIZE: return false
		return _is_pixel_ultraviolet_lit(local_cell.y * PixelBloodCanvas.CHUNK_SIZE + local_cell.x)

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
		if pollution.has(1): return
		# Let the final removal texture upload and its short pixel dissolve finish.
		disposal_pending = true
		if not dirty and transition_age >= 0.08: queue_free()

var chunks: Dictionary = {}
var upload_queue: Array[PixelBloodChunk] = []
var growing_pools: Array[Dictionary] = []
var simulation_accumulator := 0.0
var evidence_layer := "ground"

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(not upload_queue.is_empty())

func configure(layer_name: String, draw_order: int) -> void:
	evidence_layer = layer_name
	z_index = draw_order

func _process(_delta: float) -> void:
	_flush_upload_queue()

func request_chunk_upload(chunk: PixelBloodChunk) -> void:
	if not is_instance_valid(chunk) or chunk.upload_queued: return
	chunk.upload_queued = true
	upload_queue.append(chunk)
	set_process(true)

func _flush_upload_queue() -> void:
	var uploads := 0
	var consumed := 0
	while uploads < MAX_CHUNK_UPLOADS_PER_FRAME and consumed < upload_queue.size():
		# Siphoning may retire a chunk before its queued texture upload. Casting a
		# freed Godot object already raises an error, before a later validity check.
		var pending: Variant = upload_queue[consumed]
		consumed += 1
		if not is_instance_valid(pending) or pending.is_queued_for_deletion(): continue
		var chunk := pending as PixelBloodChunk
		chunk.flush_texture()
		uploads += 1
	# Compact once per batch, not once per upload (which repeatedly shifts every
	# pending entry). Preserve ordering and any entries appended while flushing.
	if consumed > 0: upload_queue = upload_queue.slice(consumed)
	if upload_queue.is_empty(): set_process(false)

func get_debug_pending_upload_count() -> int:
	return upload_queue.size()

func deposit_drop(world_position: Vector2, strength := 0.5, direction := Vector2.RIGHT, surface_profile := {}) -> void:
	var amount := clampi(roundi(110.0 + strength * 130.0), 64, 240)
	var spread := clampf(float(surface_profile.get("spread", 1.0)), 0.75, 1.55)
	add_blood_pixel(world_position, amount)
	if direction.length_squared() > 0.01:
		var forward := direction.normalized()
		for step in range(1, clampi(roundi(1.0 + spread), 2, 3)):
			add_blood_pixel(world_position - forward * float(step), roundi(amount * (0.62 / float(step))))

var splash_coverage := 1.0
var siphon_chunk_cursor := 0

## Fair, bounded work across visible chunks. Neither a full pixel sort nor a
## physics query per pixel is needed; both floor and wall layers share the fan.
func absorb_sector(origin: Vector2, forward: Vector2, reach: float, half_angle: float, proximity: float, occlusion: PackedFloat32Array, raw_budget: int, preview_only := false) -> Dictionary:
	var positions := PackedVector2Array()
	var plan: Array[Dictionary] = []
	var planned_cursors := {}
	if raw_budget <= 0 or occlusion.is_empty(): return {"amount": 0, "positions": positions}
	reach = maxf(0.0, reach)
	proximity = maxf(0.0, proximity)
	var extent := maxf(reach, proximity)
	forward = forward.normalized() if forward.length_squared() > 0.0001 else Vector2.RIGHT
	var nearby: Array[PixelBloodChunk] = []
	# Lookup only the local sparse slice, never enumerate the whole room's blood.
	# The circular broad phase contains both shapes at every aim angle.
	var first := _chunk_coordinate(Vector2i(floori(origin.x - extent), floori(origin.y - extent)))
	var last := _chunk_coordinate(Vector2i(floori(origin.x + extent), floori(origin.y + extent)))
	for cy in range(first.y, last.y + 1):
		for cx in range(first.x, last.x + 1):
			var chunk := chunks.get(Vector2i(cx, cy)) as PixelBloodChunk
			if not is_instance_valid(chunk) or chunk.is_queued_for_deletion() or chunk.blood_load <= 0: continue
			var center := Vector2(chunk.chunk_coordinate * CHUNK_SIZE) + Vector2(16, 16)
			if center.distance_squared_to(origin) <= (extent + 23.0) * (extent + 23.0): nearby.append(chunk)
	var total := 0
	var checked := 0
	if nearby.is_empty() or raw_budget <= 0: return {"amount": 0, "positions": positions}
	var share := maxi(1, ceili(float(raw_budget) / nearby.size()))
	var pressure_chunks := 0
	var cosine := cos(clampf(half_angle, 0.0, PI))
	for offset in nearby.size():
		if total >= raw_budget or checked >= 16384: break
		var chunk := nearby[(siphon_chunk_cursor + offset) % nearby.size()]
		var local_spent := 0
		var dense_source := chunk.blood_load >= 4096
		var samples := mini(512, chunk.active_pixels.size())
		var source_count := 0
		var next_source_mass := 0
		for sample in samples:
			if local_spent >= share or total >= raw_budget or checked >= 16384: break
			var index := chunk.active_pixels[(chunk.siphon_cursor + (sample if preview_only else 0)) % chunk.active_pixels.size()]
			if not preview_only: chunk.siphon_cursor += 1
			checked += 1
			if chunk.blood[index] <= 0: continue
			var local := Vector2i(index % CHUNK_SIZE, index / CHUNK_SIZE)
			var point := Vector2(chunk.chunk_coordinate * CHUNK_SIZE + local) + Vector2(0.5, 0.5)
			var delta := point - origin
			var distance := delta.length()
			if distance > proximity and (distance > reach or delta.normalized().dot(forward) < cosine): continue
			var ray := wrapf(delta.angle(), 0.0, TAU) / TAU * occlusion.size()
			var low := floori(ray) % occlusion.size()
			if distance > minf(occlusion[low], occlusion[(low + 1) % occlusion.size()]): continue
			var pixel_budget := mini(255, mini(share - local_spent, raw_budget - total))
			var removed := mini(chunk.blood[index], pixel_budget) if preview_only else chunk.absorb_local_pixel(local, pixel_budget)
			if preview_only and removed > 0: plan.append({"chunk":chunk,"local":local,"amount":removed,"point":point})
			total += removed
			local_spent += removed
			if removed > 0 and source_count < 4 and local_spent >= next_source_mass:
				positions.append(point)
				source_count += 1
				next_source_mass = local_spent + maxi(1, share / 4)
		if dense_source and local_spent > 0: pressure_chunks += 1
		if preview_only: planned_cursors[chunk] = chunk.siphon_cursor + samples
		if not preview_only: chunk.dispose_if_empty()
	if not preview_only: siphon_chunk_cursor = (siphon_chunk_cursor + 1) % nearby.size()
	return {"amount": total, "positions": positions, "pressure_chunks": pressure_chunks, "plan":plan,"cursors":planned_cursors}

func commit_siphon_plan(preview: Dictionary) -> Dictionary:
	var total := 0
	var sources := PackedVector2Array()
	var touched := {}
	for entry: Dictionary in preview.get("plan",[]):
		var chunk := entry.chunk as PixelBloodChunk
		if not is_instance_valid(chunk) or chunk.is_queued_for_deletion(): continue
		var removed := chunk.absorb_local_pixel(entry.local,entry.amount)
		if removed <= 0: continue
		total += removed
		touched[chunk] = true
		if sources.size() < 96: sources.append(entry.point)
	var cursors: Dictionary = preview.get("cursors",{})
	for chunk: PixelBloodChunk in touched:
		chunk.siphon_cursor = int(cursors.get(chunk,chunk.siphon_cursor))
		chunk.dispose_if_empty()
	siphon_chunk_cursor += 1
	return {"amount":total,"positions":sources,"pressure_chunks":mini(touched.size(),int(preview.get("pressure_chunks",0)))}

## Constant-time reads of simulation pixels; never sample a GPU texture.
func terrain_at(point: Vector2) -> int:
	var cell := Vector2i(floori(point.x), floori(point.y))
	var chunk := _find_chunk_for_cell(cell)
	if chunk == null: return 0
	var local := _local_cell(cell)
	var index := local.y * CHUNK_SIZE + local.x
	if chunk.pollution[index] > 0: return -1
	return 1 if chunk.blood[index] > 0 else 0

func stamp_pollution(center: Vector2, radius: float) -> void:
	var occlusion := _build_pool_occlusion(center, radius)
	for y in range(floori(center.y - radius), ceili(center.y + radius) + 1):
		for x in range(floori(center.x - radius), ceili(center.x + radius) + 1):
			var point := Vector2(x, y)
			if point.distance_squared_to(center) > radius * radius: continue
			if not _pool_point_visible(center, point, occlusion): continue
			var cell := Vector2i(x, y)
			var chunk := _get_or_create_chunk(_chunk_coordinate(cell))
			var local := _local_cell(cell)
			var index := local.y * CHUNK_SIZE + local.x
			chunk.absorb_local_pixel(local, 255)
			chunk.pollution[index] = 1
			chunk._mark_active(index)
			chunk._mark_dirty(index)

func _pool_point_visible(center: Vector2, point: Vector2, occlusion: PackedFloat32Array) -> bool:
	var offset := point - center
	var ray := wrapf(offset.angle(), 0.0, TAU) / TAU * POOL_OCCLUSION_RAYS
	var low := floori(ray) % POOL_OCCLUSION_RAYS
	return offset.length() <= minf(occlusion[low], occlusion[(low + 1) % POOL_OCCLUSION_RAYS])

func stamp_weapon_footprint(center: Vector2, direction: Vector2, weapon_class: String, raw_budget := -1, stain_radius := 32.0) -> int:
	var forward := direction.normalized()
	if forward == Vector2.ZERO: forward = Vector2.RIGHT
	var total := 0
	var reach := 320.0 if weapon_class == "sniper" else clampf(stain_radius, 4.0, 320.0)
	var occlusion := _build_pool_occlusion(center, reach)
	if weapon_class == "sniper":
		var hit := get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(center, center + forward * reach, 4))
		if not hit.is_empty(): reach = maxf(0.0, center.distance_to(hit.position) - 1.0)
		for step in range(321):
			if step > reach: break
			var point := center + forward * step
			if not _pool_point_visible(center, point, occlusion): break
			for side in range(-1, 2):
				if raw_budget >= 0 and total >= raw_budget: return total
				var p := point + forward.orthogonal() * side
				if _pool_point_visible(center, p, occlusion):
					total += add_blood_pixel(p, mini(2, raw_budget - total) if raw_budget >= 0 else 2)
	elif weapon_class == "shotgun":
		var needs_occlusion := false
		for distance in occlusion:
			if distance < reach:
				needs_occlusion = true
				break
		var radius_squared := reach * reach
		var base_cell := Vector2i(floori(center.x), floori(center.y))
		for y in range(-ceili(reach), ceili(reach) + 1):
			var row_extent := floori(sqrt(maxf(0.0, radius_squared - float(y * y))))
			var row_chunk: PixelBloodChunk
			var row_coordinate := Vector2i(2147483647, 2147483647)
			for x in range(-row_extent, row_extent + 1):
				if raw_budget >= 0 and total >= raw_budget: return total
				var projection := float(x) * forward.x + float(y) * forward.y
				if projection < 0.0 or projection * projection < 0.49 * float(x * x + y * y): continue
				var point := center + Vector2(x, y)
				if not needs_occlusion or _pool_point_visible(center, point, occlusion):
					var cell := base_cell + Vector2i(x, y)
					var coordinate := _chunk_coordinate(cell)
					if coordinate != row_coordinate:
						row_coordinate = coordinate
						row_chunk = _get_or_create_chunk(coordinate)
					total += row_chunk.add_local_pixel(cell - coordinate * CHUNK_SIZE, mini(2, raw_budget - total) if raw_budget >= 0 else 2)
	return total

func stamp_splatter(world_position: Vector2, direction: Vector2, intensity: float, pattern: String, cone: float, wound_kind := "", raw_budget := -1, stain_radius := -1.0, yield_multiplier := 1.0) -> int:
	var forward := direction.normalized() if direction.length_squared() > 0.01 else Vector2.RIGHT
	var count := clampi(roundi(10.0 + intensity * 9.0), 8, 54)
	var reach := 7.0 + intensity * (8.0 if pattern == "fan" else 11.0)
	var coverage := clampf(splash_coverage, 1.0, 2.0)
	# Spread thinner opaque crimson over more floor, not more resource per pixel.
	var mass_scale := 1.0 / (coverage * coverage * coverage)
	# Finite-budget legacy shots cannot gain mass through the combo modifier.
	if raw_budget < 0: mass_scale *= clampf(yield_multiplier, 1.0, 2.0)
	reach *= coverage
	if stain_radius > 0.0: reach = stain_radius * clampf(0.65 + intensity * 0.15, 0.65, 1.6)
	count = roundi(count * coverage)
	var total_added := 0
	if wound_kind in ["crush", "execution"]: reach *= 0.62
	for index in range(count):
		if raw_budget >= 0 and total_added >= raw_budget: break
		var angle := randf_range(-cone, cone)
		if pattern == "radial": angle = randf_range(-PI, PI)
		var ray_direction := forward.rotated(angle)
		var distance := pow(randf(), 0.58) * reach
		if pattern == "line": distance *= 1.28
		var endpoint := world_position + ray_direction * distance
		if evidence_layer == "ground" and is_inside_tree() and world_position.distance_squared_to(endpoint) > 1.0:
			var query := PhysicsRayQueryParameters2D.create(world_position, endpoint, 4)
			query.collide_with_areas = false
			var hit := get_world_2d().direct_space_state.intersect_ray(query)
			if not hit.is_empty(): endpoint = (hit.position as Vector2) - ray_direction
		var amount := maxi(1, roundi(clampi(roundi(72.0 + intensity * randf_range(42.0, 92.0)), 48, 255) * mass_scale))
		if pattern in ["line", "dots"]:
			# Firearm trails are separated droplets with occasional two-pixel tails,
			# never many overlapping rays that merge into one implausible solid stripe.
			total_added += add_blood_pixel(endpoint, mini(amount, raw_budget - total_added) if raw_budget >= 0 else amount)
			if index % 3 == 0 and (raw_budget < 0 or total_added < raw_budget):
				var tail_amount := roundi(amount * 0.58)
				total_added += add_blood_pixel(endpoint - ray_direction, mini(tail_amount, raw_budget - total_added) if raw_budget >= 0 else tail_amount)
		else:
			total_added += _stamp_sparse_line_budgeted(world_position, endpoint, amount, 0.20 * coverage, raw_budget - total_added if raw_budget >= 0 else -1)
		if pattern != "dots" and index % 4 == 0 and (raw_budget < 0 or total_added < raw_budget):
			total_added += _stamp_disc_budgeted(endpoint, (1.0 + intensity * 0.22) * coverage, amount, raw_budget - total_added if raw_budget >= 0 else -1)
	if pattern != "dots" and (raw_budget < 0 or total_added < raw_budget):
		total_added += _stamp_disc_budgeted(world_position, (1.5 + intensity * 0.45) * coverage, maxi(1, roundi(clampi(roundi(118.0 + intensity * 48.0), 80, 255) * mass_scale)), raw_budget - total_added if raw_budget >= 0 else -1)
	return total_added

func start_pool(world_position: Vector2, intensity: float, direction: Vector2, surface_profile := {}, violence_profile := {}) -> void:
	# Compatibility entry point for existing impact profiles: deaths leave one
	# immediate finite stain. They never seep, grow, recolor or emit more blood.
	var spread := clampf(float(surface_profile.get("spread", 1.0)), 0.78, 1.35)
	var pool_bias := clampf(float(violence_profile.get("pool_bias", 1.0)), 0.70, 1.35)
	var radius := clampf((2.2 + intensity * 1.25) * spread * pool_bias, 2.0, 6.5)
	_stamp_disc(world_position, radius, 255)

func settle_all_pools() -> void:
	growing_pools.clear()

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
			var lifted := chunk.apply_external_water(local, clampi(roundi(56.0 * falloff), 20, 56))
			# Pressure packets arrive less often than a continuous mop capsule. Each
			# physical impact therefore needs enough hydraulic removal to make the
			# stock washer decisively stronger on liquid stains, while its wide nozzle
			# still trades focused power for coverage.
			var hydraulic_scale := PRESSURE_WASH_REMOVAL_SCALE + float(washer_level) * PRESSURE_WASH_LEVEL_BONUS
			var washed := chunk.clean_local_pixel(local, maxi(1, roundi(float(power) * hydraulic_scale * falloff * residue_bonus)), "pressure_washer")
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

func absorb_circle(world_position: Vector2, radius: float, removal_per_pixel: int, maximum_samples := 48, maximum_total := 255) -> Dictionary:
	# Traverse only sparse occupied pixels in overlapping chunks, then consume the
	# nearest candidates. The previous >28px stride skipped one coordinate parity
	# forever while the actor stood still, leaving visibly permanent blood cells.
	var total := 0
	var positions := PackedVector2Array()
	var touched_chunks: Dictionary = {}
	var candidates: Array[Dictionary] = []
	var min_chunk := _chunk_coordinate(Vector2i(floori(world_position.x - radius), floori(world_position.y - radius)))
	var max_chunk := _chunk_coordinate(Vector2i(ceili(world_position.x + radius), ceili(world_position.y + radius)))
	var radius_squared := radius * radius
	for chunk_y in range(min_chunk.y, max_chunk.y + 1):
		for chunk_x in range(min_chunk.x, max_chunk.x + 1):
			var chunk := chunks.get(Vector2i(chunk_x, chunk_y)) as PixelBloodChunk
			if not is_instance_valid(chunk): continue
			for index in chunk.active_pixels:
				if chunk.active_flags[index] == 0 or chunk.blood[index] <= 0: continue
				var local_cell := Vector2i(index % CHUNK_SIZE, floori(float(index) / float(CHUNK_SIZE)))
				var cell := chunk.chunk_coordinate * CHUNK_SIZE + local_cell
				var sample_position := Vector2(cell) + Vector2(0.5, 0.5)
				var distance_squared := sample_position.distance_squared_to(world_position)
				if distance_squared <= radius_squared:
					candidates.append({"distance": distance_squared, "cell": cell, "chunk": chunk})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.distance) < float(b.distance))
	var visited := 0
	for candidate in candidates:
		if visited >= maximum_samples or total >= maximum_total: break
		var chunk: PixelBloodChunk = candidate.chunk
		var cell: Vector2i = candidate.cell
		var removed := chunk.absorb_local_pixel(_local_cell(cell), mini(removal_per_pixel, maximum_total - total))
		if removed <= 0: continue
		total += removed
		visited += 1
		touched_chunks[chunk.get_instance_id()] = chunk
		if positions.size() < 40: positions.append(Vector2(cell) + Vector2(0.5, 0.5))
	for chunk in touched_chunks.values():
		if is_instance_valid(chunk): (chunk as PixelBloodChunk).dispose_if_empty()
	if total > 0: _consume_intersecting_pool_growth(positions)
	return {"amount": total, "positions": positions}

func _consume_intersecting_pool_growth(absorbed_positions: PackedVector2Array) -> void:
	if absorbed_positions.is_empty() or growing_pools.is_empty(): return
	var survivors: Array[Dictionary] = []
	for pool in growing_pools:
		var consumed := false
		var pool_position: Vector2 = pool.position
		var capture_radius := maxf(4.0, float(pool.radius) * 1.08)
		for source in absorbed_positions:
			if source.distance_squared_to(pool_position) <= capture_radius * capture_radius:
				consumed = true
				break
		if not consumed: survivors.append(pool)
	growing_pools = survivors

func absorb_cone(world_position: Vector2, direction: Vector2, reach: float, half_angle: float, removal_per_pixel: int, maximum_samples := 48, maximum_total := 255) -> Dictionary:
	# Combat siphoning is intentionally aim-driven. Sampling the cone from near to
	# far makes the nearest visible blood peel away first and prevents blood behind
	# the player from being collected simply because it shares the same radius.
	var total := 0
	var positions := PackedVector2Array()
	var touched_chunks: Dictionary = {}
	var visited_cells: Dictionary = {}
	var forward := direction.normalized() if direction.length_squared() > 0.001 else Vector2.RIGHT
	var reach_i := maxi(3, ceili(reach))
	var clamped_half_angle := clampf(half_angle, 0.08, PI * 0.48)
	var visited_blood_samples := 0
	for distance_step in range(3, reach_i + 1):
		var arc_samples := maxi(3, ceili(float(distance_step) * clamped_half_angle * 1.35))
		for arc_index in range(arc_samples + 1):
			if visited_blood_samples >= maximum_samples or total >= maximum_total: break
			var weight := float(arc_index) / float(arc_samples)
			var angle := lerpf(-clamped_half_angle, clamped_half_angle, weight)
			var sample_position := world_position + forward.rotated(angle) * float(distance_step)
			var cell := Vector2i(floori(sample_position.x), floori(sample_position.y))
			if visited_cells.has(cell): continue
			visited_cells[cell] = true
			var chunk := _find_chunk_for_cell(cell)
			if not is_instance_valid(chunk): continue
			var removed := chunk.absorb_local_pixel(_local_cell(cell), mini(removal_per_pixel, maximum_total - total))
			if removed <= 0: continue
			total += removed
			visited_blood_samples += 1
			touched_chunks[chunk.get_instance_id()] = chunk
			if positions.size() < 16: positions.append(Vector2(cell) + Vector2(0.5, 0.5))
		if visited_blood_samples >= maximum_samples or total >= maximum_total: break
	for chunk in touched_chunks.values():
		if is_instance_valid(chunk): (chunk as PixelBloodChunk).dispose_if_empty()
	if total > 0: _consume_intersecting_pool_growth(positions)
	return {"amount": total, "positions": positions}

func add_blood_pixel(world_position: Vector2, amount: int) -> int:
	if amount <= 0: return 0
	var cell := Vector2i(floori(world_position.x), floori(world_position.y))
	var chunk := _get_or_create_chunk(_chunk_coordinate(cell))
	return chunk.add_local_pixel(_local_cell(cell), amount)

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
	_stamp_disc_budgeted(center, radius, amount, -1)

func _stamp_disc_budgeted(center: Vector2, radius: float, amount: int, raw_budget: int) -> int:
	var total_added := 0
	var min_x := floori(center.x - radius)
	var max_x := ceili(center.x + radius)
	var min_y := floori(center.y - radius)
	var max_y := ceili(center.y + radius)
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			if raw_budget >= 0 and total_added >= raw_budget: return total_added
			var distance := Vector2(x, y).distance_to(center)
			if distance <= radius:
				var pixel_amount := roundi(float(amount) * lerpf(1.0, 0.42, distance / maxf(1.0, radius)))
				total_added += add_blood_pixel(Vector2(x, y), mini(pixel_amount, raw_budget - total_added) if raw_budget >= 0 else pixel_amount)
	return total_added

func _stamp_sparse_line(start: Vector2, finish: Vector2, amount: int, density: float) -> void:
	_stamp_sparse_line_budgeted(start, finish, amount, density, -1)

func _stamp_sparse_line_budgeted(start: Vector2, finish: Vector2, amount: int, density: float, raw_budget: int) -> int:
	var total_added := 0
	var distance := start.distance_to(finish)
	var steps := maxi(1, ceili(distance))
	for step in range(steps + 1):
		if raw_budget >= 0 and total_added >= raw_budget: break
		if step > 0 and step < steps and randf() > density: continue
		var point := start.lerp(finish, float(step) / float(steps))
		var pixel_amount := roundi(float(amount) * lerpf(1.0, 0.44, float(step) / float(steps)))
		total_added += add_blood_pixel(point, mini(pixel_amount, raw_budget - total_added) if raw_budget >= 0 else pixel_amount)
	return total_added

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
					if _pool_point_allowed(pool, point): add_blood_pixel(point, roundi(float(pool.amount) * lerpf(1.0, 0.5, normalized_distance)))
		if progress < 1.0: active.append(pool)
	growing_pools = active

func _chunk_coordinate(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(float(cell.x) / float(CHUNK_SIZE)), floori(float(cell.y) / float(CHUNK_SIZE)))

func _local_cell(cell: Vector2i) -> Vector2i:
	return Vector2i(posmod(cell.x, CHUNK_SIZE), posmod(cell.y, CHUNK_SIZE))

func _find_chunk_for_cell(cell: Vector2i) -> PixelBloodChunk:
	var coordinate := _chunk_coordinate(cell)
	var candidate: Variant = chunks.get(coordinate)
	if not is_instance_valid(candidate) or candidate.is_queued_for_deletion(): return null
	return candidate as PixelBloodChunk

func _get_or_create_chunk(coordinate: Vector2i) -> PixelBloodChunk:
	var candidate: Variant = chunks.get(coordinate)
	if is_instance_valid(candidate) and not candidate.is_queued_for_deletion(): return candidate as PixelBloodChunk
	# A new hit can repaint a just-drained cell in the same frame. Never deposit
	# into the retired chunk: queue_free would otherwise discard that fresh blood.
	var chunk := PixelBloodChunk.new()
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

func _build_pool_occlusion(center: Vector2, reach: float) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	result.resize(POOL_OCCLUSION_RAYS)
	if evidence_layer != "ground":
		result.fill(reach)
		return result
	var world := get_tree().get_first_node_in_group("pathfinding_world")
	var space := get_world_2d().direct_space_state
	for index in POOL_OCCLUSION_RAYS:
		var direction := Vector2.RIGHT.rotated(TAU * float(index) / float(POOL_OCCLUSION_RAYS))
		if is_instance_valid(world) and world.has_method("is_navigation_position_walkable"):
			var allowed := reach
			for distance_step in range(1, ceili(reach) + 1):
				if not world.is_navigation_position_walkable(center + direction * float(distance_step)):
					allowed = maxf(0.0, float(distance_step) - 0.8)
					break
			result[index] = allowed
			continue
		var query := PhysicsRayQueryParameters2D.create(center, center + direction * reach, 4)
		query.collide_with_areas = false
		var hit := space.intersect_ray(query)
		result[index] = maxf(0.0, center.distance_to(hit.position) - 0.8) if not hit.is_empty() else reach
	return result

func _pool_point_allowed(pool: Dictionary, point: Vector2) -> bool:
	var center: Vector2 = pool.position
	var offset := point - center
	if offset.length_squared() <= 1.0: return true
	var occlusion: PackedFloat32Array = pool.get("occlusion", PackedFloat32Array())
	if occlusion.size() != POOL_OCCLUSION_RAYS: return not _blocked_by_solid(center, point)
	var ray_position := wrapf(offset.angle(), 0.0, TAU) / TAU * float(POOL_OCCLUSION_RAYS)
	var low := floori(ray_position) % POOL_OCCLUSION_RAYS
	var high := (low + 1) % POOL_OCCLUSION_RAYS
	var allowed := lerpf(occlusion[low], occlusion[high], ray_position - floorf(ray_position))
	return offset.length() <= allowed

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
