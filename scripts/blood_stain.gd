extends Node2D

const SPLAT_STREAM := preload("res://assets/audio/sfx/blood_splat.wav")

var amount := 1.0
var lobes: Array[Dictionary] = []
var streaks: Array[Dictionary] = []
var configured := false
var wall_stain := false
var base_intensity := 1.0
var pattern_id := "fan"
var initial_detail_count := 1
var stain_age := 0.0
var drip_time := 0.0
var drip_budget := 0
var wound_kind := ""
var surface_kind := "concrete"
var surface_darken := 0.0
var surface_absorption := 1.0
var surface_applied := false
var ultraviolet_residue := false
var ultraviolet_visible := false

func _ready() -> void:
	CleanupRegistry.register_target(self)
	if not configured:
		setup(Vector2.RIGHT.rotated(randf_range(0.0, TAU)), 1.0, false, false)
	if not wall_stain: add_to_group("blood_source")
	set_process(true)
	call_deferred("_apply_surface_profile")
	call_deferred("_clip_to_geometry")

func _apply_surface_profile() -> void:
	if wall_stain or surface_applied or not is_inside_tree(): return
	var world := get_tree().get_first_node_in_group("pathfinding_world")
	if not is_instance_valid(world) or not world.has_method("get_blood_surface_profile"): return
	var profile: Dictionary = world.get_blood_surface_profile(global_position)
	surface_kind = str(profile.get("kind", "concrete"))
	var spread := clampf(float(profile.get("spread", 1.0)), 0.65, 1.55)
	surface_darken = float(profile.get("darken", 0.0))
	surface_absorption = float(profile.get("absorption", 1.0))
	for lobe in lobes:
		lobe.position = (lobe.position as Vector2) * spread
		if surface_kind == "carpet": lobe.radius = float(lobe.radius) * 0.82
	for streak in streaks:
		streak.start = (streak.start as Vector2) * spread
		streak.end = (streak.end as Vector2) * spread
	surface_applied = true
	queue_redraw()

func _clip_to_geometry() -> void:
	if wall_stain or not is_inside_tree(): return
	var space := get_world_2d().direct_space_state
	for lobe in lobes:
		var hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(global_position, to_global(lobe.position as Vector2), 4))
		if not hit.is_empty(): lobe.position = to_local(hit.position) - (lobe.position as Vector2).normalized() * 0.8
	for streak in streaks:
		var hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(global_position, to_global(streak.end as Vector2), 4))
		if not hit.is_empty(): streak.end = to_local(hit.position) - (streak.end as Vector2).normalized() * 0.8
	queue_redraw()

func setup(spray_direction: Vector2, intensity: float, on_wall: bool, play_splat := false, pattern := "fan", cone := 0.72, new_wound_kind := "") -> void:
	configured = true
	# Reconfiguration must replace the previous geometry rather than mixing two
	# blood patterns (notably when a node has already entered the scene tree).
	lobes.clear()
	streaks.clear()
	wall_stain = on_wall
	if wall_stain:
		remove_from_group("blood_clue")
		remove_from_group("blood_source")
	base_intensity = clampf(intensity, 0.5, 2.8)
	pattern_id = pattern
	wound_kind = new_wound_kind
	add_to_group("blood_splatter_stain")
	var direction := spray_direction.normalized()
	rotation = direction.angle()
	var lobe_count := clampi(roundi(9.0 + base_intensity * 7.0), 10, 28)
	for i in range(lobe_count):
		var position := Vector2.ZERO
		if pattern_id == "radial":
			var radial_angle := randf_range(-cone, cone)
			position = Vector2.RIGHT.rotated(radial_angle) * pow(randf(), 0.48) * (14.0 + base_intensity * 10.0)
		elif pattern_id == "line":
			# Low-resolution gunshot trails read better as a broken droplet chain.
			# The old 18–46 px rays became 54–138 screen pixels at 3x scaling.
			position = Vector2(pow(randf(), 0.58) * (10.0 + base_intensity * 5.0), randfn(0.0, 0.8 + cone * 1.5))
		else:
			var fan_angle := randf_range(-cone, cone)
			position = Vector2.RIGHT.rotated(fan_angle) * pow(randf(), 0.58) * (11.0 + base_intensity * 9.0)
		if wall_stain: position.y *= 0.55
		var radius := randf_range(0.45, 1.45) * lerpf(0.75, 1.35, base_intensity / 2.8)
		lobes.append({"position": position, "radius": radius, "dark": i % 5 == 0})
		if i % 3 == 0:
			var streak_start: Vector2 = position * randf_range(0.15, 0.5)
			if pattern_id == "line":
				streak_start = position - Vector2.RIGHT * randf_range(2.0, 5.5)
			streaks.append({"start": streak_start, "end": position, "width": maxf(0.4, radius * 0.55)})
	initial_detail_count = maxi(1, lobes.size() + streaks.size())
	drip_budget = clampi(roundi(base_intensity * 2.2), 1, 8) if wall_stain else 0
	drip_time = randf_range(0.18, 0.42)
	if play_splat:
		$SplatAudio.stream = SPLAT_STREAM
		$SplatAudio.pitch_scale = randf_range(0.88, 1.08)
		$SplatAudio.volume_db = lerpf(-13.0, -7.0, clampf(base_intensity / 2.8, 0.0, 1.0))
		if is_inside_tree(): _play_splat()
		else: call_deferred("_play_splat")
	queue_redraw()

