class_name GameplayDesignRules
extends RefCounted

static func get_cleanup_tier(ratio: float) -> Dictionary:
	if ratio >= 0.999: return {"id": "perfect", "label": "PERFECT", "can_extract": true, "bonus": 1.25}
	if ratio >= 0.95: return {"id": "clean", "label": "AREA CLEAN", "can_extract": true, "bonus": 1.10}
	if ratio >= 0.90: return {"id": "certified", "label": "CERTIFIED", "can_extract": true, "bonus": 1.0}
	return {"id": "compromised", "label": "COMPROMISED", "can_extract": false, "bonus": 0.0}

static func get_cleanup_guidance(counts: Dictionary) -> String:
	var stage := CleanupWorkflow.get_stage(counts)
	return "%s x%d" % [str(stage.get("label", "UV VERIFY")), int(stage.get("remaining", 0))]

static func get_kit_aftermath(gun_slots: Array) -> Dictionary:
	if gun_slots.is_empty(): return {"score": 0, "label": "MINIMAL"}
	var gun_ids := ["pistol", "smg", "lmg", "shotgun"]
	var score := 0.0
	for slot in gun_slots:
		var profile := AttackCatalog.get_aftermath_profile(gun_ids[clampi(int(slot), 0, gun_ids.size() - 1)])
		score += float(profile.get("cleanup_load", 1.0))
	score /= float(gun_slots.size())
	return {"score": score, "label": "LOW" if score < 2.5 else ("HIGH" if score >= 5.0 else "MED")}
