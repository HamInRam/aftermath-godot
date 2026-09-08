class_name BloodSystem
extends Node2D

const GORE_CHUNK_SCENE := preload("res://scenes/effects/gore_chunk.tscn")
const PIXEL_BLOOD_CANVAS := preload("res://scripts/effects/pixel_blood_canvas.gd")
const BLOOD_MIST_BATCH := preload("res://scripts/effects/blood_mist_batch.gd")
const GROUND_BLOOD_PRESENTATION_SCALE := 1.25
const AIRBORNE_BLOOD_PRESENTATION_SCALE := 1.78
var violence_scale := 1.0
var ground_canvas: Node2D
var wall_canvas: Node2D
var mist_batch: Node2D

func _ready() -> void:
	mist_batch = BLOOD_MIST_BATCH.new() as Node2D
	mist_batch.name = "BloodMistBatch"
	add_child(mist_batch)
	ground_canvas = PIXEL_BLOOD_CANVAS.new() as Node2D
	ground_canvas.name = "GroundPixelBlood"
	ground_canvas.configure("ground", -2)
	ground_canvas.splash_coverage = 1.8
	add_child(ground_canvas)
	wall_canvas = PIXEL_BLOOD_CANVAS.new() as Node2D
	wall_canvas.name = "WallPixelBlood"
	wall_canvas.configure("wall", 2)
	add_child(wall_canvas)

func emit_hit(hit_position: Vector2, projectile_direction: Vector2, damage: int, weapon_id: String, travel_distance: float, lethal: bool) -> void:
	emit_context(DamageContext.create(hit_position, projectile_direction, damage, weapon_id, travel_distance, lethal, "torso"))

