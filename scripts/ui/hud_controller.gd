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
var context_backplate: ColorRect
var tactical_backplate: ColorRect
var status_backplate: ColorRect
var resource_backplate: ColorRect
var tutorial_label: Label
var keycap_label: Label
var enemy_count_label: Label
var camera_count_label: Label
var alarm_count_label: Label
var enemy_count_icon: TextureRect
var camera_count_icon: TextureRect
var alarm_count_icon: TextureRect
var cleanup_meter
var cleanup_percent_label: Label
var cleanup_tool_icon: TextureRect
var cleanup_tool_label: Label
var cleanup_tool_meter
var cleanup_police_icon: TextureRect
var cleanup_police_label: Label
var cleanup_scan_label: Label
var cleanup_exit_label: Label
var _last_objective_text := ""
var _last_interaction_text := ""
var _last_ammo_text := ""
var _last_status_text := ""
var _last_detail_text := ""
var _tutorial_time := 5.0
var _cleanup_mode := false
var _cleanup_room := ""
var _room_name_time := 0.0
var _status_message_time := 0.0
var _detail_message_time := 0.0
var _last_alarm_count := -1
var _last_cleanup_urgent := false
var _last_cleanup_tool_signature: Array = []

func _init() -> void:
	layer = 30

func _ready() -> void:
	# Four non-overlapping HUD safe zones. Tiny opaque pixel cards preserve
	# contrast without becoming the large grey veils used by older layouts.
	tactical_backplate = _make_pixel_card(Rect2(3, 3, 68, 14), Color("73f7e4"))
	status_backplate = _make_pixel_card(Rect2(87, 3, 146, 18), Color("ff3d78"))
	resource_backplate = _make_pixel_card(Rect2(276, 161, 41, 15), Color("ffe5a8"))
	status_icon = _make_icon(Vector2(91, 7), "case", Color("ff3d78"))
	status_label = _make_label(Vector2(101, 4), 6, Color("fff1f7"))
	status_label.size = Vector2(126, 9)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_label = _make_label(Vector2(101, 13), 5, Color("e2cedd"))
	detail_label.size = Vector2(126, 7)
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_icon = _make_icon(Vector2(5, 28), "target", Color("73f7e4"))
	objective_label = _make_label(Vector2(16, 27), 6, Color("73f7e4"))
	objective_label.size = Vector2(151, 10)
	enemy_count_icon = _make_icon(Vector2(5, 6), "enemy", Color("ff536e"))
	enemy_count_label = _make_label(Vector2(14, 5), 5, Color("fff1f7"))
	camera_count_icon = _make_icon(Vector2(30, 6), "target", Color("82d8ff"))
	camera_count_label = _make_label(Vector2(39, 5), 5, Color("fff1f7"))
	alarm_count_icon = _make_icon(Vector2(55, 6), "alert", Color("ffd166"))
	alarm_count_label = _make_label(Vector2(64, 5), 5, Color("fff1f7"))
	cleanup_meter = COMPACT_PROGRESS.new()
	# Cleanup progress is deliberately a small peripheral gauge. The lower
	# center is reserved for immediate context actions and must stay clear.
	cleanup_meter.position = Vector2(7, 14)
	cleanup_meter.size = Vector2(26, 1)
	cleanup_meter.custom_minimum_size = Vector2.ZERO
	cleanup_meter.max_value = 100.0
	cleanup_meter.show_percentage = false
	cleanup_meter.visible = false
	add_child(cleanup_meter)
	cleanup_percent_label = _make_label(Vector2(7, 5), 5, Color("73f7e4"))
	cleanup_percent_label.size = Vector2(22, 7)
	cleanup_percent_label.visible = false
	cleanup_tool_icon = _make_icon(Vector2(279, 165), "mop", Color("73f7e4"))
	cleanup_tool_label = _make_label(Vector2(288, 163), 6, Color("fff1f7"))
	cleanup_tool_label.size = Vector2(27, 8)
	cleanup_tool_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cleanup_tool_meter = COMPACT_PROGRESS.new()
	cleanup_tool_meter.position = Vector2(289, 173)
	cleanup_tool_meter.size = Vector2(26, 1)
	cleanup_tool_meter.max_value = 1.0
	cleanup_tool_meter.show_percentage = false
	cleanup_tool_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cleanup_tool_meter.visible = false
	add_child(cleanup_tool_meter)
	cleanup_tool_icon.visible = false
	cleanup_tool_label.visible = false
	cleanup_police_icon = _make_icon(Vector2(273, 6), "police", Color("ff536e"))
	cleanup_police_label = _make_label(Vector2(283, 5), 6, Color("ff8aa1"))
	cleanup_police_label.size = Vector2(32, 10)
	cleanup_police_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cleanup_police_icon.visible = false
	cleanup_police_label.visible = false
	cleanup_scan_label = _make_label(Vector2(84, 24), 5, Color("d995ff"))
	cleanup_scan_label.size = Vector2(152, 7)
	cleanup_scan_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cleanup_scan_label.visible = false
	cleanup_exit_label = _make_label(Vector2(35, 5), 5, Color("73f7e4"))
	cleanup_exit_label.size = Vector2(34, 9)
	cleanup_exit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	cleanup_exit_label.visible = false
	objective_icon.visible = false
	objective_label.visible = false
	performance_label = _make_label(Vector2(5, 16), 5, Color("82d8ff"))
	performance_label.size = Vector2(300, 10)
	ammo_icon = _make_icon(Vector2(278, 166), "ammo", Color("ffe5a8"))
	ammo_label = _make_label(Vector2(288, 164), 6, Color("ffe5a8"))
	ammo_label.size = Vector2(28, 8)
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo_meter = COMPACT_PROGRESS.new()
	ammo_meter.position = Vector2(290, 173)
	ammo_meter.size = Vector2(26, 1)
	ammo_meter.max_value = 1.0
	ammo_meter.value = 1.0
	ammo_meter.show_percentage = false
	ammo_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ammo_meter)
	combo_label = _make_label(Vector2(273, 6), 6, Color("ff3d78"))
	combo_label.size = Vector2(43, 8)
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	context_backplate = _make_pixel_card(Rect2(109, 146, 102, 12), Color("fff0a8"))
	context_backplate.visible = false
	keycap_label = _make_label(Vector2(112, 148), 5, Color("fff0a8"))
	keycap_label.size = Vector2(17, 8)
	keycap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keycap_label.text = "E"
	interaction_label = _make_label(Vector2(137, 148), 5, Color("fff0a8"))
	interaction_label.size = Vector2(70, 8)
	interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_icon = _make_icon(Vector2(129, 148), "interact", Color("fff0a8"))
	interaction_icon.size = Vector2(6, 6)
	interaction_icon.visible = false
	keycap_label.visible = false
	tutorial_label = _make_label(Vector2(80, 169), 5, Color("9aa0a6"))
	tutorial_label.size = Vector2(160, 7)
	tutorial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial_label.text = "WASD MOVE   MOUSE AIM   LMB FIRE"
	reticle = COMBAT_RETICLE.new() as CombatReticle
	add_child(reticle)
	banner_label = _make_label(Vector2(60, 68), 10, Color("73f7e4"))
	banner_label.size = Vector2(200, 24)
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.modulate.a = 0.0
	status_backplate.visible = false

