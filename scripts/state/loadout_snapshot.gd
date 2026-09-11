class_name LoadoutSnapshot
extends RefCounted
## Weapon rows are values, never live GunData resources or scene nodes.
class Weapon:
	extends RefCounted
	var weapon_id: String = ""
	var rounds: int = 0
	var attachments: Array[String] = []
	func to_dictionary() -> Dictionary:
		return {"weapon_id": weapon_id, "rounds": rounds, "attachments": attachments.duplicate()}

var weapons: Array[Weapon] = []
var reserves: Dictionary[String, int] = {}
var equipped_weapon: String = ""
var mode: String = "gun"
var melee: String = "fist"
var movement: float = 1.0
var noise: float = 1.0

static func from_dictionary(data: Dictionary) -> LoadoutSnapshot:
	var value := LoadoutSnapshot.new()
	if data.get("weapons") is Array:
		for row in data.weapons:
			if not row is Dictionary or not row.get("weapon_id") is String: continue
			var weapon := Weapon.new()
			weapon.weapon_id = row.weapon_id
			weapon.rounds = maxi(0, int(RunSnapshot.number(row.get("rounds"), 0)))
			if row.get("attachments") is Array:
				for id in row.attachments:
					if id is String: weapon.attachments.append(id)
			value.weapons.append(weapon)
	if data.get("reserves") is Dictionary:
		for id in data.reserves:
			if id is String: value.reserves[id] = maxi(0, int(RunSnapshot.number(data.reserves[id], 0)))
	if data.get("equipped_weapon") is String: value.equipped_weapon = data.equipped_weapon
	if data.get("mode") is String: value.mode = data.mode
	if data.get("melee") is String: value.melee = data.melee
	value.movement = RunSnapshot.number(data.get("movement"), 1.0)
	value.noise = RunSnapshot.number(data.get("noise"), 1.0)
	return value

func to_dictionary() -> Dictionary:
	var rows: Array[Dictionary] = []
	for weapon in weapons: rows.append(weapon.to_dictionary())
	return {"weapons": rows, "reserves": reserves.duplicate(), "equipped_weapon": equipped_weapon,
		"mode": mode, "melee": melee, "movement": movement, "noise": noise}
