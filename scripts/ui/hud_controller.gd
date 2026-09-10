class_name HudController
extends CanvasLayer

const UI_DEFAULTS := preload("res://utility/scripts/ui_defaults.gd")
const PIXEL_ICONS := preload("res://utility/pixel_icon_factory.gd")
const COMBAT_RETICLE := preload("res://scripts/ui/combat_reticle.gd")
const COMPACT_PROGRESS := preload("res://scripts/ui/compact_progress_bar.gd")

var status_label: Label
var detail_label: Label
var ammo_label: Label
var combo_label: Label
var interaction_label: Label
var objective_label: Label
var performance_label: Label
var status_icon: TextureRect
var objective_icon: TextureRect
var ammo_icon: TextureRect
var interaction_icon: TextureRect
var reticle: CombatReticle
var banner_label: Label
var ammo_meter
var focus_meter
var focus_backplate: ColorRect
var focus_icon: TextureRect
var focus_count_label: Label
var focus_caption: Label
var blood_meter
var blood_backplate: ColorRect
var blood_icon: TextureRect
var blood_count_label: Label
var vitality_backplate: ColorRect
var health_icon: TextureRect
var health_label: Label
var health_meter
var armor_icon: TextureRect
var armor_meter
var context_backplate: ColorRect
var tactical_backplate: ColorRect
var status_backplate: ColorRect
var resource_backplate: ColorRect
var ammo_caption: Label
var tutorial_label: Label
var keycap_label: Label
var enemy_count_label: Label
var camera_count_label: Label
var alarm_count_label: Label
var enemy_count_icon: TextureRect
var camera_count_icon: TextureRect
var alarm_count_icon: TextureRect
var _last_objective_text := ""
var _last_interaction_text := ""
var _last_ammo_text := ""
var _last_status_text := ""
var _last_detail_text := ""
var _tutorial_time := 5.0
var _status_message_time := 0.0
var _detail_message_time := 0.0
var _last_alarm_count := -1
var _last_focus_charges := -1
var blood_skill_label: Label
var _roguelike_mode := false

func _init() -> void:
	layer = 30