func absorb_splatter(direction: Vector2, intensity: float, pattern: String, cone: float, new_wound_kind := "") -> void:
	var local_direction := direction.rotated(-rotation)
	var added := clampi(roundi(3.0 + intensity * 2.0), 2, 8)
	for index in added:
		var angle := local_direction.angle() + randf_range(-cone, cone)
		var maximum_distance := minf(24.0, 10.0 + intensity * 5.0) if pattern == "line" else 12.0 + intensity * 5.0
		var position := Vector2.RIGHT.rotated(angle) * randf_range(4.0, maximum_distance)
		lobes.append({"position": position, "radius": randf_range(0.45, 1.3), "dark": index % 4 == 0})
		if index % 2 == 0:
			var streak_start := position - position.normalized() * randf_range(2.0, 5.5) if pattern == "line" else position * 0.35
			streaks.append({"start": streak_start, "end": position, "width": 0.55})
	initial_detail_count = maxi(initial_detail_count, lobes.size() + streaks.size())
	base_intensity = maxf(base_intensity, intensity)
	if not new_wound_kind.is_empty(): wound_kind = new_wound_kind
	queue_redraw()

func _process(delta: float) -> void:
	stain_age += delta
	if not wall_stain:
		if stain_age >= 45.0: set_process(false)
		queue_redraw()
		return
	if drip_budget <= 0:
		set_process(false)
		return
	drip_time -= delta
	if drip_time > 0.0: return
	drip_time = randf_range(0.22, 0.48)
	drip_budget -= 1
	var origin := Vector2(randf_range(-2.5, 4.5), randf_range(-1.0, 3.0))
	var length := randf_range(3.0, 8.0) * clampf(base_intensity, 0.7, 2.6)
	streaks.append({"start": origin, "end": origin + Vector2(randf_range(-0.8, 0.8), length), "width": randf_range(0.45, 1.15)})
	initial_detail_count += 1
	queue_redraw()

func _play_splat() -> void:
	if not is_inside_tree() or DisplayServer.get_name() == "headless": return
	$SplatAudio.play()

func clean_step() -> void:
	amount -= 0.12
	if amount <= 0.02:
		lobes.clear()
		streaks.clear()
		_become_ultraviolet_residue()
	else: queue_redraw()

func clean_at(world_position: Vector2, power := 1) -> bool:
	var local_point := to_local(world_position)
	var removed := 0
	var nearest_lobe_index := -1
	var nearest_lobe_distance := INF
	for index in range(lobes.size() - 1, -1, -1):
		if removed >= power: break
		var lobe: Dictionary = lobes[index]
		var lobe_distance := (lobe.position as Vector2).distance_to(local_point)
		if lobe_distance < nearest_lobe_distance:
			nearest_lobe_distance = lobe_distance
			nearest_lobe_index = index
		if lobe_distance <= 14.0:
			lobes.remove_at(index)
			removed += 1
	for index in range(streaks.size() - 1, -1, -1):
		if removed >= power: break
		var streak: Dictionary = streaks[index]
		if Geometry2D.get_closest_point_to_segment(local_point, streak.start, streak.end).distance_to(local_point) <= 10.0:
			streaks.remove_at(index)
			removed += 1
	# Smart-stroke fallback: once the stain node is selected, a moving mop always
	# removes the nearest remaining detail instead of demanding pixel-perfect aim.
	if removed <= 0 and nearest_lobe_index >= 0 and nearest_lobe_index < lobes.size():
		lobes.remove_at(nearest_lobe_index)
		removed = 1
	elif removed <= 0 and not streaks.is_empty():
		streaks.pop_back()
		removed = 1
	amount = clampf(float(lobes.size() + streaks.size()) / float(initial_detail_count), 0.0, 1.0)
	if lobes.is_empty() and streaks.is_empty():
		_become_ultraviolet_residue()
	else: queue_redraw()
	return true

