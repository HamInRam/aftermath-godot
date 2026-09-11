class_name RunSnapshot
extends RefCounted
## Detached resource checkpoint. Only adapters serialize this value to Dictionary.
var hp: int = 100
var max_hp: int = 100
var armor: float = 0.0
var max_armor: float = 0.0
var armor_protection: float = 0.0
var armor_reduction: float = 0.0
var armor_head: bool = false
var guard: int = 0
var blood: float = 0.0
var blood_capacity: float = 100.0
var blood_rage: bool = false
var blood_build: String = "balanced"
var loadout: LoadoutSnapshot = LoadoutSnapshot.new()
var combat_perks: PerkSnapshot = PerkSnapshot.new()
var skill_cooldowns: Dictionary[String, float] = {}
var focus_charges: int = 0
var focus_recharge: float = 0.0

static func from_dictionary(data: Dictionary) -> RunSnapshot:
	if data.is_empty(): return null
	var value := RunSnapshot.new()
	value.hp = int(number(data.get("hp"), 100))
	value.max_hp = int(number(data.get("max_hp"), 100))
	value.armor = float(number(data.get("armor"), 0.0))
	value.max_armor = float(number(data.get("max_armor"), 0.0))
	value.armor_protection = float(number(data.get("armor_protection"), 0.0))
	value.armor_reduction = float(number(data.get("armor_reduction"), 0.0))
	if data.get("armor_head") is bool: value.armor_head = data["armor_head"]
	value.guard = int(number(data.get("guard"), 0))
	value.blood = float(number(data.get("blood"), 0.0))
	value.blood_capacity = float(number(data.get("blood_capacity"), 100.0))
	if data.get("blood_rage") is bool: value.blood_rage = data["blood_rage"]
	if data.get("blood_build") is String: value.blood_build = data["blood_build"]
	if data.get("loadout") is Dictionary: value.loadout = LoadoutSnapshot.from_dictionary(data.loadout)
	if data.get("combat_perks") is Dictionary: value.combat_perks = PerkSnapshot.from_dictionary(data.combat_perks)
	if data.get("skill_cooldowns") is Dictionary:
		for key in data.skill_cooldowns:
			if key is String: value.skill_cooldowns[key] = maxf(0.0, number(data.skill_cooldowns[key], 0.0))
	if data.get("focus") is Dictionary:
		value.focus_charges = int(number(data.focus.get("charges"), 0.0))
		value.focus_recharge = number(data.focus.get("recharge"), 0.0)
	return value

static func number(value: Variant, fallback: float) -> float:
	return float(value) if (value is float or value is int) and is_finite(float(value)) else fallback

func to_dictionary() -> Dictionary:
	return {
		"hp": hp,
		"max_hp": max_hp,
		"armor": armor,
		"max_armor": max_armor,
		"armor_protection": armor_protection,
		"armor_reduction": armor_reduction,
		"armor_head": armor_head,
		"guard": guard,
		"blood": blood,
		"blood_capacity": blood_capacity,
		"blood_rage": blood_rage,
		"blood_build": blood_build,
		"loadout": loadout.to_dictionary(), "combat_perks": combat_perks.to_dictionary(),
		"skill_cooldowns": skill_cooldowns.duplicate(true),
		"focus": {"charges": focus_charges, "recharge": focus_recharge},
	}

func copy() -> RunSnapshot:
	return from_dictionary(to_dictionary())