func emit_context(context: DamageContext) -> void:
	var hit_position := context.hit_position
	var projectile_direction := context.direction
	var damage := context.damage
	var weapon_id := context.weapon_id
	var travel_distance := context.travel_distance
	var lethal := context.lethal
	var direction := projectile_direction.normalized()
	var profile := AttackCatalog.get_blood_profile(weapon_id)
	var violence: Dictionary = context.violence_profile if not context.violence_profile.is_empty() else AttackCatalog.get_violence_profile(weapon_id)
	var distance_ratio := clampf(travel_distance / float(profile.range), 0.0, 1.0)
	var distance_force := lerpf(1.18, 0.72, distance_ratio)
	var lethal_force := 1.40 if lethal else 0.88
	var zone_force := 1.42 if context.hit_zone == "head" else (0.82 if context.hit_zone == "limb" else 1.0)
	# Combat health uses a 100-point scale. Gore follows wound severity rather
	# than the raw HP integer so ordinary wounds do not all hit the FX ceiling.
	var wound_damage_scale := clampf(0.65 + context.damage_ratio * 2.2, 0.65, 3.2) if context.damage_ratio > 0.0 else clampf(float(damage), 0.65, 3.2)
	var ballistic_wound := context.penetration_power > 0.0
	var external_scale := context.external_blood_scale if ballistic_wound else 1.0
	var intensity := 0.0
	if ballistic_wound:
		intensity = clampf(float(profile.blood_power) * distance_force * lethal_force * zone_force * maxf(0.52, context.energy_transfer) * external_scale * violence_scale * Settings.blood_density * GROUND_BLOOD_PRESENTATION_SCALE, 0.16, 6.0)
	else:
		intensity = clampf(wound_damage_scale * float(profile.blood_power) * distance_force * lethal_force * zone_force * maxf(0.75, context.energy) * violence_scale * Settings.blood_density * GROUND_BLOOD_PRESENTATION_SCALE, 0.7, 6.0)
	var pattern: String = profile.pattern
	var cone: float = profile.cone
	var weapon_class := AttackCatalog.get_gun_data(weapon_id).weapon_class if AttackCatalog.GUNS.has(weapon_id) else ""
	var stain_radius := context.blood_stain_radius
	if context.weapon_source != null:
		weapon_class = context.weapon_source.weapon_class
	if weapon_class in ["smg", "pdw"]:
		pattern = "dots"
		cone = 0.85
	# A compact dark entry puff is followed by the brighter, faster exit cone.
	# Firearms use the resolved wound channel directly. The older presentation
	# profile remains the fallback for melee/executions, where penetration has no
	# physical meaning.
	var entry_scale := context.entry_wound_scale if ballistic_wound else float(violence.get("entry", 1.0))
	var exit_scale := context.exit_wound_scale if ballistic_wound else float(violence.get("exit", 1.0))
	var mist_scale := context.mist_scale if ballistic_wound else float(violence.get("mist", 1.0))
	# Empowered rounds use a strict raw-mass ledger. Seventy-five percent is
	# available at impact and the remainder is reserved for a lethal death mark.
	# Transient mist is visual-only and can never be siphoned back into reserve.
	var ground_budget := context.blood_budget_raw
	var impact_budget := floori(float(ground_budget) * (0.75 if lethal else 1.0)) if ground_budget >= 0 else -1
	var ground_spent := 0
	# A thin, opaque coating makes a route without multiplying its resource mass.
	# Shotgun fan only on a kill; sniper route only on an actual exiting wound.
	if (weapon_class == "shotgun" and lethal) or (weapon_class == "sniper" and context.projectile_exited):
		ground_spent += ground_canvas.stamp_weapon_footprint(hit_position, direction, weapon_class, impact_budget, stain_radius)
	var mist_deposits := 0 if context.blood_enhanced else int(violence.get("drops", 8))
	_spawn_mist(hit_position - direction * 0.8, -direction, intensity * 0.22 * entry_scale, cone * 0.35, 0 if context.blood_enhanced else maxi(2, mist_deposits / 3))
	ground_spent += _spawn_ground_splatter(hit_position - direction, -direction, intensity * 0.22 * entry_scale, "line", cone * 0.22, str(violence.get("wound", "puncture")), impact_budget - ground_spent if impact_budget >= 0 else -1)
	if not ballistic_wound or context.projectile_exited:
		_spawn_mist(hit_position, direction, intensity * mist_scale, cone, mist_deposits)
		ground_spent += _spawn_ground_splatter(hit_position, direction, intensity * exit_scale, pattern, cone, str(violence.get("wound", "puncture")), impact_budget - ground_spent if impact_budget >= 0 else -1, stain_radius)
		var wall_reach_scale := clampf(0.65 + context.penetration_ratio * 0.18, 0.65, 1.15) if ballistic_wound else 1.0
		ground_spent += _spawn_wall_splatter(hit_position, direction, intensity * exit_scale, float(profile.wall_reach) * wall_reach_scale, pattern, cone, impact_budget - ground_spent if impact_budget >= 0 else -1)
	elif ballistic_wound:
		# A retained round leaves a compact entry wound and later seepage, but no
		# impossible forward exit cone or blood painted on the wall behind it.
		ground_spent += _spawn_ground_splatter(hit_position, -direction, intensity * 0.16, "radial", cone * 0.25, "retained", impact_budget - ground_spent if impact_budget >= 0 else -1)
	if lethal:
		ground_spent += _spawn_ground_splatter(hit_position + direction * 2.0, direction.rotated(randf_range(-0.18, 0.18)), intensity * 0.72 * float(violence.get("pool_bias", 1.0)), pattern, cone * 1.12, str(violence.get("wound", "puncture")), impact_budget - ground_spent if impact_budget >= 0 else -1)
		if Settings.gore_enabled:
			_spawn_gore_chunks(hit_position, direction, intensity * context.gore_force_multiplier, weapon_id, int(violence.get("gore", 3)))
			# The corpse creates exactly the anatomy removed by its resolved pose.
			# A second weapon-count-based emitter produced intact bodies beside extra
			# arms, and its travelling limbs also generated unbudgeted fresh blood.
	if ground_budget >= 0:
		context.blood_budget_spent_raw += ground_spent
		context.blood_budget_raw = maxi(0, ground_budget - ground_spent)

func _spawn_mist(hit_position: Vector2, direction: Vector2, intensity: float, cone: float, deposit_count := 10) -> void:
	if is_instance_valid(mist_batch):
		mist_batch.emit_mist(hit_position, direction, intensity * AIRBORNE_BLOOD_PRESENTATION_SCALE, NeonPalette.BLOOD_FRESH, cone * 1.2, deposit_count)

