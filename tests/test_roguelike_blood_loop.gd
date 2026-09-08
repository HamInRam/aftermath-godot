extends Node

const BLOOD_RESOURCE := preload("res://scripts/roguelike/blood_resource_controller.gd")
const ACTOR := preload("res://scripts/actor.gd")

var failures := 0

class SiphonPlayer:
	extends Node2D
	func get_aim_world_position() -> Vector2: return global_position + Vector2.RIGHT * 24.0

class DenseBloodSource:
	extends Node
	var removed_raw := 0
	func absorb_pixel_blood(_origin: Vector2, _radius: float, _power: int, _samples: int, maximum_total: int) -> Dictionary:
		removed_raw += maximum_total
		return {"amount": maximum_total, "positions": PackedVector2Array([Vector2(12, 0)])}

func _ready() -> void:
	var resource = BLOOD_RESOURCE.new()
	add_child(resource)
	resource.reserve = 50.0
	resource.set_stance_active(true)
	var first: Dictionary = resource.consume_enhanced_round(12)
	var after_first: float = resource.reserve
	var pellet: Dictionary = resource.consume_enhanced_round(12)
	_expect(bool(first.enhanced) and bool(pellet.enhanced), "blood stance should empower every pellet in the same trigger pull")
	_expect(is_equal_approx(resource.reserve, after_first), "one shotgun trigger pull must spend blood only once")
	_expect(float(first.damage_multiplier) >= 1.6 and float(first.penetration_bonus) >= 0.8, "empowered rounds should materially increase damage and penetration")
	_expect(float(first.blood_return_cap) < float(first.blood_cost), "an empowered round must always destroy part of its paid blood cost")
	_expect(float(first.raw_blood_budget) * resource.RAW_TO_RESOURCE <= float(first.blood_return_cap) + 0.001, "siphonable impact blood must fit inside the paid return cap")
	_expect(int(first.raw_blood_budget) == int(pellet.raw_blood_budget), "cached pellets should share one trigger-pull budget instead of minting new blood")
	_expect(resource.request_skill("q"), "Q blood skill should consume available reserve")
	_expect(not resource.request_skill("q"), "Q blood skill cooldown should prevent immediate repetition")
	var actor = ACTOR.new()
	actor.max_hp = 100
	add_child(actor)
	actor.take_damage(60)
	var before_heal: int = actor.hp
	_expect(resource.consume_heal(actor), "B blood bag should heal a living wounded actor")
	_expect(actor.hp > before_heal and resource.reserve < after_first, "healing should exchange stored blood for health")
	var old_capacity: float = resource.capacity
	resource.apply_upgrade("reservoir")
	_expect(resource.capacity > old_capacity, "room rewards should persistently modify the current run")
	_expect(resource.absorption_rate_per_second == 24.0, "combat siphoning uses a finite 24-point per-second budget")
	_expect(resource.ground_drain_raw_per_second >= 180000.0, "ground siphoning should erase a typical combat pool on an OTXO-fast timescale")
	var rate_resource = BLOOD_RESOURCE.new()
	var siphon_player := SiphonPlayer.new()
	var dense_blood := DenseBloodSource.new()
	add_child(rate_resource)
	add_child(siphon_player)
	add_child(dense_blood)
	rate_resource.reserve = 0.0
	rate_resource.set_stance_active(true)
	rate_resource.update_system(1.0, siphon_player, dense_blood)
	_expect(dense_blood.removed_raw >= 180000, "one second of aimed siphoning should visibly drain dense ground blood at high speed")
	_expect(rate_resource.reserve >= 23.0 and rate_resource.reserve <= 24.1, "one second of dense siphoning must respect the faster finite budget")
	var full_resource = BLOOD_RESOURCE.new()
	var overflow_blood := DenseBloodSource.new()
	add_child(full_resource)
	add_child(overflow_blood)
	full_resource.reserve = full_resource.capacity
	full_resource.set_stance_active(true)
	full_resource.update_system(0.08, siphon_player, overflow_blood)
	_expect(overflow_blood.removed_raw == 0 and is_equal_approx(full_resource.reserve, full_resource.capacity), "a full reservoir must preserve ground blood")
	var visual = BLOOD_RESOURCE.new()
	add_child(visual)
	var sources := PackedVector2Array()
	for index in range(40): sources.append(Vector2(12 + index % 10, index / 10))
	var before_visual: float = visual.reserve
	visual._spawn_siphon_motes(sources)
	_expect(visual.particles.size() == 16, "dense absorption needs a readable packet of sixteen motes")
	for mote: Dictionary in visual.particles:
		_expect(sources.has(mote.origin), "every mote must start at an actually removed blood pixel")
	var origin := Vector2(24, 0)
	_expect(BLOOD_RESOURCE.siphon_path(origin, Vector2.ZERO, 0.0, 8.0) == origin, "arc starts exactly on blood")
	_expect(BLOOD_RESOURCE.siphon_path(origin, Vector2.ZERO, 1.0, 8.0).length() < 0.001, "arc ends inside player")
	_expect(absf(BLOOD_RESOURCE.siphon_path(origin, Vector2.ZERO, 0.5, 8.0).y) > 4.0, "pull must visibly bow rather than form a rigid beam")
	for index in range(30): visual._spawn_siphon_motes(sources)
	_expect(visual.particles.size() <= visual.MAX_SIPHON_MOTES, "effect density must remain bounded")
	visual._update_particles(1.0, siphon_player)
	_expect(visual.particles.is_empty() and visual.reserve == before_visual, "visual arrival must expire without crediting extra blood")
	if failures == 0: print("roguelike blood loop regression: PASS")
	get_tree().quit(failures)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
