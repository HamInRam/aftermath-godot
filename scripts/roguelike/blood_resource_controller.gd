class_name BloodResourceController
extends Node2D

signal resource_changed(current: float, maximum: float, stance_active: bool)
signal skill_triggered(skill_id: String)

const BLOOD_RED := NeonPalette.BLOOD_CRIMSON
const BLOOD_HOT := NeonPalette.BLOOD_CRIMSON
const ABSORB_INTERVAL := 0.04
const RAW_TO_RESOURCE := 0.00055
const SIPHON_PARTICLE_LIFETIME := 0.22
const MAX_SIPHON_MOTES := 96
const PIXELS := preload("res://utility/pixel_art_painter.gd")

var capacity := 100.0
var reserve := 100.0
var overload_active := false
var last_shot_overload := false
var last_shot_blood_cost := 0.0
var pressure_chunks := 0
var pressure_retry := 0.0
var last_absorption_steps := 0

func update_overload(delta: float) -> void:
	var was_active := overload_active
	if reserve > capacity:
		reserve = maxf(capacity, reserve - 8.0 * maxf(0.0, delta))
	if reserve <= capacity: overload_active = false
	if reserve > capacity or overload_active or was_active: queue_redraw()

func accept_siphon(raw_amount: int, drained_chunks: int, interval: float) -> float:
	if overload_active: return 0.0
	pressure_chunks = drained_chunks
	var limit := capacity
	if blood_ammo_mode and stance_active and drained_chunks >= 12: limit = capacity * 1.5
	var gain := minf(absorption_rate_per_second * interval, float(raw_amount) * RAW_TO_RESOURCE * absorption_efficiency)
	var accepted := minf(maxf(0.0,limit-reserve),maxf(0.0,gain))
	reserve += accepted
	if blood_ammo_mode and reserve >= capacity * 1.5 - 0.001: overload_active = true
	return accepted
var absorption_radius := 29.0
var absorption_half_angle := deg_to_rad(45.0)
var absorption_power := 255
var absorption_efficiency := 1.0
var absorption_rate_per_second := 24.0
var ground_drain_raw_per_second := 200000.0
var stance_move_multiplier := 0.80
var build_id := "balanced"
var perks = preload("res://scripts/roguelike/run_combat_perks.gd").new()

func set_build(id: String) -> void:
	if id not in ["balanced", "harvester", "heavy", "mobile"]: return
	build_id = id
	capacity = 70.0 if id == "harvester" else 100.0
	absorption_rate_per_second = (75.0 if id == "harvester" else 60.0) if blood_ammo_mode else (32.0 if id == "harvester" else 24.0)
	stance_move_multiplier = 0.94 if id == "mobile" else 0.80
	enhanced_round_cost = 5.0 if id == "heavy" else 3.5
	enhanced_damage_multiplier = 2.1 if id == "heavy" else (1.35 if id == "mobile" else 1.65)
	enhanced_penetration_bonus = 1.25 if id == "heavy" else 0.85
	reserve = minf(reserve, capacity)
	resource_changed.emit(reserve, capacity, stance_active)
var enhanced_round_cost := 3.5
var enhanced_damage_multiplier := 1.65
var enhanced_penetration_bonus := 0.85
## At most 72% of an empowered round's cost can return as siphonable ground
## blood. Even a perfect recovery therefore has a permanent 28% resource sink.
var enhanced_blood_return_ratio := 0.72
var heal_cost := 22.0
var heal_amount := 34
var stance_active := false
var absorption_clock := 0.0
var siphon_release_remaining := 0.0
var recycled_motes: Array[Dictionary] = []
const SIPHON_RELEASE_GRACE := 0.1
var absorption_lockout := 0.0
var skill_cooldowns := {"q": 0.0, "e": 0.0, "r": 0.0}
var skill_costs := {"q": 18.0, "e": 28.0, "r": 24.0}
var skill_base_cooldowns := {"q": 2.6, "e": 5.0, "r": 7.0}
var particles: Array[Dictionary] = []
var last_emitted_reserve := -1.0
var room_upgrade_count := 0
var enhanced_shot_cache_id := -1
var enhanced_shot_cache := {"enhanced": false, "damage_multiplier": 1.0, "penetration_bonus": 0.0, "blood_cost": 0.0, "blood_return_cap": 0.0, "raw_blood_budget": 0}
var siphon_target_position := Vector2.ZERO
var siphon_direction := Vector2.RIGHT
var siphon_visual_amount := 0.0
var mote_serial := 0
var blood_ammo_mode := false
const SIPHON_REACH := 224.0
const SIPHON_PROXIMITY := 48.0

