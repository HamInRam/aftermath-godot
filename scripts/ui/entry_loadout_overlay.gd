class_name EntryLoadoutOverlay
extends CanvasLayer

signal deployment_confirmed(kit: Dictionary)
signal deployment_cancelled

const ICONS := preload("res://utility/weapon_ui_icon_factory.gd")
const MOD_WORKBENCH_SCENE := preload("res://scenes/ui/weapon_mod_workbench.tscn")
const WEAPONS_PER_PAGE := 4
const PANEL_RECT := Rect2(8, 8, 304, 164)
const CARD_DARK := Color("091217")
const CARD_ALT := Color("0c1920")
const CYAN := Color("4db8c8")
const ORANGE := Color("ff742d")
const OLIVE := Color("65703a")
const MUTED := Color("7f9699")
const CATEGORY_LABELS := {
	"all": "ALL", "handgun": "PISTOL", "pdw": "PDW", "smg": "SMG",
	"shotgun": "SHOT", "carbine": "RIFLE", "dmr": "DMR", "sniper": "SNIPER", "lmg": "LMG",
}

var mission_title := "OPERATION"
var primary_id := "colt_m4a1"
var secondary_id := "glock_17_gen5_mos"
var staged_builds: Dictionary = {}
var selected_weapon_slot := "primary"
var selected_attachment_slot := ""
var selected_preset_id := "custom"
var selected_category := "all"
var weapon_cursor := 0
var weapon_page := 0
var part_cursor := 0
var part_options := PackedStringArray()

var root: Control
var panel: Control
var preset_cards: Array[Dictionary] = []
var inventory_cards: Array[Dictionary] = []
var available_cards: Array[Dictionary] = []
var attachment_buttons: Array[Button] = []
var category_buttons: Array[Button] = []
var category_ids := PackedStringArray(["all", "handgun", "pdw", "smg", "shotgun", "carbine", "dmr", "sniper", "lmg"])
var page_counter: Label
var selected_part_icon: TextureRect
var selected_part_name: Label
var noise_meter: Control
var mobility_meter: Control
var hint: Label
var mod_workbench: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_interface()
	primary_id = str(Progression.get_weapon_loadout().primary)
	secondary_id = str(Progression.get_weapon_loadout().secondary)
	selected_preset_id = Progression.get_current_kit_id()
	for weapon_id in WeaponPlatformCatalog.get_weapon_ids():
		staged_builds[weapon_id] = Array(Progression.get_weapon_build(weapon_id))
	_select_weapon_slot("primary")
	(inventory_cards[0].action as Button).grab_focus()
	UIDefaults.animate_screen_intro(panel)

func configure(title: String) -> void:
	mission_title = title
	if is_instance_valid(hint): hint.text = mission_title.to_upper() + " // READY"

