extends Node2D

const PIXEL_PAINTER := preload("res://utility/pixel_art_painter.gd")

var growth := 0.08
var target_scale := 1.0
var growth_duration := 5.5
var amount := 1.0
var lobes: Array[Dictionary] = []
var initial_lobe_count := 1
var flow_direction := Vector2.RIGHT
var surface_spread := 1.0
var surface_darken := 0.0
var negative_space := Vector2(8, 3)
var groove_lines: Array[Dictionary] = []
var stain_age := 0.0
var surface_kind := "concrete"
var ultraviolet_residue := false
var ultraviolet_visible := false

func _ready() -> void:
	CleanupRegistry.register_target(self)
	add_to_group("blood_source")
	call_deferred("_clip_lobes_to_geometry")

func _clip_lobes_to_geometry() -> void:
	if not is_inside_tree(): return
	var space := get_world_2d().direct_space_state
	var retained: Array[Dictionary] = []
	for lobe in lobes:
		var endpoint := global_position + (lobe.position as Vector2)
		var query := PhysicsRayQueryParameters2D.create(global_position, endpoint, 4)
		query.collide_with_areas = false
		if space.intersect_ray(query).is_empty(): retained.append(lobe)
	if not retained.is_empty(): lobes = retained
	queue_redraw()

func setup(intensity: float, direction := Vector2.RIGHT, surface_profile := {}, violence_profile := {}) -> void:
	flow_direction = direction.normalized() if direction.length_squared() > 0.01 else Vector2.RIGHT
	surface_spread = float(surface_profile.get("spread", 1.0))
	surface_darken = float(surface_profile.get("darken", 0.0))
	surface_kind = str(surface_profile.get("kind", "concrete"))
	var pool_bias := float(violence_profile.get("pool_bias", 1.0))
	target_scale = lerpf(0.82, 1.42, clampf((intensity - 0.7) / 1.5, 0.0, 1.0)) * pool_bias * clampf(surface_spread, 0.8, 1.55)
	growth_duration = lerpf(7.5, 4.2, clampf(intensity / 2.2, 0.0, 1.0))
	var lobe_count := clampi(roundi(12.0 + intensity * 5.0), 14, 24)
	for index in range(lobe_count):
		var angle := randf_range(0.0, TAU)
		var directional_weight := maxf(0.45, Vector2.RIGHT.rotated(angle).dot(flow_direction) * 0.55 + 1.0)
		var distance := randf_range(1.0, 8.5) * target_scale * directional_weight
		lobes.append({
			"position": Vector2.RIGHT.rotated(angle) * distance,
			"radius": randf_range(1.4, 4.2) * target_scale,
			"dark": index % 4 == 0,
		})
	for index in clampi(roundi(surface_spread * 3.0), 2, 6):
		var start := flow_direction.rotated(randf_range(-0.35, 0.35)) * randf_range(2.0, 5.0)
		groove_lines.append({"start": start, "end": start + flow_direction.rotated(randf_range(-0.18, 0.18)) * randf_range(6.0, 14.0) * surface_spread})
	initial_lobe_count = maxi(1, lobes.size())
	queue_redraw()

func _process(delta: float) -> void:
	stain_age += delta
	if growth < 1.0:
		growth = move_toward(growth, 1.0, 1.0 / growth_duration * delta)
		queue_redraw()
	elif stain_age >= 45.0:
		set_process(false)

func clean_step() -> void:
	amount -= 0.1
	if amount <= 0.02:
		lobes.clear()
		_become_ultraviolet_residue()
	else: queue_redraw()

func clean_at(world_position: Vector2, power := 1) -> bool:
	var local_point := to_local(world_position)
	var removed := 0
	var nearest_index := -1
	var nearest_distance := INF
	for index in range(lobes.size() - 1, -1, -1):
		if removed >= power: break
		var lobe: Dictionary = lobes[index]
		var distance := (lobe.position as Vector2).distance_to(local_point)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = index
		if distance <= 16.0:
			lobes.remove_at(index)
			removed += 1
	if removed <= 0 and nearest_index >= 0 and nearest_index < lobes.size():
		lobes.remove_at(nearest_index)
		removed = 1
	if removed <= 0: return false
	amount = clampf(float(lobes.size()) / float(initial_lobe_count), 0.0, 1.0)
	if lobes.is_empty():
		_become_ultraviolet_residue()
	else: queue_redraw()
	return true

func clean_stroke(world_position: Vector2, stroke_direction: Vector2, power: int, tool_name: String) -> bool:
	var cleaned := clean_at(world_position, power)
	if ultraviolet_residue and tool_name == "pressure_washer":
		queue_free()
		return cleaned
	if not cleaned or ultraviolet_residue: return cleaned
	var local_push := stroke_direction.rotated(-global_rotation).normalized() * 0.55
	var contact := to_local(world_position)
	for lobe in lobes:
		if (lobe.position as Vector2).distance_to(contact) <= 18.0: lobe.position = (lobe.position as Vector2) + local_push
	queue_redraw()
	return cleaned

func _become_ultraviolet_residue() -> void:
	remove_from_group("blood_source")
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
	return 10

func get_cleanup_progress() -> float:
	return 1.0 - clampf(amount, 0.0, 1.0)

func _draw() -> void:
	if ultraviolet_residue:
		if ultraviolet_visible:
			PIXEL_PAINTER.material_circle(self, Vector2.ZERO, 7, Color(0.20, 1.0, 0.46, 0.16), Color(0.45, 1.0, 0.72, 0.25), Color(0.08, 0.38, 0.2, 0.18), 41)
			PIXEL_PAINTER.circle(self, Vector2.ZERO, 10, Color(0.45, 1.0, 0.72, 0.18), true)
		return
	var age_step := floorf(clampf(stain_age / 24.0, 0.0, 0.99) * 4.0) / 3.0
	var blood := Color(0.58, 0.006, 0.035, 0.88 * amount).lerp(Color(0.26, 0.002, 0.012, 0.92 * amount), age_step).darkened(surface_darken)
	var dark := Color(0.19, 0.002, 0.01, 0.94 * amount).darkened(surface_darken)
	for lobe in lobes:
		var center: Vector2 = ((lobe.position as Vector2) * growth).round()
		var color: Color = dark if lobe.dark else blood
		PIXEL_PAINTER.material_circle(self, center, maxi(1, roundi(float(lobe.radius) * growth)), color, color.lightened(0.1), color.darkened(0.2), roundi(center.x) * 17 + roundi(center.y) * 11)
	for groove in groove_lines:
		PIXEL_PAINTER.line(self, groove.start * growth, groove.end * growth, dark)
	if surface_kind == "wood": PIXEL_PAINTER.line(self, Vector2(-8, 3), Vector2(10, 3), dark)
	PIXEL_PAINTER.material_circle(self, Vector2.ZERO, maxi(1, roundi(5.2 * growth * target_scale)), blood, blood.lightened(0.1), dark, 47)
	# The corpse masks this dark negative shape while present; once dragged away it
	# remains as a readable record of where the body originally rested.
	PIXEL_PAINTER.stipple_rect(self, Rect2((-negative_space * 0.5).round(), negative_space.round()), Color(0.10, 0.002, 0.008, 0.38 * amount), 53, 2)
	if growth > 0.65: PIXEL_PAINTER.line(self, Vector2(-3, -2), Vector2(3, -2), Color(0.95, 0.16, 0.28, 0.22 * amount))
