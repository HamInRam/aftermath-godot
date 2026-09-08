class_name BloodResourceController
extends Node2D

signal resource_changed(current: float, maximum: float, stance_active: bool)
signal skill_triggered(skill_id: String)

const BLOOD_RED := NeonPalette.BLOOD_CRIMSON
const BLOOD_HOT := NeonPalette.BLOOD_CRIMSON
const ABSORB_INTERVAL := 0.04
const RAW_TO_RESOURCE := 0.00055
const SIPHON_PARTICLE_LIFETIME := 0.34
const MAX_SIPHON_MOTES := 18
const PIXELS := preload("res://utility/pixel_art_painter.gd")

var capacity := 100.0
var reserve := 24.0
var absorption_radius := 29.0
var absorption_half_angle := deg_to_rad(43.0)
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
	absorption_rate_per_second = 32.0 if id == "harvester" else 24.0
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

func _ready() -> void:
	z_index = 12
	z_as_relative = false
	resource_changed.emit(reserve, capacity, stance_active)

func update_system(delta: float, player: Node2D, blood_system: Node) -> void:
	perks.update(delta)
	for key in skill_cooldowns:
		skill_cooldowns[key] = maxf(0.0, float(skill_cooldowns[key]) - delta)
	absorption_lockout = maxf(0.0, absorption_lockout - delta)
	siphon_visual_amount = move_toward(siphon_visual_amount, 0.0, delta * 7.5)
	if is_instance_valid(player): siphon_target_position = player.global_position
	_update_particles(delta, player)
	if not stance_active or absorption_lockout > 0.0 or not is_instance_valid(player) or not is_instance_valid(blood_system):
		_emit_if_changed()
		return
	absorption_clock += delta
	while absorption_clock >= ABSORB_INTERVAL:
		absorption_clock -= ABSORB_INTERVAL
		if reserve >= capacity - 0.001: break
		var resource_budget := minf(absorption_rate_per_second * ABSORB_INTERVAL, capacity - reserve)
		var raw_budget := maxi(1, ceili(ground_drain_raw_per_second * ABSORB_INTERVAL))
		siphon_direction = _resolve_siphon_direction(player)
		var result: Dictionary = blood_system.absorb_pixel_blood(player.global_position, absorption_radius, absorption_power, 40, raw_budget)
		var raw_amount := int(result.get("amount", 0))
		if raw_amount <= 0: break
		perks.on_siphon()
		var resource_gain := minf(resource_budget, float(raw_amount) * RAW_TO_RESOURCE * absorption_efficiency)
		reserve = minf(capacity, reserve + resource_gain)
		siphon_visual_amount = 1.0
		var sources: PackedVector2Array = result.get("positions", PackedVector2Array())
		# Several staggered one-pixel droplets peel from the stain. They travel as
		# short curved packets; no ray is ever drawn straight into the actor.
		if not sources.is_empty():
			var spawn_count := mini(5, mini(sources.size(), MAX_SIPHON_MOTES - particles.size()))
			for source_index in range(spawn_count):
				var source: Vector2 = sources[posmod(source_index * 3 + particles.size(), sources.size())]
				particles.append({
					"origin": source,
					"position": source,
					"previous": source,
					"age": -float(source_index) * 0.018,
					"life": SIPHON_PARTICLE_LIFETIME + float(source_index) * 0.018,
					"curve": (-1.0 if (source_index + particles.size()) % 2 == 0 else 1.0) * randf_range(1.5, 4.0),
				})
	_emit_if_changed()

func set_stance_active(active: bool) -> void:
	if stance_active == active: return
	stance_active = active
	absorption_clock = 0.0
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
	var survivors: Array[Dictionary] = []
	for particle in particles:
		particle.age = float(particle.age) + delta
		particle.life = float(particle.life) - delta
		if float(particle.life) <= 0.0: continue
		if float(particle.age) >= 0.0 and is_instance_valid(player):
			var origin: Vector2 = particle.origin
			var target := player.global_position
			var progress := clampf(float(particle.age) / SIPHON_PARTICLE_LIFETIME, 0.0, 1.0)
			var eased := progress * progress * (3.0 - 2.0 * progress)
			var travel := target - origin
			var side := travel.normalized().orthogonal() if travel.length_squared() > 0.01 else Vector2.UP
			particle.previous = particle.position
			particle.position = origin.lerp(target, eased) + side * sin(progress * PI) * float(particle.curve)
		survivors.append(particle)
	particles = survivors
	queue_redraw()

func _emit_if_changed() -> void:
	if absf(reserve - last_emitted_reserve) < 0.04: return
	last_emitted_reserve = reserve
	resource_changed.emit(reserve, capacity, stance_active)

func _draw() -> void:
	for particle in particles:
		if float(particle.age) < 0.0: continue
		var life := clampf(float(particle.life) / SIPHON_PARTICLE_LIFETIME, 0.0, 1.0)
		var point: Vector2 = to_local(particle.position)
		var previous: Vector2 = to_local(particle.previous)
		# Draw only the mote's last one-pixel motion segment. Drawing to the target
		# produced the old rigid needle/laser appearance.
		if previous.distance_to(point) <= 4.0: PIXELS.line(self, previous, point, Color(BLOOD_RED, 0.32 + life * 0.46))
		else: PIXELS.pixel(self, previous, Color(BLOOD_RED, life * 0.48))
		PIXELS.pixel(self, point, Color(BLOOD_HOT, 0.65 + life * 0.35))
