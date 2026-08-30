class_name CleanupWorkflow
extends RefCounted

static func get_compatible_types(tool: String) -> PackedStringArray:
	match tool:
		"mop": return PackedStringArray(["blood", "blood_pool", "blood_footprint", "gore", "spill"])
		# The washer owns broad liquid cleanup; solid tissue still requires the
		# deliberate mop pass so the two tools do not collapse into one upgrade.
		"pressure_washer": return PackedStringArray(["blood", "blood_pool", "blood_footprint", "spill"])
		"evidence_bag": return PackedStringArray(["shell", "dropped_weapon", "debris"])
		"body_bag": return PackedStringArray(["corpse"])
	return PackedStringArray()

static func get_required_tool(cleanup_type: String) -> String:
	if cleanup_type in ["blood", "blood_pool", "blood_footprint", "gore", "spill"]: return "mop"
	if cleanup_type in ["shell", "dropped_weapon", "debris"]: return "evidence_bag"
	if cleanup_type == "corpse": return "body_bag"
	return "mop"

static func get_stage(counts: Dictionary) -> Dictionary:
	var bodies := int(counts.get("corpse", 0))
	var ballistic := int(counts.get("shell", 0)) + int(counts.get("dropped_weapon", 0)) + int(counts.get("debris", 0))
	var spills := int(counts.get("spill", 0))
	var biological := int(counts.get("blood", 0)) + int(counts.get("blood_pool", 0)) + int(counts.get("blood_footprint", 0)) + int(counts.get("gore", 0))
	# Source control comes first: walking through an active leak, fire or chemical
	# pool while carrying bodies merely spreads the incident through the room.
	if spills > 0: return {"index": 1, "label": "STABILIZE HAZARDS", "remaining": spills, "tool": "mop"}
	if bodies > 0: return {"index": 2, "label": "BAG BODIES", "remaining": bodies, "tool": "body_bag"}
	if ballistic > 0: return {"index": 3, "label": "RECOVER EVIDENCE", "remaining": ballistic, "tool": "evidence_bag"}
	if biological > 0: return {"index": 4, "label": "CLEAN BIOLOGICAL", "remaining": biological, "tool": "mop"}
	return {"index": 5, "label": "UV VERIFY", "remaining": 0, "tool": "scanner"}

static func get_hint(counts: Dictionary) -> String:
	var stage := get_stage(counts)
	return "STEP %d %s%s" % [int(stage.index), str(stage.label), " %d" % int(stage.remaining) if int(stage.remaining) > 0 else ""]