func _ready() -> void:
	# Typeset corner instruments: the centre is reserved for targets and blood.
	# Layout is in native units; fonts rasterize independently at output scale.
	tactical_backplate = _make_pixel_card(Rect2(252, 6, 62, 10), Color.WHITE)
	resource_backplate = _make_pixel_card(Rect2(6, 6, 66, 24), Color.WHITE)
	status_backplate = _make_pixel_card(Rect2(87, 6, 146, 20), Color.WHITE)
	vitality_backplate = _make_pixel_card(Rect2(6, 147, 64, 13), Color.WHITE)
	focus_backplate = _make_pixel_card(Rect2(6, 163, 64, 10), Color.WHITE)
	blood_backplate = _make_pixel_card(Rect2(254, 157, 60, 16), Color("d10b32"))
	context_backplate = _make_pixel_card(Rect2(109, 150, 102, 12), Color.WHITE)
	context_backplate.visible = false

	ammo_icon = _make_icon(Vector2(9, 10), "weapon", Color.WHITE)
	ammo_label = _make_label(Vector2(22, 7), 7, Color.WHITE)
	ammo_label.size = Vector2(47, 12)
	ammo_meter = _make_meter(Vector2(22, 25), Vector2(26, 1), Color.WHITE)
	ammo_caption = _make_label(Vector2(51, 22), 4, Color("a8a8a8"))
	ammo_caption.text = "AMMO"

	enemy_count_icon = _make_icon(Vector2(255, 7), "enemy", Color.WHITE)
	enemy_count_label = _make_label(Vector2(264, 7), 5, Color.WHITE)
	camera_count_icon = _make_icon(Vector2(277, 7), "target", Color("b8b8b8"))
	camera_count_label = _make_label(Vector2(286, 7), 5, Color.WHITE)
	alarm_count_icon = _make_icon(Vector2(297, 7), "alert", Color.WHITE)
	alarm_count_label = _make_label(Vector2(306, 7), 5, Color.WHITE)
	combo_label = _make_label(Vector2(270, 20), 10, Color.WHITE)
	combo_label.size = Vector2(44, 14)
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	health_icon = _make_icon(Vector2(9, 149), "health", Color.WHITE)
	health_label = _make_label(Vector2(20, 148), 6, Color.WHITE)
	health_label.size = Vector2(25, 9)
	health_label.text = "115"
	health_meter = _make_meter(Vector2(20, 158), Vector2(25, 1), Color.WHITE)
	armor_icon = _make_icon(Vector2(49, 149), "armor", Color("929292"))
	armor_meter = _make_meter(Vector2(58, 158), Vector2(9, 1), Color("b8b8b8"))
	armor_meter.value = 0.0

	focus_icon = _make_icon(Vector2(9, 164), "focus", Color.WHITE)
	focus_count_label = _make_label(Vector2(20, 164), 5, Color.WHITE)
	focus_count_label.text = "x3"
	focus_count_label.size = Vector2(16, 7)
	focus_caption = _make_label(Vector2(40, 164), 4, Color("b8b8b8"))
	focus_caption.text = "X FOCUS"
	focus_meter = _make_meter(Vector2(20, 171), Vector2(47, 1), Color.WHITE)
	blood_icon = _make_icon(Vector2(257, 160), "blood", Color("d10b32"))
	blood_count_label = _make_label(Vector2(268, 158), 7, Color("d10b32"))
	blood_count_label.text = "000"
	blood_count_label.size = Vector2(22, 10)
	blood_meter = _make_meter(Vector2(268, 170), Vector2(43, 1), Color("d10b32"))
	blood_meter.value = 0.0
	_make_label(Vector2(294, 160), 4, Color("b8b8b8")).text = "RMB"
	blood_skill_label = _make_label(Vector2(166, 140), 5, Color("d10b32"))
	blood_skill_label.size = Vector2(148, 9)
	blood_skill_label.clip_text = true
	blood_skill_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	blood_skill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	blood_skill_label.visible = false
	for item in [blood_backplate, blood_icon, blood_count_label, blood_meter]: item.visible = false

	status_icon = _make_icon(Vector2(91, 9), "case", Color.WHITE)
	status_label = _make_label(Vector2(101, 7), 6, Color.WHITE)
	status_label.size = Vector2(127, 9)
	status_label.clip_text = true
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_label = _make_label(Vector2(92, 17), 5, Color("b8b8b8"))
	detail_label.size = Vector2(136, 7)
	detail_label.clip_text = true
	detail_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_icon = _make_icon(Vector2(6, 34), "target", Color.WHITE)
	objective_label = _make_label(Vector2(17, 34), 5, Color.WHITE)
	objective_label.size = Vector2(151, 8)
	objective_icon.hide()
	objective_label.hide()
	performance_label = _make_label(Vector2(6, 35), 5, Color.WHITE)
	performance_label.size = Vector2(308, 10)

	keycap_label = _make_label(Vector2(112, 152), 5, Color.WHITE)
	keycap_label.size = Vector2(17, 8)
	keycap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keycap_label.text = "E"
	interaction_label = _make_label(Vector2(137, 152), 5, Color.WHITE)
	interaction_label.size = Vector2(70, 8)
	interaction_label.clip_text = true
	interaction_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_icon = _make_icon(Vector2(129, 152), "interact", Color.WHITE)
	interaction_icon.size = Vector2(6, 6)
	interaction_icon.hide()
	keycap_label.hide()
	tutorial_label = _make_label(Vector2(77, 169), 5, Color("a8a8a8"))
	tutorial_label.size = Vector2(166, 7)
	tutorial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial_label.text = "LMB FIRE  Q THROW  RMB BLOOD"
	reticle = COMBAT_RETICLE.new() as CombatReticle
	add_child(reticle)
	banner_label = _make_label(Vector2(60, 60), 10, Color.WHITE)
	banner_label.size = Vector2(200, 24)
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.modulate.a = 0.0
	status_backplate.hide()