func _build_interface() -> void:
	root = Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.008, 0.012, 0.016, 0.50)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	panel = Control.new()
	panel.name = "Panel"
	panel.position = PANEL_RECT.position
	panel.size = PANEL_RECT.size
	panel.clip_contents = true
	root.add_child(panel)
	_add_rect(panel, "Shadow", Rect2(2, 2, 302, 162), Color(0, 0, 0, 0.8))
	_add_rect(panel, "Background", Rect2(0, 0, 302, 162), Color(0.018, 0.035, 0.045, 0.97))
	_draw_frame(panel, Rect2(0, 0, 302, 162), Color("315762"))
	_add_rect(panel, "TopAccent", Rect2(2, 1, 298, 1), CYAN)
	_add_rect(panel, "TopAccentWarm", Rect2(256, 1, 44, 1), ORANGE)

	_make_header(panel, "PresetsHeader", Rect2(4, 4, 46, 9), "PRESETS")
	_make_header(panel, "InventoryHeader", Rect2(52, 4, 48, 9), "KIT")
	_make_header(panel, "AvailableHeader", Rect2(103, 4, 197, 9), "ARMORY // RMB MOD")

	for index in LoadoutCatalog.ORDER.size():
		var card := _make_image_card(panel, "Preset%d" % index, Rect2(4, 15 + index * 22, 46, 21), str(index + 1))
		preset_cards.append(card)
		(card.action as Button).pressed.connect(_apply_preset.bind(index))
		(card.action as Button).mouse_entered.connect(_hover_card.bind(card, true))
		(card.action as Button).mouse_exited.connect(_hover_card.bind(card, false))
		(card.action as Button).tooltip_text = str(LoadoutCatalog.get_kit(LoadoutCatalog.ORDER[index]).name)

	for index in 5:
		var card := _make_image_card(panel, "Inventory%d" % index, Rect2(52, 15 + index * 22, 48, 21), str(index + 1))
		inventory_cards.append(card)
		(card.action as Button).mouse_entered.connect(_hover_card.bind(card, true))
		(card.action as Button).mouse_exited.connect(_hover_card.bind(card, false))
	(inventory_cards[0].action as Button).pressed.connect(_select_weapon_slot.bind("primary"))
	(inventory_cards[1].action as Button).pressed.connect(_select_weapon_slot.bind("secondary"))
	(inventory_cards[0].action as Button).gui_input.connect(_on_inventory_gui_input.bind("primary"))
	(inventory_cards[1].action as Button).gui_input.connect(_on_inventory_gui_input.bind("secondary"))
	(inventory_cards[0].action as Button).tooltip_text = "PRIMARY WEAPON // TAB TO SWITCH"
	(inventory_cards[1].action as Button).tooltip_text = "SECONDARY WEAPON // TAB TO SWITCH"
	(inventory_cards[2].action as Button).disabled = true
	(inventory_cards[3].action as Button).disabled = true
	(inventory_cards[4].action as Button).disabled = true

	var categories := Control.new()
	categories.name = "Categories"
	categories.position = Vector2(103, 15)
	categories.size = Vector2(197, 9)
	panel.add_child(categories)
	for category_id in category_ids:
		var category_button := _make_text_button(categories, "Category_" + category_id, Rect2(0, 0, 24, 9), str(CATEGORY_LABELS.get(category_id, category_id)).to_upper())
		category_button.add_theme_font_size_override("font_size", 4)
		category_button.tooltip_text = "ALL FIREARMS" if category_id == "all" else str(WeaponPlatformCatalog.CLASS_NAMES.get(category_id, category_id)).to_upper()
		category_button.pressed.connect(_select_category.bind(category_id))
		category_buttons.append(category_button)

	var rows := Control.new()
	rows.name = "AvailableRows"
	rows.position = Vector2(103, 26)
	rows.size = Vector2(197, 91)
	panel.add_child(rows)
	for index in WEAPONS_PER_PAGE:
		var card := _make_weapon_row(rows, index, Rect2(0, index * 23, 197, 22))
		available_cards.append(card)
		(card.action as Button).pressed.connect(_select_available_row.bind(index))
		(card.action as Button).gui_input.connect(_on_available_gui_input.bind(index))
		(card.action as Button).mouse_entered.connect(_hover_card.bind(card, true))
		(card.action as Button).mouse_exited.connect(_hover_card.bind(card, false))

	var previous_page := _make_text_button(panel, "PreviousPage", Rect2(103, 119, 16, 9), "<")
	previous_page.pressed.connect(_change_page.bind(-1))
	page_counter = _make_label(panel, "PageCounter", Rect2(120, 119, 34, 9), "01/01", 5, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	var next_page := _make_text_button(panel, "NextPage", Rect2(155, 119, 16, 9), ">")
	next_page.pressed.connect(_change_page.bind(1))
	hint = _make_label(panel, "Hint", Rect2(173, 119, 127, 9), "TAB SLOT // READY", 5, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)

	# A dedicated footer keeps configuration details and the primary action in
	# one stable visual block. Nothing below this divider may float outside it.
	_add_rect(panel, "FooterBackground", Rect2(102, 130, 198, 30), Color("071015"))
	_draw_frame(panel, Rect2(102, 130, 198, 30), Color("315762"))
	_add_rect(panel, "FooterAccent", Rect2(103, 131, 1, 28), CYAN)

	for index in AttachmentCatalog.SLOT_ORDER.size():
		var slot: String = AttachmentCatalog.SLOT_ORDER[index]
		var button := _make_icon_button(panel, slot.capitalize(), Rect2(106 + index * 18, 133, 15, 13))
		button.pressed.connect(_open_mod_for_current.bind(slot))
		button.mouse_entered.connect(_hover_icon.bind(button, true))
		button.mouse_exited.connect(_hover_icon.bind(button, false))
		button.tooltip_text = AttachmentCatalog.SLOT_NAMES[slot]
		attachment_buttons.append(button)
	selected_part_icon = TextureRect.new()
	selected_part_icon.name = "SelectedPartIcon"
	selected_part_icon.position = Vector2(199, 132)
	selected_part_icon.size = Vector2(14, 14)
	selected_part_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	selected_part_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	selected_part_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	panel.add_child(selected_part_icon)
	selected_part_name = _make_label(panel, "SelectedPartName", Rect2(215, 132, 82, 14), "RMB // MODIFY", 5, Color("dce8e6"), HORIZONTAL_ALIGNMENT_CENTER)

	noise_meter = _make_meter(panel, "NoiseMeter", Rect2(106, 154, 43, 3), ORANGE)
	mobility_meter = _make_meter(panel, "MobilityMeter", Rect2(153, 154, 43, 3), Color("a8b34d"))
	_make_label(panel, "NoiseCaption", Rect2(106, 147, 43, 6), "NOISE", 4, Color("df9a74"))
	_make_label(panel, "MobilityCaption", Rect2(153, 147, 43, 6), "MOBILITY", 4, Color("b9c783"))
	var deploy := _make_text_button(panel, "Deploy", Rect2(201, 147, 96, 11), "DEPLOY  >")
	deploy.add_theme_font_size_override("font_size", 5)
	deploy.pressed.connect(_deploy)

	UIDefaults.decorate_buttons(root)
	_style_primary_button(deploy)
	_style_action_buttons()

func _make_header(parent: Node, node_name: String, rect: Rect2, text: String) -> void:
	_add_rect(parent, node_name + "Bg", rect, Color("15323a"))
	_draw_frame(parent, rect, Color("315762"))
	_make_label(parent, node_name, rect, text, 5, Color("dce8e6"), HORIZONTAL_ALIGNMENT_CENTER)

func _make_image_card(parent: Node, node_name: String, rect: Rect2, index_text: String) -> Dictionary:
	var root := Control.new()
	root.name = node_name
	root.position = rect.position
	root.size = rect.size
	parent.add_child(root)
	var background := _add_rect(root, "Background", Rect2(Vector2.ZERO, rect.size), CARD_DARK)
	var accent := _add_rect(root, "Accent", Rect2(1, rect.size.y - 3, 1, 2), CYAN)
	_draw_frame(root, Rect2(Vector2.ZERO, rect.size), Color("263e46"))
	var index_label := _make_label(root, "Index", Rect2(2, 1, 7, 7), index_text, 5, MUTED)
	var image := TextureRect.new()
	image.name = "Image"
	image.position = Vector2(8, 1)
	image.size = Vector2(rect.size.x - 10, 14)
	image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	root.add_child(image)
	var name_label := _make_label(root, "Name", Rect2(3, 15, rect.size.x - 5, 6), "EMPTY", 5, Color("bfd0d0"), HORIZONTAL_ALIGNMENT_CENTER)
	var action := Button.new()
	action.name = "Action"
	action.flat = true
	action.position = Vector2.ZERO
	action.size = rect.size
	action.focus_mode = Control.FOCUS_ALL
	root.add_child(action)
	return {"root": root, "background": background, "accent": accent, "index": index_label, "image": image, "name": name_label, "action": action}

func _make_weapon_row(parent: Node, index: int, rect: Rect2) -> Dictionary:
	var root := Control.new()
	root.name = "Row%d" % index
	root.position = rect.position
	root.size = rect.size
	parent.add_child(root)
	var background := _add_rect(root, "Background", Rect2(Vector2.ZERO, rect.size), CARD_DARK if index % 2 == 0 else CARD_ALT)
	var accent := _add_rect(root, "Accent", Rect2(1, 1, 2, rect.size.y - 2), CYAN)
	_draw_frame(root, Rect2(Vector2.ZERO, rect.size), Color("263e46"))
	_make_label(root, "Index", Rect2(4, 1, 7, 7), str(index + 1), 5, MUTED)
	var image := TextureRect.new()
	image.name = "Image"
	image.position = Vector2(10, 1)
	image.size = Vector2(64, 15)
	image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	root.add_child(image)
	var name_label := _make_label(root, "Name", Rect2(5, 15, 71, 6), "PLATFORM", 5, CYAN, HORIZONTAL_ALIGNMENT_CENTER)
	var stat_kinds := ["damage", "accuracy", "magazine", "noise", "mobility", "weight"]
	var values: Array[Label] = []
	for stat_index in stat_kinds.size():
		var cell_x := 77 + stat_index * 20
		if stat_index > 0: _add_rect(root, "StatLine%d" % stat_index, Rect2(cell_x, 1, 1, 22), Color("263e46"))
		var icon := TextureRect.new()
		icon.name = stat_kinds[stat_index].capitalize()
		icon.position = Vector2(cell_x + 6, 2)
		icon.size = Vector2(8, 8)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.texture = ICONS.stat_icon(stat_kinds[stat_index])
		root.add_child(icon)
		values.append(_make_label(root, "Value%d" % stat_index, Rect2(cell_x + 1, 10, 19, 7), "--", 5, Color("d5dfdc"), HORIZONTAL_ALIGNMENT_CENTER))
		_make_label(root, "Caption%d" % stat_index, Rect2(cell_x + 1, 17, 19, 5), ["DMG", "ACC", "MAG", "SIG", "MOB", "WT"][stat_index], 4, Color("8f9d9f"), HORIZONTAL_ALIGNMENT_CENTER)
	var action := Button.new()
	action.name = "Action"
	action.flat = true
	action.position = Vector2.ZERO
	action.size = rect.size
	action.focus_mode = Control.FOCUS_ALL
	root.add_child(action)
	return {"root": root, "background": background, "accent": accent, "image": image, "name": name_label, "values": values, "action": action}

func _make_icon_button(parent: Node, node_name: String, rect: Rect2) -> Button:
	var background := _add_rect(parent, node_name + "Bg", rect, CARD_DARK)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_frame(parent, rect, Color("31515a"))
	var button := Button.new()
	button.name = node_name
	button.position = rect.position
	button.size = rect.size
	button.flat = true
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 14)
	parent.add_child(button)
	return button