func pay_for_shot(data: GunData) -> bool:
	last_shot_overload = false
	last_shot_blood_cost = 0.0
	if data == null: return false
	var cost := maxf(0.1, data.caliber_blood_cost)
	if overload_active and reserve > capacity:
		last_shot_overload = true
		last_shot_blood_cost = minf(cost, reserve-capacity)
		reserve = maxf(capacity,reserve-cost)
		if reserve <= capacity: overload_active = false
		_emit_if_changed()
		return true
	if reserve + 0.0001 < cost: return false
	reserve = maxf(0.0, reserve - cost)
	last_shot_blood_cost = cost
	_emit_if_changed()
	return true

func _ready() -> void:
	for index in range(MAX_SIPHON_MOTES):
		recycled_motes.append({"origin": Vector2.ZERO, "position": Vector2.ZERO, "age": 0.0, "life": 0.0, "duration": 0.0, "curve": 0.0})
	z_index = 12
	z_as_relative = false
	resource_changed.emit(reserve, capacity, stance_active)

func update_system(delta: float, player: Node2D, blood_system: Node) -> void:
	last_absorption_steps = 0
	pressure_retry = maxf(0.0,pressure_retry-delta)
	update_overload(delta)
	perks.update(delta)
	for key in skill_cooldowns:
		skill_cooldowns[key] = maxf(0.0, float(skill_cooldowns[key]) - delta)
	absorption_lockout = maxf(0.0, absorption_lockout - delta)
	siphon_visual_amount = move_toward(siphon_visual_amount, 0.0, delta * 7.5)
	if is_instance_valid(player): siphon_target_position = player.global_position
	_update_particles(delta, player)
	if (not stance_active and siphon_release_remaining <= 0.0) or absorption_lockout > 0.0 or not is_instance_valid(player) or not is_instance_valid(blood_system):
		absorption_clock = 0.0
		siphon_release_remaining = 0.0
		_emit_if_changed()
		return
	var absorb_delta := delta if stance_active else minf(delta, siphon_release_remaining)
	if reserve >= capacity and pressure_retry > 0.0:
		absorption_clock = 0.0
		_emit_if_changed()
		return
	siphon_release_remaining = maxf(0.0, siphon_release_remaining - delta)
	# At most two simulation slices per rendered frame; do not bank a stall.
	absorption_clock = minf(ABSORB_INTERVAL*2.0, absorption_clock + absorb_delta)
	while absorption_clock >= ABSORB_INTERVAL:
		last_absorption_steps += 1
		absorption_clock -= ABSORB_INTERVAL
		if overload_active or reserve >= (capacity * 1.5 if blood_ammo_mode else capacity) - 0.001:
			absorption_clock = 0.0
			break
		var raw_budget := maxi(1, ceili(ground_drain_raw_per_second * ABSORB_INTERVAL))
		siphon_direction = _resolve_siphon_direction(player)
		var result: Dictionary
		if blood_ammo_mode:
			if reserve >= capacity:
				result = blood_system.absorb_siphon_sector(player.global_position, siphon_direction, SIPHON_REACH, absorption_half_angle, SIPHON_PROXIMITY, raw_budget, 12)
			else:
				result = blood_system.absorb_siphon_sector(player.global_position, siphon_direction, SIPHON_REACH, absorption_half_angle, SIPHON_PROXIMITY, raw_budget)
		else:
			result = blood_system.absorb_pixel_blood(player.global_position, absorption_radius, absorption_power, 40, raw_budget)
		var raw_amount := int(result.get("amount", 0))
		if raw_amount <= 0:
			if reserve >= capacity: pressure_retry = 0.12
			absorption_clock = 0.0
			break
		perks.on_siphon()
		accept_siphon(raw_amount, int(result.get("pressure_chunks",0)), ABSORB_INTERVAL)
		siphon_visual_amount = 1.0
		var sources: PackedVector2Array = result.get("positions", PackedVector2Array())
		_spawn_siphon_motes(sources)
	_emit_if_changed()

