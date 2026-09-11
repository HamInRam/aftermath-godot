extends RefCounted
## Original event-driven synergies. No generated ammo or renewable blood.
const DEFINITIONS := {
	"harvest_step": "SIPHON -> 1S FREE MOVEMENT",
	"reload_breach": "RELOAD -> NEXT BLOOD SHOT PIERCES",
	"hot_swap": "THROW -> 4S BLOOD SHOT BURST",
	"last_word": "LAST BLOOD ROUND -> +35% DAMAGE",
	"blood_clock": "KILL -> SKILL COOLDOWN -0.35S",
	"field_cycle": "SHOTGUN KILL -> LOAD 1 RESERVE",
}
const RAGE_DEFINITIONS := {
	"harvest_step": "SIPHON -> 1S +10% MOVEMENT",
	"reload_breach": "RELOAD -> NEXT RAGE SHOT PIERCES",
	"hot_swap": "THROW -> NEXT RAGE SHOT +25% / 4S",
	"last_word": "FINAL RAGE SECOND -> +35% DAMAGE",
	"blood_clock": "RAGE DRAIN 12/S INSTEAD OF 14/S",
	"field_cycle": "SHOTGUN KILL -> LOAD 1 RESERVE",
}
var learned: Array[String] = []
var harvest_time := 0.0
var swap_time := 0.0
var kill_lock := 0.0
var breach_ready := false

func acquire(id: String) -> bool:
	if not DEFINITIONS.has(id) or id in learned: return false
	learned.append(id)
	return true

func offers() -> Array[String]:
	var result: Array[String] = []
	for id in DEFINITIONS:
		if id not in learned: result.append(id)
		if result.size() == 3: break
	return result

func update(delta: float) -> void:
	harvest_time = maxf(0.0, harvest_time - delta)
	swap_time = maxf(0.0, swap_time - delta)
	kill_lock = maxf(0.0, kill_lock - delta)

func on_siphon() -> void:
	if "harvest_step" in learned: harvest_time = 1.0

func on_reload() -> void:
	if "reload_breach" in learned: breach_ready = true

func on_throw() -> void:
	if "hot_swap" in learned: swap_time = 4.0

func enhance(shot: Dictionary, last_round: bool) -> void:
	if not bool(shot.enhanced): return
	if breach_ready:
		shot.penetration_bonus += 0.75
		breach_ready = false
	if swap_time > 0.0:
		shot.damage_multiplier *= 1.25
		swap_time = 0.0
	if last_round and "last_word" in learned: shot.damage_multiplier *= 1.35
	# Do not increase raw_blood_budget or blood_return_cap with damage.

func on_kill(gun: Node, cooldowns: Dictionary, weapon_id: String) -> void:
	if kill_lock > 0.0: return
	kill_lock = 0.6
	if "blood_clock" in learned:
		for key in cooldowns: cooldowns[key] = maxf(0.0, float(cooldowns[key]) - 0.35)
	if "field_cycle" not in learned or not is_instance_valid(gun): return
	if gun.weapon_id != weapon_id or gun.gun_data == null or gun.gun_data.weapon_class != "shotgun": return
	if gun.is_reloading or gun.ammo >= gun.max_ammo or gun.reserve_ammo <= 0: return
	gun.ammo += 1
	gun.reserve_ammo -= 1
	gun.ammo_by_weapon[weapon_id] = gun.ammo
	gun.reserve_by_weapon[weapon_id] = gun.reserve_ammo
	Events.publish_ammo(gun.ammo, gun.max_ammo, false)
	Events.publish_ammo_reserve(gun.reserve_ammo)

func capture() -> Dictionary:
	return {"learned": learned.duplicate(), "harvest": harvest_time, "swap": swap_time, "lock": kill_lock, "breach": breach_ready}

func restore(state: Dictionary) -> void:
	learned.clear()
	for id in state.get("learned", []): acquire(str(id))
	harvest_time = clampf(float(state.get("harvest", 0.0)), 0.0, 1.0)
	swap_time = clampf(float(state.get("swap", 0.0)), 0.0, 4.0)
	kill_lock = clampf(float(state.get("lock", 0.0)), 0.0, 0.6)
	breach_ready = bool(state.get("breach", false)) and "reload_breach" in learned