func _make_meter(pos: Vector2, extent: Vector2, color: Color):
	var meter = COMPACT_PROGRESS.new()
	meter.position = pos
	meter.size = extent
	meter.max_value = 1.0
	meter.value = 1.0
	meter.show_percentage = false
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter.modulate = color
	add_child(meter)
	return meter

func _process(delta: float) -> void:
	_tutorial_time -= delta
	if _status_message_time > 0.0:
		_status_message_time = maxf(0.0, _status_message_time - delta)
		status_icon.visible = _status_message_time > 0.0
		status_label.visible = _status_message_time > 0.0
		status_backplate.visible = _status_message_time > 0.0
	if _detail_message_time > 0.0:
		_detail_message_time = maxf(0.0, _detail_message_time - delta)
		detail_label.visible = _detail_message_time > 0.0
	if Input.get_vector("move_left", "move_right", "move_up", "move_down").length_squared() > 0.01 or Input.is_action_just_pressed("shoot"):
		_tutorial_time = minf(_tutorial_time, 0.5)
	if _tutorial_time <= 0.0 and tutorial_label.visible:
		tutorial_label.visible = false
	if status_label.text != _last_status_text:
		var raw := status_label.text
		var status_kind := _icon_for_text(raw, "case")
		var status_color := (Color("d10b32") if status_kind == "warning" else Color("f4f4f4")) if _roguelike_mode else (Color("d10b32") if status_kind == "warning" else (Color("f4f4f4") if status_kind in ["clean", "check"] else Color("f4f4f4")))
		status_icon.texture = PIXEL_ICONS.make(status_kind, status_color)
		_set_card_accent(status_backplate, status_color)
		status_label.text = _compact_status(raw)
		_last_status_text = status_label.text
		_status_message_time = 1.8
		status_icon.visible = true
		status_label.visible = true
		status_backplate.visible = true
		_pulse(status_label)
	if detail_label.text != _last_detail_text:
		if detail_label.text.length() > 34: detail_label.text = _compact_detail(detail_label.text)
		_last_detail_text = detail_label.text
		_detail_message_time = 1.5 if not detail_label.text.is_empty() else 0.0
		detail_label.visible = _detail_message_time > 0.0
	if objective_label.text != _last_objective_text:
		var raw := objective_label.text
		objective_icon.texture = PIXEL_ICONS.make(_icon_for_text(raw, "target"), Color("f4f4f4"))
		objective_label.text = _compact_objective(raw)
		_last_objective_text = objective_label.text
		_pulse(objective_icon)
	if interaction_label.text != _last_interaction_text:
		var raw := interaction_label.text
		var visible := not raw.is_empty() and not raw.begins_with("1 MOP")
		interaction_icon.visible = visible
		keycap_label.visible = visible
		context_backplate.visible = visible
		interaction_icon.texture = PIXEL_ICONS.make(_icon_for_text(raw, "interact"), Color("f4f4f4"))
		keycap_label.text = _extract_key(raw)
		interaction_label.text = _compact_interaction(raw) if visible else ""
		_last_interaction_text = interaction_label.text
	if ammo_label.text != _last_ammo_text:
		var raw := ammo_label.text
		ammo_icon.texture = PIXEL_ICONS.make(_icon_for_text(raw, "ammo"), Color("f4f4f4"))
		ammo_label.text = _compact_ammo(raw)
		_update_ammo_meter(raw)
		_last_ammo_text = ammo_label.text

func set_combo(combo: int) -> void:
	var next_text := ("x%d" % combo) if combo > 1 else ""
	if combo_label.text != next_text: combo_label.text = next_text

