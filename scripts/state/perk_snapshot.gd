class_name PerkSnapshot
extends RefCounted
var learned: Array[String] = []
var harvest: float = 0.0
var swap: float = 0.0
var lock: float = 0.0
var breach: bool = false

static func from_dictionary(data: Dictionary) -> PerkSnapshot:
	var value := PerkSnapshot.new()
	if data.get("learned") is Array:
		for id in data.learned:
			if id is String and id not in value.learned: value.learned.append(id)
	value.harvest = clampf(RunSnapshot.number(data.get("harvest"), 0.0), 0.0, 1.0)
	value.swap = clampf(RunSnapshot.number(data.get("swap"), 0.0), 0.0, 4.0)
	value.lock = clampf(RunSnapshot.number(data.get("lock"), 0.0), 0.0, 0.6)
	value.breach = data.get("breach", false) == true
	return value

func to_dictionary() -> Dictionary:
	return {"learned": learned.duplicate(), "harvest": harvest, "swap": swap, "lock": lock, "breach": breach}