func _process(delta: float) -> void:
	_tutorial_time -= delta
	if _cleanup_mode and _room_name_time > 0.0:
		_room_name_time = maxf(0.0, _room_name_time - delta)
		status_icon.visible = _room_name_time > 0.0
		status_label.visible = _room_name_time > 0.0
		status_backplate.visible = _room_name_time > 0.0
	if not _cleanup_mode and _status_message_time > 0.0:
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
		var status_color := Color("ff658c") if status_kind == "warning" else (Color("73f7e4") if status_kind in ["clean", "check"] else Color("ff3d78"))
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
		objective_icon.texture = PIXEL_ICONS.make(_icon_for_text(raw, "target"), Color("73f7e4"))
		objective_label.text = _compact_objective(raw)
		_last_objective_text = objective_label.text
		_pulse(objective_icon)
	if interaction_label.text != _last_interaction_text:
		var raw := interaction_label.text
		var visible := not raw.is_empty() and not raw.begins_with("1 MOP")
		interaction_icon.visible = visible
		keycap_label.visible = visible
		context_backplate.visible = visible
		interaction_icon.texture = PIXEL_ICONS.make(_icon_for_text(raw, "interact"), Color("fff0a8"))
		keycap_label.text = _extract_key(raw)
		interaction_label.text = _compact_interaction(raw) if visible else ""
		_last_interaction_text = interaction_label.text
	if ammo_label.text != _last_ammo_text:
		var raw := ammo_label.text
		ammo_icon.texture = PIXEL_ICONS.make(_icon_for_text(raw, "ammo"), Color("ffe5a8"))
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