func _make_text_button(parent: Node, node_name: String, rect: Rect2, text: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.position = rect.position
	button.size = rect.size
	button.text = text
	button.add_theme_font_size_override("font_size", 5)
	parent.add_child(button)
	return button

func _make_meter(parent: Node, node_name: String, rect: Rect2, color: Color) -> Control:
	var meter := Control.new()
	meter.name = node_name
	meter.position = rect.position
	meter.size = rect.size
	parent.add_child(meter)
	var segment_pitch := rect.size.x / 10.0
	for index in 10:
		_add_rect(meter, "Segment%d" % index, Rect2(index * segment_pitch, 0, maxf(1.0, segment_pitch - 1.0), rect.size.y), Color("26343a"))
	meter.set_meta("meter_color", color)
	return meter

func _set_meter(meter: Control, ratio: float) -> void:
	var count := clampi(roundi(ratio * meter.get_child_count()), 0, meter.get_child_count())
	var color: Color = meter.get_meta("meter_color")
	for index in meter.get_child_count():
		(meter.get_child(index) as ColorRect).color = color if index < count else Color("26343a")

func _make_label(parent: Node, node_name: String, rect: Rect2, text: String, font_size: int, color: Color, alignment := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.name = node_name
	label.position = rect.position
	label.size = rect.size
	label.text = text
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _add_rect(parent: Node, node_name: String, rect: Rect2, color: Color) -> ColorRect:
	var item := ColorRect.new()
	item.name = node_name
	item.position = rect.position
	item.size = rect.size
	item.color = color
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(item)
	return item

func _draw_frame(parent: Node, rect: Rect2, color: Color) -> void:
	_add_rect(parent, "FrameTop%d" % parent.get_child_count(), Rect2(rect.position, Vector2(rect.size.x, 1)), color)
	_add_rect(parent, "FrameBottom%d" % parent.get_child_count(), Rect2(rect.position + Vector2(0, rect.size.y - 1), Vector2(rect.size.x, 1)), color)
	_add_rect(parent, "FrameLeft%d" % parent.get_child_count(), Rect2(rect.position, Vector2(1, rect.size.y)), color)
	_add_rect(parent, "FrameRight%d" % parent.get_child_count(), Rect2(rect.position + Vector2(rect.size.x - 1, 0), Vector2(1, rect.size.y)), color)

func _style_action_buttons() -> void:
	for node in panel.find_children("*", "Button", true, false):
		var button := node as Button
		if button.flat:
			var empty := StyleBoxEmpty.new()
			button.add_theme_stylebox_override("normal", empty)
			button.add_theme_stylebox_override("hover", empty)
			button.add_theme_stylebox_override("pressed", empty)

func _style_primary_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("14343a")
	normal.border_color = CYAN
	normal.set_border_width_all(1)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("1b4b50")
	hover.border_color = Color("73f7e4")
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("5b361e")
	pressed.border_color = ORANGE
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color("e8ffff"))
	button.add_theme_color_override("font_hover_color", Color("ffffff"))

func _current_weapon_id() -> String:
	return primary_id if selected_weapon_slot == "primary" else secondary_id

func _current_build(weapon_id := "") -> PackedStringArray:
	var resolved := _current_weapon_id() if weapon_id.is_empty() else weapon_id
	return PackedStringArray(staged_builds.get(resolved, []))

func _select_weapon_slot(slot: String) -> void:
	selected_weapon_slot = slot
	selected_attachment_slot = ""
	selected_category = "all"
	var ids := _available_weapons()
	weapon_cursor = maxi(0, ids.find(_current_weapon_id()))
	weapon_page = weapon_cursor / WEAPONS_PER_PAGE
	_rebuild_parts()
	_refresh()

func _apply_preset(index: int) -> void:
	if index < 0 or index >= LoadoutCatalog.ORDER.size(): return
	var kit_id: String = LoadoutCatalog.ORDER[index]
	var kit := LoadoutCatalog.get_kit(kit_id)
	var guns: Array = kit.get("guns", [])
	for gun_id in guns:
		if not Progression.is_weapon_unlocked(str(gun_id)):
			_show_hint("PRESET LOCKED // PLATFORM NOT OWNED", Color("ff5577"))
			return
	selected_preset_id = kit_id
	if guns.size() > 0: primary_id = str(guns[0])
	if guns.size() > 1: secondary_id = str(guns[1])
	elif guns.size() == 1 and str(WeaponPlatformCatalog.get_platform(str(guns[0])).get("class", "")) == "handgun": secondary_id = str(guns[0])
	selected_attachment_slot = ""
	_select_weapon_slot(selected_weapon_slot)
	_show_hint("PRESET LOADED", Color("73f7e4"))

func _select_attachment_slot(slot: String) -> void:
	selected_attachment_slot = slot
	_rebuild_parts()
	_refresh()

func _available_weapons() -> PackedStringArray:
	var result := PackedStringArray()
	for weapon_class in WeaponPlatformCatalog.CLASS_ORDER:
		if selected_weapon_slot == "primary" and weapon_class == "handgun": continue
		if selected_weapon_slot == "secondary" and weapon_class not in ["handgun", "pdw"]: continue
		if selected_category != "all" and weapon_class != selected_category: continue
		for weapon_id in WeaponPlatformCatalog.get_class_weapon_ids(weapon_class):
			result.append(weapon_id)
	return result

func _allowed_categories() -> PackedStringArray:
	return PackedStringArray(["all", "handgun", "pdw"]) if selected_weapon_slot == "secondary" else PackedStringArray(["all", "pdw", "smg", "shotgun", "carbine", "dmr", "sniper", "lmg"])

func _select_category(category_id: String) -> void:
	if category_id not in _allowed_categories(): return
	selected_category = category_id
	weapon_page = 0
	weapon_cursor = 0
	_refresh()
	_show_hint("CATEGORY // " + ("ALL FIREARMS" if category_id == "all" else str(WeaponPlatformCatalog.CLASS_NAMES.get(category_id, category_id))), CYAN)

func _refresh_categories() -> void:
	var allowed := _allowed_categories()
	var button_width := floori(196.0 / float(maxi(1, allowed.size())))
	var visible_index := 0
	for index in category_buttons.size():
		var button := category_buttons[index]
		var category_id: String = category_ids[index]
		button.visible = category_id in allowed
		if not button.visible: continue
		button.position = Vector2(visible_index * button_width, 0)
		button.size = Vector2(button_width - 1, 10)
		button.modulate = Color("fff2ba") if category_id == selected_category else Color("9eb4b6")
		visible_index += 1

func _select_available_row(row_index: int) -> void:
	var ids := _available_weapons()
	var index := weapon_page * WEAPONS_PER_PAGE + row_index
	if index < 0 or index >= ids.size(): return
	if not Progression.is_weapon_unlocked(ids[index]):
		_show_hint("LOCKED // COMPLETE OPERATIONS TO REQUISITION", Color("ff7a75"))
		return
	weapon_cursor = index
	if selected_weapon_slot == "primary": primary_id = ids[index]
	else: secondary_id = ids[index]
	selected_preset_id = "custom"
	_rebuild_parts()
	_refresh()

func _cycle_weapon(direction: int) -> void:
	var ids := _available_weapons()
	if ids.is_empty(): return
	for attempt in ids.size():
		weapon_cursor = posmod(weapon_cursor + direction, ids.size())
		if Progression.is_weapon_unlocked(ids[weapon_cursor]): break
	if not Progression.is_weapon_unlocked(ids[weapon_cursor]): return
	weapon_page = weapon_cursor / WEAPONS_PER_PAGE
	if selected_weapon_slot == "primary": primary_id = ids[weapon_cursor]
	else: secondary_id = ids[weapon_cursor]
	selected_preset_id = "custom"
	_rebuild_parts()
	_refresh()

func _change_page(direction: int) -> void:
	var ids := _available_weapons()
	var pages := maxi(1, ceili(float(ids.size()) / WEAPONS_PER_PAGE))
	weapon_page = posmod(weapon_page + direction, pages)
	_refresh()

func _rebuild_parts() -> void:
	part_options = PackedStringArray([""])
	part_cursor = 0
	if selected_attachment_slot.is_empty(): return
	part_options.append_array(AttachmentCatalog.get_attachment_ids_for_slot(selected_attachment_slot, WeaponPlatformCatalog.get_platform(_current_weapon_id())))
	part_cursor = maxi(0, part_options.find(_equipped_for_slot(_current_weapon_id(), selected_attachment_slot)))

func _cycle_part(direction: int) -> void:
	if selected_attachment_slot.is_empty() or part_options.is_empty(): return
	var previous := part_cursor
	part_cursor = posmod(part_cursor + direction, part_options.size())
	if not _stage_part(part_options[part_cursor]):
		part_cursor = previous
		_show_hint("MOD LIMIT %d" % Progression.get_attachment_limit(), Color("ff5577"))
	else:
		selected_preset_id = "custom"
		_show_hint("MOD FITTED", Color("73f7e4"))
	_refresh()

func _stage_part(attachment_id: String) -> bool:
	var weapon_id := _current_weapon_id()
	var build := _current_build()
	for existing_id in build.duplicate():
		if str(AttachmentCatalog.get_attachment(existing_id).get("slot", "")) == selected_attachment_slot:
			build.remove_at(build.find(existing_id))
	if not attachment_id.is_empty():
		if build.size() >= Progression.get_attachment_limit(): return false
		build.append(attachment_id)
	staged_builds[weapon_id] = Array(build)
	return true

func _equipped_for_slot(weapon_id: String, slot: String) -> String:
	for attachment_id in _current_build(weapon_id):
		if str(AttachmentCatalog.get_attachment(attachment_id).get("slot", "")) == slot: return attachment_id
	return ""

func _refresh() -> void:
	_refresh_presets()
	_refresh_inventory()
	_refresh_categories()
	_refresh_available_rows()
	_refresh_attachments()
	var aggregate := _aggregate_stats()
	_set_meter(noise_meter, aggregate.noise)
	_set_meter(mobility_meter, aggregate.mobility)

func _refresh_presets() -> void:
	for index in preset_cards.size():
		var card := preset_cards[index]
		var kit_id: String = LoadoutCatalog.ORDER[index]
		var kit := LoadoutCatalog.get_kit(kit_id)
		var guns: Array = kit.get("guns", [])
		var preview_id := primary_id if guns.is_empty() else str(guns[0])
		(card.image as TextureRect).texture = ICONS.weapon_icon(preview_id, _current_build(preview_id))
		(card.name as Label).text = ["CUSTOM", "BALANCED", "ASSAULT", "CLEANER", "GHOST"][index]
		_set_card_state(card, OLIVE if kit_id == selected_preset_id else CARD_DARK, ORANGE if kit_id == selected_preset_id else CYAN)

func _refresh_inventory() -> void:
	var kit := LoadoutCatalog.get_kit(selected_preset_id)
	_set_inventory_weapon(0, primary_id, "PRIMARY", selected_weapon_slot == "primary")
	_set_inventory_weapon(1, secondary_id, "SECONDARY", selected_weapon_slot == "secondary")
	var supply_data := [
		["ammo", "AMMO X%d" % int(kit.get("reserve_magazines", 2))],
		["cleaner", "CLEAN %+d" % int(kit.get("cleaner_bonus", 0))],
		["focus", "FOCUS X3"],
	]
	for index in 3:
		var card := inventory_cards[index + 2]
		(card.image as TextureRect).texture = ICONS.supply_icon(supply_data[index][0])
		(card.name as Label).text = supply_data[index][1]
		_set_card_state(card, CARD_DARK, ORANGE)

func _set_inventory_weapon(index: int, weapon_id: String, caption: String, selected: bool) -> void:
	var card := inventory_cards[index]
	(card.image as TextureRect).texture = ICONS.weapon_icon(weapon_id, _current_build(weapon_id))
	(card.name as Label).text = caption
	_set_card_state(card, OLIVE if selected else CARD_DARK, ORANGE if selected else CYAN)

func _refresh_available_rows() -> void:
	var ids := _available_weapons()
	var pages := maxi(1, ceili(float(ids.size()) / WEAPONS_PER_PAGE))
	weapon_page = clampi(weapon_page, 0, pages - 1)
	for row_index in available_cards.size():
		var card := available_cards[row_index]
		var index := weapon_page * WEAPONS_PER_PAGE + row_index
		(card.root as Control).visible = index < ids.size()
		if index >= ids.size(): continue
		var weapon_id: String = ids[index]
		var data := AttackCatalog.get_gun_data(weapon_id, _current_build(weapon_id))
		var unlocked := Progression.is_weapon_unlocked(weapon_id)
		(card.image as TextureRect).texture = ICONS.weapon_icon(weapon_id, _current_build(weapon_id))
		(card.image as TextureRect).modulate = Color.WHITE if unlocked else Color("59666a")
		(card.name as Label).text = data.display_name if unlocked else "LOCKED // " + data.display_name
		var values: Array = card.values
		(values[0] as Label).text = str(data.damage * maxi(1, data.pellet_count))
		(values[1] as Label).text = "%d" % clampi(roundi(100.0 - data.spread_degrees * 8.0), 1, 99)
		(values[2] as Label).text = str(data.ammo_capacity)
		(values[3] as Label).text = "%d" % clampi(roundi(data.hearing_radius / 5.0), 0, 99)
		(values[4] as Label).text = "%d" % clampi(roundi(data.movement_speed_multiplier * 80.0), 1, 99)
		(values[5] as Label).text = "%.1f" % (data.empty_weight_grams / 1000.0)
		(card.action as Button).tooltip_text = ("%s // %s // LMB EQUIP // RMB MODIFY" if unlocked else "%s // %s // LOCKED") % [data.display_name, data.caliber]
		var equipped := weapon_id == _current_weapon_id()
		_set_card_state(card, OLIVE if equipped else (CARD_DARK if row_index % 2 == 0 else CARD_ALT), ORANGE if equipped else (CYAN if unlocked else Color("5b454e")))
	page_counter.text = "%02d/%02d" % [weapon_page + 1, pages]

func _refresh_attachments() -> void:
	var current_id := _current_weapon_id()
	for index in AttachmentCatalog.SLOT_ORDER.size():
		var slot: String = AttachmentCatalog.SLOT_ORDER[index]
		var equipped := _equipped_for_slot(current_id, slot)
		var button := attachment_buttons[index]
		button.icon = ICONS.attachment_icon(equipped, slot)
		button.modulate = Color("b8dadd") if not equipped.is_empty() else Color("637276")
	selected_part_icon.texture = ICONS.class_icon(str(WeaponPlatformCatalog.get_platform(current_id).get("class", "all")))
	selected_part_name.text = "RMB WEAPON // MODIFY"
	selected_part_name.tooltip_text = "RIGHT-CLICK ANY FIREARM OR CLICK A HARDPOINT TO OPEN THE MOD WORKBENCH"

func _set_card_state(card: Dictionary, background: Color, accent: Color) -> void:
	(card.background as ColorRect).color = background
	(card.accent as ColorRect).color = accent

func _hover_card(card: Dictionary, hovering: bool) -> void:
	if hovering:
		(card.background as ColorRect).color = (card.background as ColorRect).color.lightened(0.12)
	else:
		_refresh()

func _hover_icon(button: Button, hovering: bool) -> void:
	button.self_modulate = Color("73f7e4") if hovering else Color.WHITE

func _aggregate_stats() -> Dictionary:
	var primary := AttackCatalog.get_gun_data(primary_id, _current_build(primary_id))
	var secondary := AttackCatalog.get_gun_data(secondary_id, _current_build(secondary_id))
	var kit := LoadoutCatalog.get_kit(selected_preset_id)
	var hearing := (primary.hearing_radius + secondary.hearing_radius) * 0.5 * float(kit.get("noise", 1.0))
	var movement := (primary.movement_speed_multiplier + secondary.movement_speed_multiplier) * 0.5 * float(kit.get("move", 1.0))
	return {"noise": clampf(hearing / 330.0, 0.05, 1.0), "mobility": clampf((movement - 0.72) / 0.40, 0.05, 1.0)}

func _show_hint(message: String, color: Color) -> void:
	hint.text = message
	hint.modulate = color

func _on_inventory_gui_input(event: InputEvent, slot: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		get_viewport().set_input_as_handled()
		_open_mod_interface(primary_id if slot == "primary" else secondary_id)

func _on_available_gui_input(event: InputEvent, row_index: int) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT): return
	var ids := _available_weapons()
	var index := weapon_page * WEAPONS_PER_PAGE + row_index
	if index < 0 or index >= ids.size(): return
	if not Progression.is_weapon_unlocked(ids[index]):
		_show_hint("LOCKED // MODIFICATION UNAVAILABLE", Color("ff7a75"))
		return
	get_viewport().set_input_as_handled()
	_open_mod_interface(ids[index])

func _open_mod_for_current(slot := "") -> void:
	_open_mod_interface(_current_weapon_id(), slot)

func _open_mod_interface(target_weapon_id: String, initial_slot := "") -> void:
	if is_instance_valid(mod_workbench): return
	if not Progression.is_weapon_unlocked(target_weapon_id):
		_show_hint("LOCKED // COMPLETE OPERATIONS TO REQUISITION", Color("ff7a75"))
		return
	mod_workbench = MOD_WORKBENCH_SCENE.instantiate() as Control
	add_child(mod_workbench)
	root.visible = false
	mod_workbench.call("configure", target_weapon_id, _current_build(target_weapon_id), Progression.get_attachment_limit())
	if not initial_slot.is_empty() and initial_slot in AttachmentCatalog.SLOT_ORDER:
		mod_workbench.set("selected_slot", initial_slot)
		mod_workbench.set("page", 0)
		mod_workbench.call("_refresh")
	mod_workbench.connect("build_changed", _on_mod_build_changed)
	mod_workbench.connect("closed", _close_mod_interface)

func _on_mod_build_changed(target_weapon_id: String, build: PackedStringArray) -> void:
	staged_builds[target_weapon_id] = Array(build)
	selected_preset_id = "custom"

func _close_mod_interface() -> void:
	if not is_instance_valid(mod_workbench): return
	mod_workbench.queue_free()
	mod_workbench = null
	root.visible = true
	_refresh()
	_show_hint("MOD BUILD STAGED // CONFIRM TO SAVE", Color("73f7e4"))

func _deployment_kit() -> Dictionary:
	var kit := LoadoutCatalog.get_kit(selected_preset_id)
	kit["id"] = "custom"
	kit["guns"] = [primary_id, secondary_id]
	return kit

func _deploy() -> void:
	var kit := _deployment_kit()
	Progression.data.weapon_loadout = {"primary": primary_id, "secondary": secondary_id}
	Progression.data.weapon_builds = staged_builds.duplicate(true)
	Progression.data.current_kit_id = "custom"
	Progression.save_progress()
	deployment_confirmed.emit(kit)
	queue_free()

func _cancel() -> void:
	show_deployment_required_hint()

func show_deployment_required_hint() -> void:
	_show_hint("LOADOUT REQUIRED // CONFIRM TO DEPLOY", Color("ffb45a"))
	if not inventory_cards.is_empty() and is_instance_valid(inventory_cards[0].action):
		(inventory_cards[0].action as Button).grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(mod_workbench): return
	if event.is_action_pressed("ui_cancel"):
		_cancel()
	elif event.is_action_pressed("ui_focus_next"):
		_select_weapon_slot("secondary" if selected_weapon_slot == "primary" else "primary")
	elif event.is_action_pressed("ui_up") and selected_attachment_slot.is_empty():
		_cycle_weapon(-1)
	elif event.is_action_pressed("ui_down") and selected_attachment_slot.is_empty():
		_cycle_weapon(1)
	elif event.is_action_pressed("ui_left") and not selected_attachment_slot.is_empty():
		_cycle_part(-1)
	elif event.is_action_pressed("ui_right") and not selected_attachment_slot.is_empty():
		_cycle_part(1)
	elif event.is_action_pressed("ui_accept"):
		_deploy()