func _spawn_siphon_motes(sources: PackedVector2Array) -> void:
	# Only real removed pixels may become visual motes. No new resources or nodes.
	var count := mini(16, mini(sources.size(), MAX_SIPHON_MOTES - particles.size()))
	for index in range(count):
		var source := sources[index * sources.size() / count]
		var delay := float(index % 4) * 0.006
		var curve := (4.0 + float(mote_serial % 6)) * (-1.0 if mote_serial % 2 == 0 else 1.0)
		var duration := siphon_duration(source.distance_to(siphon_target_position)) if blood_ammo_mode else SIPHON_PARTICLE_LIFETIME
		var mote: Dictionary = recycled_motes.pop_back() if not recycled_motes.is_empty() else {}
		mote.origin = source
		mote.position = source
		mote.age = -delay
		mote.life = duration + delay
		mote.duration = duration
		mote.curve = curve
		particles.append(mote)
		mote_serial += 1
	if count > 0: queue_redraw()

static func siphon_path(origin: Vector2, target: Vector2, progress: float, curve: float) -> Vector2:
	var t := clampf(progress, 0.0, 1.0)
	var travel := target - origin
	var side := travel.normalized().orthogonal() if travel.length_squared() > 0.01 else Vector2.UP
	# Accelerating pull with an outward bow; both endpoints are exact.
	return origin.lerp(target, t * t) + side * sin(t * PI) * minf(absf(curve), travel.length() * 0.4) * signf(curve)

static func siphon_duration(distance: float) -> float:
	return lerpf(0.075, 0.48, pow(clampf(distance / SIPHON_REACH, 0.0, 1.0), 1.35))

func set_stance_active(active: bool, allow_release_grace := false) -> void:
	if not active and not allow_release_grace:
		siphon_release_remaining = 0.0
		absorption_clock = 0.0
	if stance_active == active: return
	siphon_release_remaining = SIPHON_RELEASE_GRACE if not active and allow_release_grace and blood_ammo_mode else 0.0
	stance_active = active
	if siphon_release_remaining <= 0.0: absorption_clock = 0.0
	resource_changed.emit(reserve, capacity, stance_active)
	queue_redraw()

func consume_enhanced_round(shot_id := -1, last_round := false) -> Dictionary:
	if shot_id >= 0 and shot_id == enhanced_shot_cache_id: return enhanced_shot_cache
	if not stance_active or reserve + 0.001 < enhanced_round_cost:
		enhanced_shot_cache_id = shot_id
		enhanced_shot_cache = {"enhanced": false, "damage_multiplier": 1.0, "penetration_bonus": 0.0, "blood_cost": 0.0, "blood_return_cap": 0.0, "raw_blood_budget": 0}
		return enhanced_shot_cache
	var paid_cost := enhanced_round_cost
	reserve -= paid_cost
	resource_changed.emit(reserve, capacity, stance_active)
	enhanced_shot_cache_id = shot_id
	var return_cap := paid_cost * clampf(enhanced_blood_return_ratio, 0.0, 0.95)
	enhanced_shot_cache = {
		"enhanced": true,
		"damage_multiplier": enhanced_damage_multiplier,
		"penetration_bonus": enhanced_penetration_bonus,
		"blood_cost": paid_cost,
		"blood_return_cap": return_cap,
		"raw_blood_budget": floori(return_cap / RAW_TO_RESOURCE),
	}
	perks.enhance(enhanced_shot_cache, last_round)
	return enhanced_shot_cache

func request_skill(skill_id: String) -> bool:
	if blood_ammo_mode: return false
	var id := skill_id.to_lower()
	if not skill_costs.has(id) or float(skill_cooldowns.get(id, 0.0)) > 0.0: return false
	var cost := float(skill_costs[id])
	if reserve + 0.001 < cost: return false
	reserve -= cost
	absorption_lockout = 0.65
	skill_cooldowns[id] = float(skill_base_cooldowns[id])
	resource_changed.emit(reserve, capacity, stance_active)
	skill_triggered.emit(id)
	return true