func set_interaction(text: String) -> void:
	interaction_label.text = text

func set_objective(text: String) -> void:
	objective_label.text = text

func set_performance(text: String) -> void:
	performance_label.text = text

func set_weapon_spread(ratio: float, enabled: bool) -> void:
	if not is_instance_valid(reticle): return
	reticle.position = get_viewport().get_mouse_position() - reticle.size * 0.5
	reticle.set_feedback(ratio, enabled)

func set_weapon_aim_feedback(state: Dictionary, enabled: bool) -> void:
	if not is_instance_valid(reticle): return
	var cursor_position: Vector2 = state.get("cursor_position", get_viewport().get_mouse_position())
	reticle.position = cursor_position - reticle.size * 0.5
	reticle.set_aim_feedback(state, enabled)

func show_hit_confirmation(kind: String, lethal := false) -> void:
	if is_instance_valid(reticle): reticle.show_hit_confirmation(kind, lethal)

func set_combat_focus(value: float, active: bool, charges := 0, max_charges := 3, recharge_progress := 0.0) -> void:
	if not is_instance_valid(focus_meter): return
	if _roguelike_mode:
		for node in [focus_backplate, focus_icon, focus_count_label, focus_meter, focus_caption]: node.hide()
		return
	var normalized := clampf(value, 0.0, 1.0)
	focus_meter.value = normalized
	focus_meter.visible = true
	focus_meter.modulate = Color("ffffff") if active else Color("b8b8b8")
	focus_count_label.text = "x%d" % clampi(charges, 0, max_charges)
	focus_count_label.modulate = Color("ffffff") if active else (Color("f4f4f4") if charges > 0 else Color("686868"))
	focus_icon.texture = PIXEL_ICONS.make("focus", Color("ffffff") if active else Color("b8b8b8"))
	_set_card_accent(focus_backplate, Color("ffffff") if active else Color("b8b8b8"))
	if charges != _last_focus_charges:
		_pulse(focus_icon, 1.14)
		_last_focus_charges = charges
	if is_instance_valid(reticle): reticle.set_focus_active(active)

func set_roguelike_mode(enabled: bool) -> void:
	if not enabled: return
	_roguelike_mode = true
	tutorial_label.text = "LMB BLOOD FIRE  RMB SIPHON  SPACE ROLL"
	resource_backplate.visible = false
	ammo_caption.visible = false
	ammo_icon.visible = false
	ammo_label.visible = false
	ammo_meter.visible = false
	focus_backplate.visible = false
	blood_backplate.visible = true
	blood_icon.visible = true
	blood_count_label.visible = true
	blood_meter.visible = true
	_set_card_accent(tactical_backplate, Color("f4f4f4"))
	_set_card_accent(status_backplate, Color("f4f4f4"))
	_set_card_accent(resource_backplate, Color("f4f4f4"))
	_set_card_accent(vitality_backplate, Color("d10b32"))
	ammo_icon.texture = PIXEL_ICONS.make("ammo", Color("f4f4f4"))
	ammo_label.modulate = Color("f4f4f4")
	health_icon.texture = PIXEL_ICONS.make("health", Color("d10b32"))
	enemy_count_icon.texture = PIXEL_ICONS.make("enemy", Color("d10b32"))
	camera_count_icon.modulate = Color("a8a8a8")
	if is_instance_valid(blood_skill_label): blood_skill_label.visible = false