func spawn_micro_drop(world_position: Vector2, strength := 0.5, direction := Vector2.RIGHT) -> void:
	var surface_profile := {}
	var world := get_tree().get_first_node_in_group("pathfinding_world")
	if is_instance_valid(world) and world.has_method("get_nearest_walkable_position"):
		world_position = world.get_nearest_walkable_position(world_position)
		if world_position == Vector2.INF: return
	if is_instance_valid(world) and world.has_method("get_blood_surface_profile"): surface_profile = world.get_blood_surface_profile(world_position)
	if is_instance_valid(ground_canvas): ground_canvas.deposit_drop(world_position, strength, direction, surface_profile)

func spawn_wound_drop(world_position: Vector2, direction: Vector2, severity: float) -> void:
	# Persistent wounds are painted straight into the sparse one-pixel canvas.
	# This makes a readable trail without allocating one Node per drop.
	var strength := clampf(0.14 + severity * 0.58, 0.16, 1.08)
	spawn_micro_drop(world_position + Vector2(randf_range(-1.2, 1.2), randf_range(-1.2, 1.2)), strength, direction)

func _spawn_ground_splatter(hit_position: Vector2, direction: Vector2, intensity: float, pattern: String, cone: float, wound_kind := "", raw_budget := -1, stain_radius := -1.0) -> int:
	var stain_position := hit_position + direction * randf_range(1.5, 3.0)
	var world := get_tree().get_first_node_in_group("pathfinding_world")
	if is_instance_valid(world) and world.has_method("get_nearest_walkable_position"):
		stain_position = world.get_nearest_walkable_position(stain_position)
		if stain_position == Vector2.INF: return 0
	if is_instance_valid(ground_canvas): return ground_canvas.stamp_splatter(stain_position, direction, intensity, pattern, cone, wound_kind, raw_budget, stain_radius)
	return 0

func _spawn_wall_splatter(hit_position: Vector2, direction: Vector2, intensity: float, reach: float, pattern: String, cone: float, raw_budget := -1) -> int:
	if raw_budget == 0: return 0
	var query := PhysicsRayQueryParameters2D.create(hit_position, hit_position + direction * reach, 4)
	var result := get_world_2d().direct_space_state.intersect_ray(query)
	if result.is_empty(): return 0
	if is_instance_valid(wall_canvas): return wall_canvas.stamp_splatter(result.position - direction * 0.8, -direction, intensity * 0.82, pattern, cone * 0.72, "wall", raw_budget)
	return 0

func spawn_death_burst(world_position: Vector2, intensity := 1.0, wound_offset := Vector2.ZERO, direction := Vector2.RIGHT, attack_id := "pistol", stain_radius := -1.0) -> void:
	# Death adds one final weapon-authored burst, never a timed source. The resolved
	# hit context already supplies penetration, energy, range and entry/exit wound
	# differences; this compact terminal mark replaces the old expanding pool.
	var blood_profile := AttackCatalog.get_blood_profile(attack_id)
	var violence := AttackCatalog.get_violence_profile(attack_id)
	var burst_position := world_position + wound_offset.limit_length(6.0)
	var burst_intensity := clampf(intensity * float(violence.get("pool_bias", 1.0)) * 0.78, 0.55, 2.6)
	_spawn_ground_splatter(burst_position, direction, burst_intensity, str(blood_profile.pattern), float(blood_profile.cone) * 0.82, str(violence.get("wound", "puncture")), -1, stain_radius)

func spawn_death_burst_budgeted(world_position: Vector2, intensity: float, wound_offset: Vector2, direction: Vector2, attack_id: String, raw_budget: int, stain_radius := -1.0) -> int:
	if raw_budget <= 0: return 0
	var blood_profile := AttackCatalog.get_blood_profile(attack_id)
	var violence := AttackCatalog.get_violence_profile(attack_id)
	var burst_position := world_position + wound_offset.limit_length(6.0)
	var burst_intensity := clampf(intensity * float(violence.get("pool_bias", 1.0)) * 0.84, 0.62, 3.2)
	return _spawn_ground_splatter(burst_position, direction, burst_intensity, str(blood_profile.pattern), float(blood_profile.cone), "blast", raw_budget, stain_radius)

