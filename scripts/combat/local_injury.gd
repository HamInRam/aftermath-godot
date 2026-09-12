class_name LocalInjury
extends RefCounted

# Bounded anatomical damage, independent of health, blood resources and physics.
static func record(wounds: Dictionary, zone: String, local_direction: Vector2, severity: float) -> void:
	var part := "head" if zone == "head" else ("arm_a" if local_direction.y < 0.0 else "arm_b")
	if zone == "torso": part = "torso"
	if not wounds.has(part): wounds["_side_" + part] = signf(local_direction.y) if absf(local_direction.y) > 0.1 else 1.0
	wounds[part] = minf(3.0, float(wounds.get(part, 0.0)) + clampf(severity * 3.0, 0.65, 1.4))

static func apply(cells: Dictionary, wounds: Dictionary) -> Dictionary:
	if wounds.is_empty(): return cells
	var groups := {}
	for at: Vector2 in cells:
		var part: String = str(cells[at].part)
		if part in ["arm_front", "hand_a"]: part = "arm_a"
		if part in ["arm_back", "hand_b"]: part = "arm_b"
		if not wounds.has(part): continue
		if not groups.has(part): groups[part] = []
		groups[part].append(at)
	for part: String in groups:
		var points: Array = groups[part]
		var side := float(wounds.get("_side_" + part, 1.0))
		points.sort_custom(func(a: Vector2, b: Vector2): return a.y * side < b.y * side if a.y != b.y else a.x < b.x)
		var count := mini(points.size() / 3, maxi(2, int(float(wounds[part]) * 3.0)))
		# A contiguous edge notch, not random flickering holes across the body.
		for i in count:
			var at: Vector2 = points[i]
			if i < count / 2: cells.erase(at)
			else: cells[at] = {"color": Color("343434") if i % 2 == 0 else Color("b0b0b0"), "part": part}
	return cells
