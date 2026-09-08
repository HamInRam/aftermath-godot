extends CanvasLayer
signal perk_selected(id: String)
## Optional, non-pausing intermission. Never accepts input during an encounter.
var blood: Node
var rooms: Node
var pending := false
var consumed := false
var quiet_time := 0.0
var label: Label
var choices: Array[String] = []

func _ready() -> void:
	layer = 35
	label = Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	label.offset_left = -160
	label.offset_right = 160
	label.offset_top = -80
	label.offset_bottom = -32
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = "OPTIONAL BLOOD STYLE\nF1 FAST SIPHON / SMALL TANK\nF2 HEAVY ROUNDS / HIGH COST\nF3 FAST MOVE / LOWER DAMAGE"
	preload("res://utility/scripts/ui_defaults.gd").apply_label(label, 7, Color.WHITE)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(label)
	label.hide()

func offer(index: int) -> void:
	if index % 3 != 0 or consumed or not is_instance_valid(blood): return
	choices = blood.perks.offers()
	pending = not choices.is_empty()
	label.text = "OPTIONAL COMBAT SYNERGY"
	for slot in choices.size():
		label.text += "\nF%d %s" % [slot + 1, blood.perks.DEFINITIONS[choices[slot]]]
		if blood.perks.learned.is_empty(): label.text += [" / TANK70", " / COST5", " / LOW DMG"][slot]

func _process(delta: float) -> void:
	var safe: bool = pending and is_instance_valid(rooms) and rooms.engaged_rooms.is_empty() and not rooms.run_finished
	quiet_time = quiet_time + delta if safe else 0.0
	label.visible = safe and quiet_time >= 1.0

func _unhandled_key_input(event: InputEvent) -> void:
	if not label.visible or not pending or consumed or not is_instance_valid(blood): return
	if event is not InputEventKey or not event.pressed or event.echo: return
	var keys := [KEY_F1, KEY_F2, KEY_F3]
	var index := keys.find(event.physical_keycode)
	if index < 0 or index >= choices.size(): return
	if blood.perks.learned.is_empty(): blood.set_build(["harvester", "heavy", "mobile"][index])
	if not blood.perks.acquire(choices[index]): return
	perk_selected.emit(choices[index])
	consumed = true
	pending = false
	label.hide()
	get_viewport().set_input_as_handled()
