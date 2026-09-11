class_name RoguelikeRunSession
extends RefCounted
## Runtime-only run state. Save records persist separately; a fresh application
## never pretends it can resume a floor whose world no longer exists.

const FLOOR_LIMIT := 6
var active := false
var completed_floors: Dictionary = {}
var floor_checkpoint: Dictionary = {}
var checkpoint_floor := 0
var transfer_state: Dictionary = {}
var totals := {"score": 0, "rooms": 0, "kills": 0, "seconds": 0.0, "retries": 0}

func begin() -> void:
	active = true
	completed_floors.clear()
	floor_checkpoint.clear()
	checkpoint_floor = 0
	transfer_state.clear()
	totals = {"score": 0, "rooms": 0, "kills": 0, "seconds": 0.0, "retries": 0}

func capture(player: Node, blood: Node, focus: Dictionary) -> Dictionary:
	if not is_instance_valid(player) or not player.has_method("capture_run_loadout"): return {}
	return {
		"loadout": player.capture_run_loadout(),
		"hp": player.hp, "max_hp": player.max_hp,
		"armor": player.armor_durability, "max_armor": player.max_armor_durability,
		"armor_protection": player.armor_protection, "armor_reduction": player.armor_damage_reduction,
		"armor_head": player.armor_covers_head, "guard": player.blood_guard_points,
		"blood": blood.reserve, "blood_capacity": blood.capacity,
		"blood_rage": blood.is_raging(),
		"blood_build": blood.build_id,
		"combat_perks": blood.perks.capture(),
		"skill_cooldowns": blood.skill_cooldowns.duplicate(true),
		"focus": focus.duplicate(true),
	}

func restore(state: Dictionary, player: Node, blood: Node) -> bool:
	if state.is_empty() or not is_instance_valid(player) or not player.has_method("restore_run_loadout"): return false
	player.restore_run_loadout(state.get("loadout", {}))
	player.max_hp = maxi(1, int(state.get("max_hp", 100)))
	player.hp = clampi(int(state.get("hp", player.max_hp)), 1, player.max_hp)
	player.max_armor_durability = maxf(0.0, float(state.get("max_armor", 0.0)))
	player.armor_durability = clampf(float(state.get("armor", 0.0)), 0.0, player.max_armor_durability)
	player.armor_protection = float(state.get("armor_protection", 0.0))
	player.armor_damage_reduction = float(state.get("armor_reduction", 0.0))
	player.armor_covers_head = bool(state.get("armor_head", false))
	player.blood_guard_points = 0 if blood.blood_ammo_mode or blood.blood_rage_mode else maxi(0, int(state.get("guard", 0)))
	blood.set_build(str(state.get("blood_build", "balanced")))
	blood.perks.restore(state.get("combat_perks", {}))
	blood.capacity = maxf(1.0, float(state.get("blood_capacity", 100.0)))
	blood.reserve = clampf(float(state.get("blood", 0.0)), 0.0, blood.capacity)
	if blood.blood_rage_mode: blood._set_rage(bool(state.get("blood_rage", false)) and blood.reserve > 0.0)
	for key in blood.skill_cooldowns:
		blood.skill_cooldowns[key] = maxf(0.0, float(state.get("skill_cooldowns", {}).get(key, 0.0)))
	blood.set_stance_active(false)
	player.health_changed.emit(player.hp, player.max_hp)
	player.armor_changed.emit(player.armor_durability, player.max_armor_durability)
	blood.resource_changed.emit(blood.reserve, blood.capacity, false)
	return true

func remember_floor_start(floor_number: int, state: Dictionary) -> void:
	if not active or state.is_empty(): return
	checkpoint_floor = floor_number
	floor_checkpoint = state.duplicate(true)
	transfer_state.clear()

func get_entry_state(floor_number: int, retry: bool) -> Dictionary:
	if not active: return {}
	if retry:
		return floor_checkpoint.duplicate(true) if checkpoint_floor == floor_number else {}
	return transfer_state.duplicate(true)

func finish_floor(floor_number: int, report: Dictionary, score: int, state: Dictionary) -> bool:
	if not active or completed_floors.has(floor_number): return false
	if floor_number < 1 or floor_number > FLOOR_LIMIT or floor_number != completed_floors.size() + 1: return false
	completed_floors[floor_number] = true
	totals.score += maxi(0, score)
	totals.rooms += maxi(0, int(report.get("rooms_cleared", 0)))
	totals.kills += maxi(0, int(report.get("kills", 0)))
	totals.seconds += maxf(0.0, float(report.get("combat_seconds", 0.0)))
	transfer_state = state.duplicate(true)
	return true

func is_complete() -> bool:
	return active and completed_floors.size() >= FLOOR_LIMIT

func summary() -> Dictionary:
	var result := totals.duplicate(true)
	result["floors"] = completed_floors.size()
	result["complete"] = is_complete()
	return result
