class_name HandcraftedRoomCatalog
extends RefCounted

# A room module is authored as one tactical composition: hostile anchors,
# patrol intent, role order and destructible cover. Quarter-turn and mirror
# variants preserve the authored spacing while allowing the same composition to
# fit thresholds on any side. Nothing here uses unconstrained random placement.

static func get_modules() -> Array[Dictionary]:
	return [
		_m("crossfire_gate", [Vector2(.18,.24),Vector2(.78,.26),Vector2(.32,.72),Vector2(.72,.70)], [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.UP], [Vector2(.48,.35),Vector2(.52,.68)], ["gunner","gunner","assault","melee"]),
		_m("broken_diamond", [Vector2(.50,.18),Vector2(.80,.48),Vector2(.46,.80),Vector2(.20,.54)], [Vector2.DOWN,Vector2.LEFT,Vector2.UP,Vector2.RIGHT], [Vector2(.36,.38),Vector2(.66,.62)], ["assault","gunner","heavy","melee"]),
		_m("staggered_line", [Vector2(.18,.24),Vector2(.40,.42),Vector2(.64,.58),Vector2(.82,.76)], [Vector2.RIGHT,Vector2.RIGHT,Vector2.LEFT,Vector2.LEFT], [Vector2(.32,.68),Vector2(.70,.30)], ["melee","gunner","assault","heavy"]),
		_m("left_hook", [Vector2(.20,.20),Vector2(.22,.50),Vector2(.46,.76),Vector2(.80,.68)], [Vector2.DOWN,Vector2.DOWN,Vector2.RIGHT,Vector2.LEFT], [Vector2(.48,.32),Vector2(.70,.48)], ["assault","melee","gunner","gunner"]),
		_m("right_hook", [Vector2(.80,.20),Vector2(.78,.50),Vector2(.54,.76),Vector2(.20,.68)], [Vector2.DOWN,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT], [Vector2(.52,.32),Vector2(.30,.48)], ["gunner","assault","melee","heavy"]),
		_m("rear_anchor", [Vector2(.24,.24),Vector2(.74,.24),Vector2(.30,.58),Vector2(.54,.80)], [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.LEFT], [Vector2(.52,.46),Vector2(.78,.68)], ["gunner","heavy","assault","melee"]),
		_m("forward_wedge", [Vector2(.50,.20),Vector2(.28,.46),Vector2(.72,.46),Vector2(.50,.76)], [Vector2.DOWN,Vector2.RIGHT,Vector2.LEFT,Vector2.UP], [Vector2(.18,.66),Vector2(.82,.66)], ["melee","assault","assault","gunner"]),
		_m("split_columns", [Vector2(.24,.20),Vector2(.24,.72),Vector2(.76,.28),Vector2(.76,.78)], [Vector2.DOWN,Vector2.UP,Vector2.DOWN,Vector2.UP], [Vector2(.48,.34),Vector2(.52,.66)], ["gunner","melee","gunner","heavy"]),
		_m("perimeter_clock", [Vector2(.20,.22),Vector2(.80,.24),Vector2(.78,.76),Vector2(.22,.78)], [Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP], [Vector2(.44,.46),Vector2(.60,.56)], ["gunner","assault","heavy","melee"]),
		_m("center_bait", [Vector2(.50,.44),Vector2(.18,.22),Vector2(.82,.24),Vector2(.52,.80)], [Vector2.UP,Vector2.RIGHT,Vector2.LEFT,Vector2.UP], [Vector2(.28,.62),Vector2(.74,.62)], ["melee","gunner","gunner","assault"]),
		_m("diagonal_lock", [Vector2(.20,.20),Vector2(.40,.38),Vector2(.64,.62),Vector2(.82,.80)], [Vector2(1,1),Vector2(1,1),Vector2(-1,-1),Vector2(-1,-1)], [Vector2(.70,.26),Vector2(.30,.74)], ["assault","gunner","heavy","melee"]),
		_m("shallow_arc", [Vector2(.18,.36),Vector2(.38,.22),Vector2(.64,.24),Vector2(.82,.40)], [Vector2.DOWN,Vector2.DOWN,Vector2.DOWN,Vector2.DOWN], [Vector2(.36,.68),Vector2(.66,.70)], ["gunner","assault","gunner","melee"]),
		_m("deep_arc", [Vector2(.20,.68),Vector2(.38,.80),Vector2(.64,.78),Vector2(.82,.64)], [Vector2.UP,Vector2.UP,Vector2.UP,Vector2.UP], [Vector2(.34,.30),Vector2(.68,.28)], ["melee","assault","heavy","gunner"]),
		_m("twin_funnels", [Vector2(.20,.28),Vector2(.42,.50),Vector2(.80,.28),Vector2(.60,.74)], [Vector2.RIGHT,Vector2.UP,Vector2.LEFT,Vector2.UP], [Vector2(.34,.72),Vector2(.68,.44)], ["assault","melee","gunner","heavy"]),
		_m("offset_cross", [Vector2(.48,.18),Vector2(.22,.48),Vector2(.76,.52),Vector2(.54,.80)], [Vector2.DOWN,Vector2.RIGHT,Vector2.LEFT,Vector2.UP], [Vector2(.34,.34),Vector2(.66,.68)], ["gunner","melee","assault","gunner"]),
		_m("side_pressure", [Vector2(.18,.20),Vector2(.18,.52),Vector2(.48,.76),Vector2(.82,.44)], [Vector2.DOWN,Vector2.DOWN,Vector2.RIGHT,Vector2.LEFT], [Vector2(.42,.34),Vector2(.68,.66)], ["melee","assault","gunner","heavy"]),
		_m("collapsing_box", [Vector2(.22,.24),Vector2(.76,.22),Vector2(.74,.72),Vector2(.28,.76)], [Vector2(1,1),Vector2(-1,1),Vector2(-1,-1),Vector2(1,-1)], [Vector2(.50,.38),Vector2(.50,.64)], ["assault","gunner","heavy","melee"]),
		_m("open_center", [Vector2(.16,.20),Vector2(.84,.22),Vector2(.82,.80),Vector2(.18,.78)], [Vector2.DOWN,Vector2.DOWN,Vector2.UP,Vector2.UP], [Vector2(.26,.48),Vector2(.74,.52)], ["gunner","gunner","assault","heavy"]),
		_m("narrow_bridge", [Vector2(.22,.28),Vector2(.44,.28),Vector2(.58,.72),Vector2(.80,.72)], [Vector2.RIGHT,Vector2.RIGHT,Vector2.LEFT,Vector2.LEFT], [Vector2(.36,.54),Vector2(.66,.46)], ["melee","assault","gunner","heavy"]),
		_m("wide_pincer", [Vector2(.16,.32),Vector2(.84,.34),Vector2(.28,.76),Vector2(.72,.78)], [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.UP], [Vector2(.48,.24),Vector2(.52,.60)], ["assault","gunner","melee","heavy"]),
		_m("three_one", [Vector2(.18,.24),Vector2(.42,.26),Vector2(.70,.28),Vector2(.76,.76)], [Vector2.DOWN,Vector2.DOWN,Vector2.DOWN,Vector2.LEFT], [Vector2(.30,.68),Vector2(.56,.62)], ["gunner","assault","melee","heavy"]),
		_m("checker_push", [Vector2(.24,.22),Vector2(.70,.24),Vector2(.36,.72),Vector2(.82,.70)], [Vector2.RIGHT,Vector2.LEFT,Vector2.RIGHT,Vector2.LEFT], [Vector2(.50,.46),Vector2(.18,.54)], ["assault","gunner","heavy","melee"]),
		_m("rotating_guard", [Vector2(.50,.18),Vector2(.80,.50),Vector2(.50,.82),Vector2(.20,.50)], [Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP], [Vector2(.38,.38),Vector2(.62,.62)], ["gunner","melee","assault","heavy"]),
		_m("zigzag", [Vector2(.18,.22),Vector2(.66,.28),Vector2(.34,.60),Vector2(.82,.76)], [Vector2.RIGHT,Vector2.LEFT,Vector2.RIGHT,Vector2.LEFT], [Vector2(.48,.42),Vector2(.64,.68)], ["melee","gunner","assault","gunner"]),
		_m("corner_cages", [Vector2(.20,.20),Vector2(.80,.20),Vector2(.20,.80),Vector2(.80,.80)], [Vector2(1,1),Vector2(-1,1),Vector2(1,-1),Vector2(-1,-1)], [Vector2(.34,.50),Vector2(.66,.50),Vector2(.50,.64)], ["gunner","heavy","melee","assault"]),
		_m("midline_break", [Vector2(.18,.48),Vector2(.38,.48),Vector2(.66,.52),Vector2(.84,.52)], [Vector2.UP,Vector2.DOWN,Vector2.UP,Vector2.DOWN], [Vector2(.30,.24),Vector2(.70,.76)], ["assault","melee","gunner","heavy"]),
		_m("rear_crossfire", [Vector2(.20,.74),Vector2(.80,.74),Vector2(.32,.38),Vector2(.68,.34)], [Vector2.RIGHT,Vector2.LEFT,Vector2.DOWN,Vector2.DOWN], [Vector2(.48,.60),Vector2(.50,.18)], ["gunner","gunner","assault","melee"]),
		_m("assault_fan", [Vector2(.50,.20),Vector2(.26,.42),Vector2(.74,.42),Vector2(.82,.76)], [Vector2.DOWN,Vector2(1,1),Vector2(-1,1),Vector2.LEFT], [Vector2(.40,.68),Vector2(.62,.68)], ["assault","melee","assault","heavy"]),
		_m("inner_ring", [Vector2(.36,.34),Vector2(.64,.34),Vector2(.64,.68),Vector2(.36,.68)], [Vector2.LEFT,Vector2.DOWN,Vector2.RIGHT,Vector2.UP], [Vector2(.16,.48),Vector2(.84,.52)], ["melee","assault","gunner","heavy"]),
		_m("outside_in", [Vector2(.16,.24),Vector2(.84,.28),Vector2(.78,.80),Vector2(.22,.76)], [Vector2(1,1),Vector2(-1,1),Vector2(-1,-1),Vector2(1,-1)], [Vector2(.48,.38),Vector2(.52,.66)], ["gunner","assault","heavy","melee"]),
		_m("layered_defense", [Vector2(.24,.22),Vector2(.74,.24),Vector2(.46,.54),Vector2(.64,.80)], [Vector2.DOWN,Vector2.DOWN,Vector2.UP,Vector2.LEFT], [Vector2(.34,.42),Vector2(.72,.58),Vector2(.30,.76)], ["gunner","heavy","assault","melee"]),
		_m("breach_reversal", [Vector2(.30,.18),Vector2(.70,.18),Vector2(.20,.64),Vector2(.76,.78)], [Vector2.DOWN,Vector2.DOWN,Vector2.RIGHT,Vector2.UP], [Vector2(.48,.48),Vector2(.82,.42)], ["melee","gunner","assault","heavy"]),
		_m("barbell", [Vector2(.18,.22),Vector2(.18,.76),Vector2(.82,.24),Vector2(.82,.78)], [Vector2.DOWN,Vector2.UP,Vector2.DOWN,Vector2.UP], [Vector2(.34,.50),Vector2(.66,.50)], ["assault","melee","gunner","heavy"]),
		_m("long_gallery", [Vector2(.16,.32),Vector2(.38,.70),Vector2(.62,.30),Vector2(.84,.68)], [Vector2.RIGHT,Vector2.RIGHT,Vector2.LEFT,Vector2.LEFT], [Vector2(.28,.48),Vector2(.74,.50)], ["gunner","assault","gunner","melee"]),
		_m("loading_pairs", [Vector2(.22,.20),Vector2(.46,.22),Vector2(.58,.78),Vector2(.82,.80)], [Vector2.DOWN,Vector2.RIGHT,Vector2.LEFT,Vector2.UP], [Vector2(.28,.56),Vector2(.72,.44)], ["heavy","melee","assault","gunner"]),
		_m("stage_wings", [Vector2(.18,.26),Vector2(.82,.26),Vector2(.38,.74),Vector2(.64,.76)], [Vector2.DOWN,Vector2.DOWN,Vector2.RIGHT,Vector2.LEFT], [Vector2(.32,.44),Vector2(.68,.44)], ["gunner","gunner","melee","assault"]),
		_m("central_island", [Vector2(.20,.30),Vector2(.72,.18),Vector2(.82,.68),Vector2(.30,.82)], [Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP], [Vector2(.50,.42),Vector2(.50,.62)], ["assault","gunner","heavy","melee"]),
		_m("displaced_stair", [Vector2(.18,.20),Vector2(.38,.40),Vector2(.62,.60),Vector2(.82,.80)], [Vector2.DOWN,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT], [Vector2(.22,.68),Vector2(.78,.32)], ["melee","assault","gunner","heavy"]),
		_m("window_watch", [Vector2(.18,.22),Vector2(.50,.20),Vector2(.82,.22),Vector2(.50,.78)], [Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP], [Vector2(.28,.58),Vector2(.74,.54)], ["gunner","heavy","gunner","melee"]),
		_m("screened_flanks", [Vector2(.18,.36),Vector2(.82,.36),Vector2(.26,.80),Vector2(.74,.80)], [Vector2.DOWN,Vector2.DOWN,Vector2.RIGHT,Vector2.LEFT], [Vector2(.32,.52),Vector2(.68,.52)], ["assault","gunner","melee","heavy"]),
		_m("counter_turn", [Vector2(.22,.20),Vector2(.78,.42),Vector2(.54,.80),Vector2(.18,.64)], [Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP], [Vector2(.48,.36),Vector2(.58,.58)], ["gunner","assault","melee","heavy"]),
		_m("service_sweep", [Vector2(.18,.24),Vector2(.42,.26),Vector2(.78,.54),Vector2(.48,.82)], [Vector2.DOWN,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT], [Vector2(.22,.56),Vector2(.60,.48)], ["melee","assault","gunner","gunner"]),
		_m("wide_triangle", [Vector2(.18,.22),Vector2(.82,.22),Vector2(.50,.80),Vector2(.48,.38)], [Vector2.DOWN,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT], [Vector2(.28,.58),Vector2(.72,.60)], ["gunner","gunner","heavy","melee"]),
		_m("empty_spine", [Vector2(.18,.24),Vector2(.24,.76),Vector2(.76,.22),Vector2(.82,.78)], [Vector2.DOWN,Vector2.UP,Vector2.DOWN,Vector2.UP], [Vector2(.20,.50),Vector2(.80,.50)], ["assault","gunner","melee","heavy"]),
		_m("crossed_pairs", [Vector2(.22,.30),Vector2(.38,.76),Vector2(.68,.24),Vector2(.82,.70)], [Vector2(1,1),Vector2(1,-1),Vector2(-1,1),Vector2(-1,-1)], [Vector2(.46,.42),Vector2(.58,.62)], ["melee","gunner","assault","heavy"]),
		_m("double_crescent", [Vector2(.18,.38),Vector2(.36,.18),Vector2(.66,.82),Vector2(.82,.62)], [Vector2.DOWN,Vector2.RIGHT,Vector2.LEFT,Vector2.UP], [Vector2(.36,.64),Vector2(.66,.36)], ["assault","gunner","heavy","melee"]),
		_m("split_reserve", [Vector2(.22,.20),Vector2(.78,.20),Vector2(.20,.80),Vector2(.80,.80)], [Vector2.RIGHT,Vector2.LEFT,Vector2.RIGHT,Vector2.LEFT], [Vector2(.36,.38),Vector2(.64,.62),Vector2(.50,.50)], ["gunner","melee","heavy","assault"]),
		_m("courtyard_exchange", [Vector2(.16,.46),Vector2(.46,.18),Vector2(.84,.54),Vector2(.56,.82)], [Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP], [Vector2(.34,.64),Vector2(.66,.36)], ["gunner","assault","gunner","melee"]),
	]