func show_banner(text: String, color := Color("73f7e4")) -> void:
	if not is_instance_valid(banner_label): return
	banner_label.text = text
	banner_label.modulate = Color(color, 0.0)
	var tween := create_tween()
	tween.tween_property(banner_label, "modulate:a", 1.0, 0.08)
	tween.tween_interval(0.55)
	tween.tween_property(banner_label, "modulate:a", 0.0, 0.22)

func set_phase(value: String) -> void:
	var cleaning := value == "cleanup"
	_cleanup_mode = cleaning
	tactical_backplate.visible = true
	resource_backplate.visible = true
	enemy_count_icon.visible = not cleaning
	enemy_count_label.visible = not cleaning
	camera_count_icon.visible = not cleaning
	camera_count_label.visible = not cleaning
	alarm_count_icon.visible = not cleaning
	alarm_count_label.visible = not cleaning
	objective_icon.visible = cleaning
	objective_label.visible = cleaning
	cleanup_meter.visible = cleaning
	cleanup_percent_label.visible = cleaning
	cleanup_tool_icon.visible = cleaning
	cleanup_tool_label.visible = cleaning
	cleanup_tool_meter.visible = cleaning
	cleanup_exit_label.visible = cleaning
	cleanup_police_icon.visible = false
	cleanup_police_label.visible = false
	cleanup_scan_label.visible = false
	ammo_icon.visible = not cleaning
	ammo_label.visible = not cleaning
	ammo_meter.visible = not cleaning
	if not cleaning:
		status_icon.visible = true
		status_label.visible = true
		status_backplate.visible = true
		return
	tutorial_label.text = "1 MOP  2 WASH  RMB UV  TAB SCAN"
	tutorial_label.visible = true
	tutorial_label.modulate.a = 1.0
	_tutorial_time = 5.0

func set_combat_counts(enemies_left: int, cameras_left: int, alarms: int) -> void:
	var enemy_text := "x%d" % maxi(0, enemies_left)
	var camera_text := "x%d" % maxi(0, cameras_left)
	var alarm_text := "x%d" % maxi(0, alarms)
	if enemy_count_label.text != enemy_text: enemy_count_label.text = enemy_text
	if camera_count_label.text != camera_text: camera_count_label.text = camera_text
	if alarm_count_label.text != alarm_text: alarm_count_label.text = alarm_text
	if alarms > 0:
		alarm_count_label.modulate = Color("ff536e")
		if alarms != _last_alarm_count: _pulse(alarm_count_icon, 1.2)
	else:
		alarm_count_label.modulate = Color("fff1f7")
	_last_alarm_count = alarms

func set_cleanup_summary(cleanliness: float, risk: int, police_seconds := -1.0) -> void:
	cleanup_meter.value = clampf(cleanliness * 100.0, 0.0, 100.0)
	cleanup_percent_label.text = "%d%%" % roundi(cleanliness * 100.0)
	var cleanliness_color := Color("73f7e4") if cleanliness >= 0.90 else (Color("ffd166") if cleanliness >= 0.65 else Color("ff658c"))
	cleanup_percent_label.modulate = cleanliness_color
	cleanup_meter.modulate = cleanliness_color
	_set_card_accent(tactical_backplate, cleanliness_color)
	cleanup_police_icon.visible = police_seconds >= 0.0
	cleanup_police_label.visible = police_seconds >= 0.0
	if police_seconds >= 0.0:
		cleanup_police_label.text = "%02d:%02d" % [floori(police_seconds / 60.0), floori(fmod(police_seconds, 60.0))]
		var urgent := police_seconds < 30.0
		cleanup_police_label.modulate = Color("ff536e") if urgent else Color("fff1f7")
		if urgent and not _last_cleanup_urgent: _pulse(cleanup_police_icon, 1.08)
		_last_cleanup_urgent = urgent
	else:
		_last_cleanup_urgent = false
	objective_label.text = ""
	objective_icon.visible = false