func set_blood_resource(current: float, maximum: float, active: bool, cooldowns := {}) -> void:
	if not is_instance_valid(blood_meter): return
	blood_meter.value = clampf(current / maxf(1.0, maximum), 0.0, 1.0)
	blood_meter.visible = true
	blood_count_label.text = "%03d" % roundi(current)
	var color := Color("d10b32")
	blood_meter.modulate = color
	blood_count_label.modulate = color
	blood_icon.texture = PIXEL_ICONS.make("blood", color)
	_set_card_accent(blood_backplate, color)
	if is_instance_valid(blood_skill_label):
		var q := "Q" if float(cooldowns.get("q", 0.0)) <= 0.0 else "q"
		var e := "E" if float(cooldowns.get("e", 0.0)) <= 0.0 else "e"
		var r := "R" if float(cooldowns.get("r", 0.0)) <= 0.0 else "r"
		blood_skill_label.text = "%s STEP   %s PULSE   %s GUARD   B HEAL" % [q, e, r]
		blood_skill_label.modulate = color if active else Color("a8a8a8")
		blood_skill_label.visible = active and not _roguelike_mode

func set_blood_overload(current: float, maximum: float, overloaded: bool) -> void:
	if not is_instance_valid(blood_count_label): return
	if current > maximum:
		blood_count_label.text = "%d%%" % roundi(current / maxf(1.0,maximum)*100.0)
		blood_count_label.modulate = Color.WHITE if overloaded else NeonPalette.BLOOD_CRIMSON

func set_player_health(current: int, maximum: int) -> void:
	if not is_instance_valid(health_meter): return
	var ratio := clampf(float(current) / maxf(1.0, float(maximum)), 0.0, 1.0)
	health_meter.value = ratio
	health_label.text = "%03d" % maxi(0, current)
	var color := Color.WHITE if ratio > 0.25 else Color("d10b32")
	health_meter.modulate = color
	health_icon.texture = PIXEL_ICONS.make("health", color)
	_set_card_accent(vitality_backplate, color)
	if ratio <= 0.25: _pulse(health_icon, 1.12)

func set_player_armor(current: float, maximum: float) -> void:
	if not is_instance_valid(armor_meter): return
	var ratio := clampf(current / maxf(1.0, maximum), 0.0, 1.0) if maximum > 0.0 else 0.0
	armor_meter.value = ratio
	armor_icon.modulate = Color.WHITE if maximum > 0.0 else Color(0.35, 0.35, 0.35, 0.7)

func show_banner(text: String, color := Color("f4f4f4")) -> void:
	if not is_instance_valid(banner_label): return
	banner_label.text = text
	banner_label.modulate = Color(color, 0.0)
	var tween := create_tween()
	tween.tween_property(banner_label, "modulate:a", 1.0, 0.08)
	tween.tween_interval(0.55)
	tween.tween_property(banner_label, "modulate:a", 0.0, 0.22)

func set_phase(value: String) -> void:
	if value != "combat": return
	tactical_backplate.visible = true
	resource_backplate.visible = not _roguelike_mode
	vitality_backplate.visible = true
	health_icon.visible = true
	health_label.visible = true
	health_meter.visible = true
	armor_icon.visible = true
	armor_meter.visible = true
	enemy_count_icon.visible = true
	enemy_count_label.visible = true
	camera_count_icon.visible = true
	camera_count_label.visible = true
	alarm_count_icon.visible = true
	alarm_count_label.visible = true
	objective_icon.visible = false
	objective_label.visible = false
	ammo_icon.visible = not _roguelike_mode
	ammo_label.visible = not _roguelike_mode
	ammo_meter.visible = not _roguelike_mode
	for node in [focus_backplate, focus_icon, focus_count_label, focus_meter, focus_caption]: node.visible = not _roguelike_mode
	blood_backplate.visible = _roguelike_mode
	blood_icon.visible = _roguelike_mode
	blood_count_label.visible = _roguelike_mode
	blood_meter.visible = _roguelike_mode
	status_icon.visible = true
	status_label.visible = true
	status_backplate.visible = true