static func get_assignments(seed_value: int, count: int) -> Array[Dictionary]:
	var modules := get_modules()
	var indices: Array[int] = []
	for index in range(modules.size()): indices.append(index)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for index in range(indices.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var held := indices[index]
		indices[index] = indices[swap_index]
		indices[swap_index] = held
	var result: Array[Dictionary] = []
	var available: Array[int] = indices.duplicate()
	for slot in range(count):
		if available.is_empty(): available = indices.duplicate()
		var selected := 0
		if not result.is_empty():
			for candidate in range(available.size()):
				if _combat_kind(str(modules[available[candidate]].id)) != str(result[-1].combat_kind):
					selected = candidate
					break
		var module: Dictionary = modules[available[selected]].duplicate(true)
		available.remove_at(selected)
		module["combat_kind"] = _combat_kind(str(module.id))
		var transform_index := rng.randi_range(0, 7)
		module = _transform_module(module, transform_index)
		module["transform"] = transform_index
		result.append(module)
	return result

static func _combat_kind(id: String) -> String:
	if "ring" in id or "island" in id or "rotat" in id: return "orbit"
	if "cross" in id or "pincer" in id or "flank" in id: return "crossfire"
	if "open" in id or "wide" in id or "gallery" in id: return "open"
	if "breach" in id or "push" in id or "assault" in id: return "breach"
	if "screen" in id or "cage" in id or "defense" in id: return "breakthrough"
	return "skirmish"

static func validate_catalog() -> PackedStringArray:
	var errors := PackedStringArray()
	var ids := {}
	for module: Dictionary in get_modules():
		var module_id := str(module.get("id", ""))
		if module_id.is_empty() or ids.has(module_id): errors.append("duplicate or empty module id: " + module_id)
		ids[module_id] = true
		var enemies: Array = module.get("enemies", [])
		var patrols: Array = module.get("patrols", [])
		var roles: Array = module.get("roles", [])
		var props: Array = module.get("props", [])
		if enemies.size() < 4: errors.append(module_id + " needs four hostile anchors")
		if patrols.size() != enemies.size() or roles.size() != enemies.size(): errors.append(module_id + " hostile metadata mismatch")
		for point: Vector2 in enemies + props:
			if point.x < 0.14 or point.x > 0.86 or point.y < 0.14 or point.y > 0.86: errors.append(module_id + " anchor outside safe room inset")
		for enemy_point: Vector2 in enemies:
			for prop_point: Vector2 in props:
				if enemy_point.distance_to(prop_point) < 0.105: errors.append(module_id + " prop overlaps hostile anchor")
	return errors

static func _m(id: String, enemies: Array, patrols: Array, props: Array, roles: Array) -> Dictionary:
	return {"id": id, "enemies": enemies, "patrols": patrols, "props": props, "roles": roles}

static func _transform_module(module: Dictionary, transform_index: int) -> Dictionary:
	for key in ["enemies", "props"]:
		var transformed: Array[Vector2] = []
		for point: Vector2 in module.get(key, []): transformed.append(_transform_point(point, transform_index))
		module[key] = transformed
	var transformed_patrols: Array[Vector2] = []
	for direction: Vector2 in module.get("patrols", []): transformed_patrols.append(_transform_direction(direction, transform_index).normalized())
	module.patrols = transformed_patrols
	return module

static func _transform_point(point: Vector2, transform_index: int) -> Vector2:
	var p := point
	if transform_index >= 4: p.x = 1.0 - p.x
	for turn in range(transform_index % 4): p = Vector2(1.0 - p.y, p.x)
	return p

static func _transform_direction(direction: Vector2, transform_index: int) -> Vector2:
	var value := direction
	if transform_index >= 4: value.x *= -1.0
	return value.rotated(float(transform_index % 4) * PI * 0.5)