func consume_heal(player: Node) -> bool:
	if blood_ammo_mode: return false
	if reserve + 0.001 < heal_cost or not is_instance_valid(player): return false
	if int(player.get("hp")) >= int(player.get("max_hp")): return false
	var healed := int(player.heal(heal_amount)) if player.has_method("heal") else 0
	if healed <= 0: return false
	reserve -= heal_cost
	absorption_lockout = 0.40
	resource_changed.emit(reserve, capacity, stance_active)
	return true

func get_cooldown_ratios() -> Dictionary:
	var result := {}
	for key in skill_cooldowns:
		result[key] = float(skill_cooldowns[key]) / maxf(0.001, float(skill_base_cooldowns[key]))
	return result

func get_movement_multiplier() -> float:
	if blood_ammo_mode: return 1.0
	if perks.harvest_time > 0.0: return 1.0
	return stance_move_multiplier if stance_active else 1.0

func get_resource_ratio() -> float:
	return clampf(reserve / maxf(1.0, capacity), 0.0, 1.0)

func get_siphon_visual_amount() -> float:
	return siphon_visual_amount

func _resolve_siphon_direction(player: Node2D) -> Vector2:
	var aim_point: Vector2 = player.get_aim_world_position() if player.has_method("get_aim_world_position") else player.global_position + Vector2.RIGHT.rotated(player.global_rotation)
	var direction := player.global_position.direction_to(aim_point)
	return direction if direction.length_squared() > 0.001 else Vector2.RIGHT.rotated(player.global_rotation)

func get_skill_cost(skill_id: String) -> float:
	return float(skill_costs.get(skill_id.to_lower(), 0.0))

func apply_upgrade(upgrade_id: String) -> void:
	room_upgrade_count += 1
	match upgrade_id:
		"reservoir":
			capacity += 24.0
			reserve = minf(capacity, reserve + 24.0)
		"siphon":
			absorption_radius += 5.0
			absorption_efficiency *= 1.10
			absorption_rate_per_second *= 1.12
		"ballistics":
			enhanced_damage_multiplier += 0.12
			enhanced_round_cost = maxf(2.0, enhanced_round_cost - 0.2)
		"mobility":
			stance_move_multiplier = minf(0.82, stance_move_multiplier + 0.07)
		"vitality":
			heal_amount += 10
			heal_cost = maxf(12.0, heal_cost - 2.0)
		"ritual":
			for key in skill_base_cooldowns: skill_base_cooldowns[key] = float(skill_base_cooldowns[key]) * 0.88
	resource_changed.emit(reserve, capacity, stance_active)

func _update_particles(delta: float, player: Node2D) -> void:
	if particles.is_empty(): return
	if not is_instance_valid(player):
		particles.clear()
		queue_redraw()
		return
	for index in range(particles.size() - 1, -1, -1):
		var particle := particles[index]
		particle.age = float(particle.age) + delta
		particle.life = float(particle.life) - delta
		if float(particle.life) <= 0.0:
			if recycled_motes.size() < MAX_SIPHON_MOTES: recycled_motes.append(particle)
			particles.remove_at(index)
			continue
		if float(particle.age) >= 0.0 and is_instance_valid(player):
			var origin: Vector2 = particle.origin
			var target := player.global_position
			var progress := clampf(float(particle.age) / float(particle.get("duration", SIPHON_PARTICLE_LIFETIME)), 0.0, 1.0)
			particle.position = siphon_path(origin, target, progress, float(particle.curve))
	queue_redraw()

func _emit_if_changed() -> void:
	if absf(reserve - last_emitted_reserve) < 0.04: return
	last_emitted_reserve = reserve
	resource_changed.emit(reserve, capacity, stance_active)

func _draw() -> void:
	if overload_active:
		for side in [-1,1]:
			for step in range(5):
				PIXELS.pixel(self, Vector2(side*7,step-2), BLOOD_RED)
	for particle in particles:
		if float(particle.age) < 0.0: continue
		var progress := clampf(float(particle.age) / float(particle.get("duration", SIPHON_PARTICLE_LIFETIME)), 0.0, 1.0)
		# Sample a short curved tail independent of frame delta. Opaque crimson
		# stays readable over gray floors; never draw a source-to-player beam.
		for tail_index in range(3):
			var t := maxf(0.0, progress - float(tail_index) * 0.035)
			var point := siphon_path(particle.origin, siphon_target_position, t, float(particle.curve))
			PIXELS.pixel(self, to_local(point).round(), BLOOD_RED)