func set_cleanup_tool(tool_name: String, saturation: float, flow := 0.0, washer_mode := "WIDE", washer_focus := 0.0) -> void:
	var clean_name := tool_name.to_upper().replace("PRESSURE_WASHER", "WASH").replace("EVIDENCE_BAG", "EVIDENCE").replace("BODY_BAG", "BODY")
	var icon_kind := "washer" if tool_name == "pressure_washer" else ("bag" if tool_name in ["evidence_bag", "body_bag"] else "mop")
	# A continuously changing color generated a unique runtime icon almost every
	# frame. Sixteen authored-looking pixel steps keep the gradual red transition
	# while letting the icon cache and HUD draw list remain stable.
	var ratio := snappedf(clampf(saturation, 0.0, 1.0), 1.0 / 16.0) if tool_name == "mop" else 0.0
	var flow_tier := clampi(ceili(clampf(flow, 0.0, 1.0) * 3.0), 0, 3)
	var focus_step := roundi(clampf(washer_focus, 0.0, 1.0) * 8.0)
	var signature: Array = [tool_name, roundi(ratio * 16.0), flow_tier, washer_mode, focus_step]
	if signature == _last_cleanup_tool_signature: return
	_last_cleanup_tool_signature = signature
	var tool_color := Color("73f7e4").lerp(Color("b51232"), ratio)
	cleanup_tool_icon.texture = PIXEL_ICONS.make(icon_kind, tool_color)
	if tool_name == "mop" and flow_tier > 0:
		cleanup_tool_label.text = ("MOP F%d" % flow_tier).left(9)
	elif tool_name == "pressure_washer":
		cleanup_tool_label.text = ("WASH N" if washer_mode == "NARROW" else "WASH W")
	else:
		cleanup_tool_label.text = clean_name.left(9)
	cleanup_tool_meter.visible = tool_name in ["mop", "pressure_washer"]
	cleanup_tool_meter.value = clampf(washer_focus, 0.0, 1.0) if tool_name == "pressure_washer" else ratio
	cleanup_tool_meter.modulate = Color("82d8ff") if tool_name == "pressure_washer" else tool_color
	_set_card_accent(resource_backplate, tool_color)

func set_cleanup_context(room_name: String, cleanliness: float, can_exit: bool, scan_active: bool, counts := {}, guidance := "") -> void:
	var next_room := room_name.to_upper().left(24)
	if next_room != _cleanup_room:
		_cleanup_room = next_room
		status_label.text = next_room
		status_icon.visible = true
		status_label.visible = true
		status_backplate.visible = true
		_room_name_time = 1.6
	detail_label.text = ""
	cleanup_exit_label.text = "EXIT" if can_exit else ""
	cleanup_exit_label.visible = can_exit
	cleanup_scan_label.visible = scan_active
	if scan_active:
		var bio := int(counts.get("blood", 0)) + int(counts.get("blood_pool", 0)) + int(counts.get("blood_footprint", 0)) + int(counts.get("gore", 0))
		var bodies := int(counts.get("corpse", 0))
		var evidence := int(counts.get("shell", 0)) + int(counts.get("dropped_weapon", 0)) + int(counts.get("debris", 0))
		cleanup_scan_label.text = "%s  B%d C%d E%d" % [guidance.left(15), bio, bodies, evidence]

func _extract_key(text: String) -> String:
	var begin := text.find("[")
	var finish := text.find("]")
	if begin >= 0 and finish > begin: return text.substr(begin + 1, finish - begin - 1).strip_edges().left(5)
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
	return value.left(24)

func _compact_ammo(text: String) -> String:
	var value := text.replace("PISTOL ", "").replace("SMG ", "").replace("LMG ", "").replace("SHOTGUN ", "")
	value = value.replace("PRESSURE WASHER", "WASH").replace("EVIDENCE BAG", "BAG").replace("BODY BAG", "BODY")
	return value.left(12)

func _update_ammo_meter(text: String) -> void:
	var values := _extract_numbers(text)
	if values.size() >= 2: ammo_meter.value = clampf(float(values[0]) / maxf(1.0, float(values[1])), 0.0, 1.0)
	else: ammo_meter.value = 1.0
	var urgent := values.size() >= 1 and values[0] <= 3
	ammo_label.modulate = Color("ff536e") if urgent else Color.WHITE
	_set_card_accent(resource_backplate, Color("ff536e") if urgent else Color("ffe5a8"))
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
	plate.color = Color(0.018, 0.010, 0.026, alpha)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plate)
	return plate

func _make_pixel_card(rect: Rect2, accent: Color) -> ColorRect:
	var card := _make_backplate(rect.position, rect.size, 0.68)
	card.color = Color(0.025, 0.018, 0.032, 0.78)
	var rail := ColorRect.new()
	rail.position = Vector2.ZERO
	rail.size = Vector2(1, rect.size.y)
	rail.color = accent
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(rail)
	return card

func _set_card_accent(card: ColorRect, color: Color) -> void:
	if is_instance_valid(card) and card.get_child_count() > 0:
		(card.get_child(0) as ColorRect).color = color

func _pulse(item: CanvasItem, amount := 1.10) -> void:
	if not is_instance_valid(item): return
	item.modulate = Color("73f7e4")
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