func clean_stroke(world_position: Vector2, stroke_direction: Vector2, power: int, tool_name: String) -> bool:
	var cleaned := clean_at(world_position, power)
	if ultraviolet_residue and tool_name == "pressure_washer":
		queue_free()
		return cleaned
	if not cleaned or ultraviolet_residue: return cleaned
	var local_push := stroke_direction.rotated(-global_rotation).normalized() * 0.7
	var local_contact := to_local(world_position)
	for lobe in lobes:
		if (lobe.position as Vector2).distance_to(local_contact) <= 18.0: lobe.position = (lobe.position as Vector2) + local_push
	queue_redraw()
	return cleaned

func _become_ultraviolet_residue() -> void:
	remove_from_group("blood_source")
	remove_from_group("blood_clue")
	ultraviolet_residue = true
	amount = 0.0
	set_process(false)
	queue_redraw()

func set_ultraviolet_visible(enabled: bool) -> void:
	ultraviolet_visible = enabled
	queue_redraw()

func is_ultraviolet_residue() -> bool:
	return ultraviolet_residue

func get_cleanup_type() -> String:
	return "blood"

func get_cleanup_cost() -> int:
	return 9

func get_cleanup_progress() -> float:
	return 1.0 - clampf(amount, 0.0, 1.0)

func _draw() -> void:
	if ultraviolet_residue:
		if ultraviolet_visible:
			draw_circle(Vector2.ZERO, 4.0, Color(0.20, 1.0, 0.46, 0.34))
			draw_arc(Vector2.ZERO, 6.0, 0.0, TAU, 12, Color(0.45, 1.0, 0.72, 0.22), 1.0)
		return
	var dilution := 1.0 - amount
	var coagulation := floorf(clampf(stain_age / maxf(8.0, 18.0 / surface_absorption), 0.0, 0.99) * 4.0) / 3.0
	var fresh_blood := Color(0.78, 0.008, 0.045, 0.9).lerp(Color(0.32, 0.006, 0.018, 0.94), coagulation)
	var fresh_dark := Color(0.30, 0.002, 0.012, 0.94).lerp(Color(0.12, 0.002, 0.008, 0.96), coagulation)
	var blood := fresh_blood.lerp(Color(0.92, 0.38, 0.44, 0.24), dilution).darkened(surface_darken)
	var dark := fresh_dark.lerp(Color(0.64, 0.16, 0.2, 0.2), dilution).darkened(surface_darken)
	blood.a *= clampf(amount * 1.35, 0.08, 1.0)
	dark.a *= clampf(amount * 1.35, 0.08, 1.0)
	for streak in streaks:
		draw_line(streak.start, streak.end, dark, maxf(0.35, streak.width))
	for lobe in lobes:
		draw_circle(lobe.position, maxf(0.35, lobe.radius), dark if lobe.dark else blood)
		if surface_kind == "tile" and stain_age < 8.0: draw_circle((lobe.position as Vector2) + Vector2(-0.5, -0.5), 0.35, Color(1, 0.5, 0.58, 0.3 * amount))
	var core_radius := (3.2 if wall_stain else 4.6) * minf(1.35, base_intensity)
	if wound_kind in ["slash", "dismember"]:
		draw_line(Vector2(-core_radius, -1), Vector2(core_radius, 1), dark, 1.5)
	elif wound_kind in ["blast", "torn"]:
		draw_circle(Vector2.ZERO, core_radius * 1.25, dark)
		draw_rect(Rect2(-core_radius, -1, core_radius * 2.0, 2), blood)
	elif wound_kind in ["crush", "execution"]:
		draw_circle(Vector2.ZERO, core_radius * 1.15, dark)
		draw_circle(Vector2(2, -1), core_radius * 0.65, blood)
	elif wound_kind == "drag":
		draw_line(Vector2(-core_radius * 1.4, -1.2), Vector2(core_radius * 1.5, 0.8), dark, 2.5)
		draw_line(Vector2(-core_radius, 1.8), Vector2(core_radius * 1.2, 2.6), blood, 1.0)
	else:
		draw_circle(Vector2.ZERO, core_radius, blood)
	if not wall_stain and amount > 0.7:
		draw_line(Vector2(-2, -1), Vector2(2, -1), Color(1.0, 0.34, 0.45, 0.28 * amount), 1.0)
	if surface_kind == "wood": draw_line(Vector2(-5, 2), Vector2(7, 2), dark, 0.6)