func spawn_death_pool(world_position: Vector2, intensity := 1.0, wound_offset := Vector2.ZERO, direction := Vector2.RIGHT, attack_id := "pistol") -> void:
	# Compatibility entry point for authored scenes/tests. Pools no longer grow.
	spawn_death_burst(world_position, intensity, wound_offset, direction, attack_id)

func absorb_pixel_blood(world_position: Vector2, radius: float, power: int, maximum_samples := 48, maximum_total := 255) -> Dictionary:
	var total := 0
	var positions := PackedVector2Array()
	# Wall impacts are visually crimson too, so they must participate in the same
	# blood economy. Reserve a small first pass for them, then spend every unused
	# sample and mass unit on the ground layer where most combat blood lives.
	if is_instance_valid(wall_canvas):
		var wall_result: Dictionary = wall_canvas.absorb_circle(world_position, radius, power, maxi(2, maximum_samples / 4), maxi(1, maximum_total / 4))
		total += int(wall_result.get("amount", 0))
		positions.append_array(wall_result.get("positions", PackedVector2Array()))
	if is_instance_valid(ground_canvas) and total < maximum_total:
		var ground_result: Dictionary = ground_canvas.absorb_circle(world_position, radius, power, maximum_samples, maximum_total - total)
		total += int(ground_result.get("amount", 0))
		positions.append_array(ground_result.get("positions", PackedVector2Array()))
	return {"amount": total, "positions": positions}

func absorb_pixel_blood_cone(world_position: Vector2, direction: Vector2, reach: float, half_angle: float, power: int, maximum_samples := 48, maximum_total := 255) -> Dictionary:
	if not is_instance_valid(ground_canvas): return {"amount": 0, "positions": PackedVector2Array()}
	return ground_canvas.absorb_cone(world_position, direction, reach, half_angle, power, maximum_samples, maximum_total)

func absorb_siphon_sector(origin: Vector2, direction: Vector2, reach: float, half_angle: float, proximity: float, raw_budget: int) -> Dictionary:
	if raw_budget <= 0: return {"amount": 0, "positions": PackedVector2Array()}
	var extent := maxf(maxf(0.0, reach), proximity)
	var occlusion := PackedFloat32Array()
	for index in range(96):
		var ray_direction := Vector2.RIGHT.rotated(TAU * float(index) / 96.0)
		var query := PhysicsRayQueryParameters2D.create(origin, origin + ray_direction * extent, 36)
		query.collide_with_areas = false
		var hit := get_world_2d().direct_space_state.intersect_ray(query)
		occlusion.append(origin.distance_to(hit.position) + 0.6 if not hit.is_empty() else extent)
	var total := 0
	var positions := PackedVector2Array()
	# Reserve a small share for wall stains; unused share returns to the floor.
	if is_instance_valid(wall_canvas):
		var result: Dictionary = wall_canvas.absorb_sector(origin, direction, reach, half_angle, proximity, occlusion, raw_budget / 8)
		total += int(result.amount)
		positions.append_array(result.positions)
	if is_instance_valid(ground_canvas):
		var result: Dictionary = ground_canvas.absorb_sector(origin, direction, reach, half_angle, proximity, occlusion, raw_budget - total)
		total += int(result.amount)
		positions.append_array(result.positions)
	return {"amount": total, "positions": positions}

func _spawn_gore_chunks(hit_position: Vector2, direction: Vector2, intensity: float, attack_id: String, profile_count := 3) -> void:
	var count := clampi(roundi(profile_count * clampf(intensity / 1.5, 0.7, 1.5)), 2, 20)
	for index in range(count):
		var chunk = GORE_CHUNK_SCENE.instantiate()
		chunk.position = to_local(hit_position + Vector2(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0)))
		chunk.setup(direction.rotated(randf_range(-0.65, 0.65)), intensity, index, attack_id)
		RuntimeBudget.try_add("gore", chunk, self)