func set_combat_counts(enemies_left: int, cameras_left: int, alarms: int) -> void:
	camera_count_icon.visible = cameras_left > 0
	camera_count_label.visible = cameras_left > 0
	alarm_count_icon.visible = alarms > 0
	alarm_count_label.visible = alarms > 0
	var enemy_text := "x%d" % maxi(0, enemies_left)
	var camera_text := "x%d" % maxi(0, cameras_left)
	var alarm_text := "x%d" % maxi(0, alarms)
	if enemy_count_label.text != enemy_text: enemy_count_label.text = enemy_text
	if camera_count_label.text != camera_text: camera_count_label.text = camera_text
	if alarm_count_label.text != alarm_text: alarm_count_label.text = alarm_text
	if alarms > 0:
		alarm_count_label.modulate = Color("d10b32")
		if alarms != _last_alarm_count: _pulse(alarm_count_icon, 1.2)
	else:
		alarm_count_label.modulate = Color("eeeeee")
	_last_alarm_count = alarms

func _extract_key(text: String) -> String:
	var begin := text.find("[")
	var finish := text.find("]")
	if begin >= 0 and finish > begin: return text.substr(begin + 1, finish - begin - 1).strip_edges().replace("SPACE", "SPC").left(5)
	return "LMB" if "HOLD" in text or "MOP" in text or "WASH" in text else "E"

func _compact_status(text: String) -> String:
	var value := text.replace("AFTERMATH // ", "").replace("MISSION // ", "")
	value = value.replace("CLEANUP REQUIRED", "CLEANUP").replace("SCENE STABILIZATION", "SECURING")
	value = value.replace("YOU ARE DEAD", "DEAD").replace("PERFECT CLEANUP", "PERFECT")
	return value.left(27)

func _compact_detail(text: String) -> String:
	var value := text.replace(" // ", "  ").replace("NO WITNESSES.", "")
	value = value.replace("GET CLOSE  HOLD LMB", "HOLD LMB  SCRUB")
	value = value.replace("CHECKING WEAPONS  BODIES  ACTIVE HAZARDS", "WEAPONS  BODIES  HAZARDS")
	value = value.replace("R TO INSTANT RESTART", "R  RETRY")
	value = value.replace("SECURITY BREACH  POSITION COMPROMISED", "ALARM  POSITION EXPOSED")
	return value.left(42)

func _compact_objective(text: String) -> String:
	var value := text.replace("OBJECTIVES COMPLETE // ERASE ALL EVIDENCE", "CLEAR EVIDENCE")
	value = value.replace("MISSION COMPLETE // ", "DONE  ").replace("ROOM VERIFIED // ", "ROOM OK  ")
	value = value.replace(" // ALARMS ", "  !")
	if "PRIORITY " in value: value = value.split(" // ")[0]
	elif " // RISK " in value:
		var parts := value.split(" // ")
		if parts.size() > 1: value = "%s  %s" % [parts[0], parts[1]]
	return value.left(28)

func _compact_interaction(text: String) -> String:
	var value := text.replace("[ ", "[").replace(" ]", "]").replace(" // OPTIONAL", "")
	value = value.replace("SECURE NEARBY EVIDENCE", "BAG EVIDENCE").replace("PICK UP", "TAKE")
	value = value.replace("RINSE MOP", "RINSE").replace("LEAVE SCENE", "EXIT")
	if " // " in value: value = value.split(" // ")[0]
	if value.begins_with("[") and "]" in value: value = value.substr(value.find("]") + 1).strip_edges()
	return value.replace("_", " ").left(24)

func _compact_ammo(text: String) -> String:
	var value := text.replace("PISTOL ", "").replace("SMG ", "").replace("LMG ", "").replace("SHOTGUN ", "")
	# The magazine capacity is already represented by the thin meter. Reserve
	# ammunition must not be truncated off the edge of the resource card.
	var numbers := _extract_numbers(value)
	if "/" in value and numbers.size() >= 3:
		return "%02d +%d" % [numbers[0], numbers[2]]
	value = value.replace("PRESSURE WASHER", "WASH").replace("EVIDENCE BAG", "BAG").replace("BODY BAG", "BODY")
	return value.left(12)

