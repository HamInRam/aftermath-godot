class_name DestructionMaterial
extends RefCounted

const PROFILES := {
	"wood": {"resistance": 0.82, "noise": 92.0, "chunks": 3, "burst": 12, "primary": Color("777777"), "secondary": Color("bcbcbc"), "hazard": "none", "bounce": 0.18},
	"glass": {"resistance": 0.48, "noise": 108.0, "chunks": 2, "burst": 18, "primary": Color("bcbcbc"), "secondary": Color("ffffff"), "hazard": "glass", "bounce": 0.08},
	"metal": {"resistance": 1.28, "noise": 118.0, "chunks": 2, "burst": 10, "primary": Color("737373"), "secondary": Color("eeeeee"), "hazard": "electric", "bounce": 0.46},
	"plastic": {"resistance": 0.68, "noise": 82.0, "chunks": 2, "burst": 12, "primary": Color("949494"), "secondary": Color("d8d8d8"), "hazard": "none", "bounce": 0.38},
	"fabric": {"resistance": 0.72, "noise": 66.0, "chunks": 2, "burst": 7, "primary": Color("5b5b5b"), "secondary": Color("a3a3a3"), "hazard": "none", "bounce": 0.04},
	"ceramic": {"resistance": 0.58, "noise": 104.0, "chunks": 3, "burst": 16, "primary": Color("dedede"), "secondary": Color("a9a9a9"), "hazard": "water", "bounce": 0.12},
	"liquid": {"resistance": 0.55, "noise": 88.0, "chunks": 2, "burst": 9, "primary": Color("a2a2a2"), "secondary": Color("e6e6e6"), "hazard": "spill", "bounce": 0.1},
}

static func for_kind(kind: String) -> Dictionary:
	var material := material_for_kind(kind)
	var profile: Dictionary = PROFILES.get(material, PROFILES.wood).duplicate(true)
	profile["material"] = material
	return profile

static func material_for_kind(kind: String) -> String:
	if kind in ["sofa", "bed"]: return "fabric"
	if kind in ["tv", "speaker", "console", "conveyor", "evidence_cabinet", "freezer"]: return "metal"
	if kind in ["sink", "toilet"]: return "ceramic"
	if kind in ["vending", "slot_machine"]: return "plastic"
	if kind in ["plant"]: return "ceramic"
	if kind in ["bottle", "window"]: return "glass"
	return "wood"

static func energy_for_attack(attack_kind: String, raw_energy: float) -> float:
	var multiplier: float = float({"projectile": 1.0, "shotgun": 1.65, "melee": 0.8, "bat": 1.35, "thrown": 0.9, "door": 1.25, "corpse": 1.1}.get(attack_kind, 1.0))
	return maxf(0.2, raw_energy * float(multiplier))
