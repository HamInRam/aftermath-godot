class_name RoguelikeRunSession
extends RefCounted
## Runtime-only run state. Save records persist separately; a fresh application
## never pretends it can resume a floor whose world no longer exists.

const FLOOR_LIMIT := 6
var active := false
var completed_floors: Dictionary = {}
var _checkpoint: RunSnapshot
var floor_checkpoint: Dictionary:
	get: return _checkpoint.to_dictionary() if _checkpoint != null else {}
	set(value): _checkpoint = RunSnapshot.from_dictionary(value)
var checkpoint_floor := 0
var _transfer: RunSnapshot
var transfer_state: Dictionary:
	get: return _transfer.to_dictionary() if _transfer != null else {}
	set(value): _transfer = RunSnapshot.from_dictionary(value)
var totals := {"score": 0, "rooms": 0, "kills": 0, "seconds": 0.0, "retries": 0}

func begin() -> void:
	active = true
	completed_floors.clear()
	_checkpoint = null
	checkpoint_floor = 0
	_transfer = null
	totals = {"score": 0, "rooms": 0, "kills": 0, "seconds": 0.0, "retries": 0}

func capture(player: Node, blood: Node, focus: Dictionary) -> Dictionary:
	var snapshot := capture_snapshot(player, blood, focus)
	return snapshot.to_dictionary() if snapshot != null else {}

func capture_snapshot(player: Node, blood: Node, focus: Dictionary) -> RunSnapshot:
	if not is_instance_valid(player) or not player.has_method("capture_run_loadout"): return null
	return RunSnapshot.from_dictionary({
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
	})

func restore(state: Dictionary, player: Node, blood: Node) -> bool:
	return restore_snapshot(RunSnapshot.from_dictionary(state), player, blood)

func restore_snapshot(state: RunSnapshot, player: Node, blood: Node) -> bool:
	if state == null or not is_instance_valid(player) or not player.has_method("restore_run_loadout"): return false
	player.restore_run_loadout(state.loadout.to_dictionary())
	player.max_hp = maxi(1, int(state.max_hp))
	player.hp = clampi(int(state.hp), 1, player.max_hp)
	player.max_armor_durability = maxf(0.0, float(state.max_armor))
	player.armor_durability = clampf(float(state.armor), 0.0, player.max_armor_durability)
	player.armor_protection = float(state.armor_protection)
	player.armor_damage_reduction = float(state.armor_reduction)
	player.armor_covers_head = bool(state.armor_head)
	player.blood_guard_points = 0 if blood.blood_ammo_mode or blood.blood_rage_mode else maxi(0, int(state.guard))
	blood.set_build(str(state.blood_build))
	blood.perks.restore(state.combat_perks.to_dictionary())
	blood.capacity = maxf(1.0, float(state.blood_capacity))
	blood.reserve = clampf(float(state.blood), 0.0, blood.capacity)
	if blood.blood_rage_mode: blood._set_rage(bool(state.blood_rage) and blood.reserve > 0.0)
	for key in blood.skill_cooldowns:
		blood.skill_cooldowns[key] = maxf(0.0, float(state.skill_cooldowns.get(key, 0.0)))
	blood.set_stance_active(false)
	player.health_changed.emit(player.hp, player.max_hp)
	player.armor_changed.emit(player.armor_durability, player.max_armor_durability)
	blood.resource_changed.emit(blood.reserve, blood.capacity, false)
	return true

func remember_floor_start(floor_number: int, state: Dictionary) -> void:
	if not active or state.is_empty(): return
	checkpoint_floor = floor_number
	_checkpoint = RunSnapshot.from_dictionary(state)
	_transfer = null

func get_entry_state(floor_number: int, retry: bool) -> Dictionary:
	var snapshot := get_entry_snapshot(floor_number, retry)
	return snapshot.to_dictionary() if snapshot != null else {}

func get_entry_snapshot(floor_number: int, retry: bool) -> RunSnapshot:
	if not active: return null
	if retry: return _checkpoint.copy() if checkpoint_floor == floor_number and _checkpoint != null else null
	return _transfer.copy() if _transfer != null else null

func remember_snapshot(floor_number: int, snapshot: RunSnapshot) -> void:
	if not active or snapshot == null: return
	checkpoint_floor = floor_number
	_checkpoint = snapshot.copy()
	_transfer = null

func set_transfer_snapshot(snapshot: RunSnapshot) -> void:
	_transfer = snapshot.copy() if snapshot != null else null

func finish_floor(floor_number: int, report: Dictionary, score: int, state: Dictionary) -> bool:
	if not active or completed_floors.has(floor_number): return false
	if floor_number < 1 or floor_number > FLOOR_LIMIT or floor_number != completed_floors.size() + 1: return false
	completed_floors[floor_number] = true
	totals.score += maxi(0, score)
	totals.rooms += maxi(0, int(report.get("rooms_cleared", 0)))
	totals.kills += maxi(0, int(report.get("kills", 0)))
	totals.seconds += maxf(0.0, float(report.get("combat_seconds", 0.0)))
	_transfer = RunSnapshot.from_dictionary(state)
	return true

func is_complete() -> bool:
	return active and completed_floors.size() >= FLOOR_LIMIT

func summary() -> Dictionary:
	var result := totals.duplicate(true)
	result["floors"] = completed_floors.size()
	result["complete"] = is_complete()
	return result
