class_name WeaponStatResolver
extends RefCounted

static func resolve(base_values: Dictionary, attachment_ids: PackedStringArray) -> Dictionary:
	var values := base_values.duplicate(true)
	var base := base_values.duplicate(true)
	var used_slots := {}
	var accepted := PackedStringArray()
	var extra_weight := 0.0
	var extra_length := 0.0
	for attachment_id in attachment_ids:
		var attachment := AttachmentCatalog.get_attachment(attachment_id)
		if attachment.is_empty() or not AttachmentCatalog.is_compatible(attachment, values): continue
		var slot := str(attachment.get("slot", ""))
		if slot.is_empty() or used_slots.has(slot): continue
		used_slots[slot] = attachment_id
		accepted.append(attachment_id)
		extra_weight += float(attachment.get("weight", 0.0))
		extra_length += float(attachment.get("length", 0.0))
		for key in (attachment.get("mul", {}) as Dictionary):
			values[key] = float(values.get(key, 0.0)) * float((attachment.mul as Dictionary)[key])
		for key in (attachment.get("add", {}) as Dictionary):
			values[key] = float(values.get(key, 0.0)) + float((attachment.add as Dictionary)[key])
		for key in (attachment.get("set", {}) as Dictionary): values[key] = (attachment.set as Dictionary)[key]
	values.attachment_weight = extra_weight
	values.attachment_length = extra_length
	values.accepted_attachments = accepted
	# Hard caps keep builds believable and prevent a single best-in-slot stack.
	values.spread = maxf(float(base.get("spread", 1.0)) * 0.55, float(values.get("spread", 1.0)))
	values.recoil = maxf(float(base.get("recoil", 1.0)) * 0.55, float(values.get("recoil", 1.0)))
	values.reload = maxf(float(base.get("reload", 1.0)) * 0.70, float(values.get("reload", 1.0)))
	values.capacity = mini(int(float(base.get("capacity", base.get("cap", 1))) * 2.0), int(values.get("capacity", values.get("cap", 1))))
	values.noise = maxf(70.0, float(values.get("noise", 150.0)))
	values.move = clampf(float(values.get("move", 1.0)), float(base.get("move", 1.0)) - 0.08, float(base.get("move", 1.0)) + 0.08)
	values.aim = clampf(float(values.get("aim", 10.0)), 3.8, 20.0)
	values.look_ahead = clampf(float(values.get("look_ahead", 1.0)), 0.75, 1.55)
	return values

static func compare(base_data: GunData, built_data: GunData) -> Dictionary:
	return {
		"accuracy": _percent_inverse(base_data.spread_degrees, built_data.spread_degrees),
		"control": _percent_inverse(base_data.recoil_strength, built_data.recoil_strength),
		"handling": _percent_direct(base_data.aim_follow_speed, built_data.aim_follow_speed),
		"mobility": _percent_direct(base_data.movement_speed_multiplier, built_data.movement_speed_multiplier),
		"capacity": built_data.ammo_capacity - base_data.ammo_capacity,
		"noise": _percent_inverse(base_data.hearing_radius, built_data.hearing_radius),
		"penetration": _percent_direct(base_data.penetration_power, built_data.penetration_power),
		"aftermath": _percent_direct(base_data.cleanup_burden, built_data.cleanup_burden),
	}

static func _percent_direct(base_value: float, built_value: float) -> int:
	return roundi((built_value / maxf(0.001, base_value) - 1.0) * 100.0)

static func _percent_inverse(base_value: float, built_value: float) -> int:
	return roundi((base_value / maxf(0.001, built_value) - 1.0) * 100.0)