func _update_ammo_meter(text: String) -> void:
	var values := _extract_numbers(text)
	if values.size() >= 2: ammo_meter.value = clampf(float(values[0]) / maxf(1.0, float(values[1])), 0.0, 1.0)
	else: ammo_meter.value = 1.0
	var urgent := values.size() >= 1 and values[0] <= 3
	ammo_label.modulate = Color("d10b32") if urgent else Color.WHITE
	_set_card_accent(resource_backplate, Color("d10b32") if urgent else Color("f4f4f4"))
	if urgent: _pulse(ammo_icon, 1.18)

func _extract_numbers(text: String) -> Array[int]:
	var values: Array[int] = []
	var current := ""
	for character in text:
		if character >= "0" and character <= "9": current += character
		elif not current.is_empty():
			values.append(int(current))
			current = ""
	if not current.is_empty(): values.append(int(current))
	return values

func _make_backplate(pos: Vector2, plate_size: Vector2, alpha := 0.16) -> ColorRect:
	var plate := ColorRect.new()
	plate.position = pos
	plate.size = plate_size
	plate.color = Color(0.02, 0.02, 0.02, alpha)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plate)
	return plate

func _make_pixel_card(rect: Rect2, accent: Color) -> ColorRect:
	var card := _make_backplate(rect.position, rect.size, 0.68)
	card.color = Color(0.035, 0.035, 0.035, 0.94)
	var rail := ColorRect.new()
	rail.position = Vector2.ZERO
	rail.position = Vector2(0, rect.size.y - 1)
	rail.size = Vector2(7, 1)
	rail.color = accent
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(rail)
	return card

func _set_card_accent(card: ColorRect, color: Color) -> void:
	if is_instance_valid(card) and card.get_child_count() > 0:
		(card.get_child(0) as ColorRect).color = color

func _pulse(item: CanvasItem, amount := 1.10) -> void:
	if not is_instance_valid(item): return
	item.modulate = Color("f4f4f4")
	item.scale = Vector2.ONE
	create_tween().tween_property(item, "modulate", Color.WHITE, 0.14)

func _make_label(pos: Vector2, size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	UI_DEFAULTS.apply_label(label, size, color)
	add_child(label)
	return label

func _make_icon(pos: Vector2, kind: String, color: Color) -> TextureRect:
	var icon := TextureRect.new()
	icon.position = pos
	icon.size = Vector2(8, 8)
	icon.texture = PIXEL_ICONS.make(kind, color)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon)
	return icon

func _icon_for_text(text: String, fallback: String) -> String:
	var value := text.to_upper()
	if "POLICE" in value: return "police"
	if "HEAT" in value: return "heat"
	if "BODY" in value or "CORPSE" in value: return "body"
	if "EXECUTE" in value or "FINISH" in value: return "execute"
	if "CASING" in value or "SHELL" in value: return "casing"
	if "BLOOD" in value: return "blood"
	if "MOP" in value: return "mop"
	if "WASH" in value: return "washer"
	if "UV" in value or "SCAN" in value: return "uv"
	if "RINSE" in value or "SINK" in value: return "sink"
	if "LEAVE" in value or "EXIT" in value: return "exit"
	if "PICK UP" in value or "THROW" in value: return "weapon"
	if "CLEAN" in value or "STAIN" in value: return "clean"
	if "EVIDENCE" in value or "CLUE" in value: return "evidence"
	if "HAZARD" in value or "POLICE" in value or "DEAD" in value or "RISK" in value: return "warning"
	if "CLEANUP" in value or "CLEANER" in value: return "clean"
	if "RELOAD" in value: return "reload"
	if "/" in value and fallback == "ammo": return "ammo"
	if "COMPLETE" in value or "VERIFIED" in value or "PERFECT" in value: return "check"
	if "LEAVE" in value or "EXIT" in value: return "back"
	return fallback
