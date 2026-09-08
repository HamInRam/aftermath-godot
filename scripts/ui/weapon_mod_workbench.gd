class_name WeaponModWorkbench
extends Control

signal build_changed(weapon_id: String, build: PackedStringArray)
signal closed

const ICONS := preload("res://utility/weapon_ui_icon_factory.gd")
const PANEL_RECT := Rect2(4, 5, 312, 170)
const CARD := Color("091217")
const CARD_ALT := Color("0d1a20")
const CYAN := Color("55d8d0")
const ORANGE := Color("ff742d")
const OLIVE := Color("65703a")
const MUTED := Color("7f9699")
const PARTS_PER_PAGE := 6

var weapon_id := "colt_m4a1"
var build := PackedStringArray()
var attachment_limit := 3
var selected_slot := "muzzle"
var page := 0

var panel: Control
var weapon_image: TextureRect
var weapon_name: Label
var weapon_meta: Label
var build_count: Label
var slot_cards: Array[Dictionary] = []
var part_cards: Array[Dictionary] = []
var stat_values: Array[Label] = []
var page_label: Label
var slot_title: Label
var hint: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_interface()
	_refresh()
	UIDefaults.animate_screen_intro(panel)

func configure(new_weapon_id: String, new_build: PackedStringArray, max_parts: int) -> void:
	weapon_id = WeaponPlatformCatalog.canonical_id(new_weapon_id)
	build = new_build.duplicate()
	attachment_limit = maxi(1, max_parts)
	selected_slot = AttachmentCatalog.SLOT_ORDER[0]
	page = 0
	if is_instance_valid(panel): _refresh()

func _build_interface() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.004, 0.008, 0.012, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	panel = Control.new()
	panel.name = "Panel"
	panel.position = PANEL_RECT.position
	panel.size = PANEL_RECT.size
	add_child(panel)
	_add_rect(panel, "Shadow", Rect2(2, 2, 310, 168), Color(0, 0, 0, 0.84))
	_add_rect(panel, "Background", Rect2(0, 0, 310, 168), Color(0.018, 0.034, 0.042, 0.985))
	_frame(panel, Rect2(0, 0, 310, 168), Color("37616a"))
	_add_rect(panel, "TopAccent", Rect2(2, 1, 306, 1), CYAN)
	_label(panel, "Title", Rect2(5, 4, 177, 9), "WEAPON MODIFICATION", 6, Color("e6efed"))
	build_count = _label(panel, "BuildCount", Rect2(184, 4, 121, 9), "0/3 HARDPOINTS", 5, CYAN, HORIZONTAL_ALIGNMENT_RIGHT)

	# Receiver deck: a large live silhouette and compact base information.
	_add_rect(panel, "WeaponDeck", Rect2(4, 15, 118, 50), CARD)
	_frame(panel, Rect2(4, 15, 118, 50), Color("29464e"))
	weapon_image = TextureRect.new()
	weapon_image.name = "WeaponPreview"
	weapon_image.position = Vector2(7, 18)
	weapon_image.size = Vector2(112, 31)
	weapon_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	weapon_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	weapon_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	panel.add_child(weapon_image)
	weapon_name = _label(panel, "WeaponName", Rect2(7, 48, 112, 8), "PLATFORM", 5, Color("e2e9e7"), HORIZONTAL_ALIGNMENT_CENTER)
	weapon_meta = _label(panel, "WeaponMeta", Rect2(7, 56, 112, 7), "CLASS // CALIBRE", 5, MUTED, HORIZONTAL_ALIGNMENT_CENTER)

	_add_rect(panel, "StatsDeck", Rect2(125, 15, 181, 50), CARD)
	_frame(panel, Rect2(125, 15, 181, 50), Color("29464e"))
	var stats := ["accuracy", "control", "handling", "mobility", "capacity", "noise"]
	var captions := ["ACC", "CTL", "AIM", "MOB", "CAP", "SIG"]
	for index in stats.size():
		var x := 128 + index * 29
		var icon := TextureRect.new()
		icon.name = stats[index].capitalize()
		icon.position = Vector2(x + 10, 20)
		icon.size = Vector2(8, 8)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.texture = ICONS.stat_icon(_stat_icon_kind(stats[index]))
		panel.add_child(icon)
		stat_values.append(_label(panel, "Stat%d" % index, Rect2(x, 31, 28, 10), "+0", 5, Color("dce7e5"), HORIZONTAL_ALIGNMENT_CENTER))
		_label(panel, "StatCaption%d" % index, Rect2(x, 43, 28, 7), captions[index], 4, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		if index > 0: _add_rect(panel, "StatDivider%d" % index, Rect2(x - 1, 19, 1, 34), Color("20383f"))
	_label(panel, "StatLegend", Rect2(128, 54, 174, 8), "UP IMPROVES // DOWN TRADE-OFF", 5, Color("aebabb"), HORIZONTAL_ALIGNMENT_CENTER)

	_label(panel, "HardpointsHeader", Rect2(4, 68, 118, 8), "HARDPOINTS", 5, CYAN)
	for index in AttachmentCatalog.SLOT_ORDER.size():
		var slot: String = AttachmentCatalog.SLOT_ORDER[index]
		var card := _make_slot_card(index, Rect2(4, 78 + index * 15, 118, 14), slot)
		slot_cards.append(card)
		(card.action as Button).pressed.connect(_select_slot.bind(slot))

	slot_title = _label(panel, "PartHeader", Rect2(125, 68, 151, 8), "AVAILABLE PARTS", 5, CYAN)
	var previous := _button(panel, "PreviousPage", Rect2(278, 67, 13, 9), "<")
	previous.pressed.connect(_change_page.bind(-1))
	page_label = _label(panel, "Page", Rect2(290, 68, 15, 8), "1/1", 5, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	for index in PARTS_PER_PAGE:
		var column := index % 2
		var row := index / 2
		var card := _make_part_card(index, Rect2(125 + column * 91, 78 + row * 25, 88, 23))
		part_cards.append(card)
		(card.action as Button).pressed.connect(_fit_part_row.bind(index))
	var next := _button(panel, "NextPage", Rect2(293, 143, 13, 9), ">")
	next.pressed.connect(_change_page.bind(1))

	hint = _label(panel, "Hint", Rect2(5, 155, 219, 10), "CLICK PART TO FIT // ESC RETURN", 5, MUTED)
	var done := _button(panel, "Done", Rect2(239, 155, 67, 10), "DONE")
	done.add_theme_font_size_override("font_size", 5)
	done.pressed.connect(_close)
	UIDefaults.decorate_buttons(self)
	_style_flat_buttons()

func _make_slot_card(index: int, rect: Rect2, slot: String) -> Dictionary:
	var root := Control.new()
	root.name = "Slot%d" % index
	root.position = rect.position
	root.size = rect.size
	panel.add_child(root)
	var bg := _add_rect(root, "Background", Rect2(Vector2.ZERO, rect.size), CARD_ALT if index % 2 else CARD)
	var accent := _add_rect(root, "Accent", Rect2(1, 1, 2, rect.size.y - 2), CYAN)
	_frame(root, Rect2(Vector2.ZERO, rect.size), Color("29464e"))
	var image := TextureRect.new()
	image.name = "PartImage"
	image.position = Vector2(5, 1)
	image.size = Vector2(28, 12)
	image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	root.add_child(image)
	var name := _label(root, "Name", Rect2(35, 1, 80, 7), AttachmentCatalog.SLOT_NAMES[slot], 5, Color("d6e1df"))
	var equipped := _label(root, "Equipped", Rect2(35, 7, 80, 6), "FACTORY", 4, MUTED)
	var action := Button.new()
	action.name = "Action"
	action.flat = true
	action.position = Vector2.ZERO
	action.size = rect.size
	action.tooltip_text = AttachmentCatalog.SLOT_NAMES[slot]
	root.add_child(action)
	return {"root": root, "background": bg, "accent": accent, "image": image, "name": name, "equipped": equipped, "action": action, "slot": slot}

func _make_part_card(index: int, rect: Rect2) -> Dictionary:
	var root := Control.new()
	root.name = "Part%d" % index
	root.position = rect.position
	root.size = rect.size
	panel.add_child(root)
	var bg := _add_rect(root, "Background", Rect2(Vector2.ZERO, rect.size), CARD_ALT if index % 2 else CARD)
	var accent := _add_rect(root, "Accent", Rect2(1, 1, 2, rect.size.y - 2), CYAN)
	_frame(root, Rect2(Vector2.ZERO, rect.size), Color("29464e"))
	var image := TextureRect.new()
	image.name = "Image"
	image.position = Vector2(4, 1)
	image.size = Vector2(31, 19)
	image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	root.add_child(image)
	var name := _label(root, "Name", Rect2(36, 2, 50, 9), "PART", 5, Color("dce7e5"))
	var delta := _label(root, "Delta", Rect2(36, 12, 50, 7), "ACC +0", 4, MUTED)
	var action := Button.new()
	action.name = "Action"
	action.flat = true
	action.position = Vector2.ZERO
	action.size = rect.size
	root.add_child(action)
	return {"root": root, "background": bg, "accent": accent, "image": image, "name": name, "delta": delta, "action": action}

func _select_slot(slot: String) -> void:
	selected_slot = slot
	page = 0
	_refresh()

func _options() -> PackedStringArray:
	var result := PackedStringArray([""])
	result.append_array(AttachmentCatalog.get_attachment_ids_for_slot(selected_slot, WeaponPlatformCatalog.get_platform(weapon_id)))
	return result

func _change_page(direction: int) -> void:
	var pages := maxi(1, ceili(float(_options().size()) / PARTS_PER_PAGE))
	page = posmod(page + direction, pages)
	_refresh_parts()

func _fit_part_row(row_index: int) -> void:
	var options := _options()
	var index := page * PARTS_PER_PAGE + row_index
	if index < 0 or index >= options.size(): return
	var attachment_id: String = options[index]
	var revised := build.duplicate()
	for existing in revised.duplicate():
		if str(AttachmentCatalog.get_attachment(existing).get("slot", "")) == selected_slot:
			revised.remove_at(revised.find(existing))
	if not attachment_id.is_empty():
		if revised.size() >= attachment_limit:
			_show_hint("HARDPOINT LIMIT %d // REMOVE A PART" % attachment_limit, Color("ff5577"))
			return
		revised.append(attachment_id)
	build = revised
	build_changed.emit(weapon_id, build.duplicate())
	_refresh()
	_show_hint("FACTORY CONFIGURATION" if attachment_id.is_empty() else "PART FITTED // " + str(AttachmentCatalog.get_attachment(attachment_id).name), CYAN)

func _equipped(slot: String) -> String:
	for attachment_id in build:
		if str(AttachmentCatalog.get_attachment(attachment_id).get("slot", "")) == slot: return attachment_id
	return ""

func _refresh() -> void:
	if not WeaponPlatformCatalog.has_weapon(weapon_id): return
	var platform := WeaponPlatformCatalog.get_platform(weapon_id)
	var data := AttackCatalog.get_gun_data(weapon_id, build)
	weapon_image.texture = ICONS.weapon_icon(weapon_id, build)
	weapon_name.text = data.display_name
	weapon_meta.text = "%s // %s" % [WeaponPlatformCatalog.CLASS_NAMES.get(str(platform.get("class", "")), "WEAPON"), data.caliber]
	build_count.text = "%d/%d HARDPOINTS" % [build.size(), attachment_limit]
	var comparison := WeaponStatResolver.compare(AttackCatalog.get_gun_data(weapon_id), data)
	var values := [comparison.accuracy, comparison.control, comparison.handling, comparison.mobility, comparison.capacity, comparison.noise]
	for index in stat_values.size():
		(stat_values[index] as Label).text = "%+d" % int(values[index])
		(stat_values[index] as Label).modulate = _delta_color(int(values[index]))
	for card in slot_cards:
		var slot: String = card.slot
		var equipped := _equipped(slot)
		(card.image as TextureRect).texture = ICONS.attachment_preview(equipped, slot)
		(card.equipped as Label).text = "FACTORY" if equipped.is_empty() else str(AttachmentCatalog.get_attachment(equipped).name)
		(card.background as ColorRect).color = OLIVE if slot == selected_slot else CARD
		(card.accent as ColorRect).color = ORANGE if not equipped.is_empty() else (CYAN if slot == selected_slot else Color("426169"))
	_refresh_parts()

func _refresh_parts() -> void:
	var options := _options()
	var pages := maxi(1, ceili(float(options.size()) / PARTS_PER_PAGE))
	page = clampi(page, 0, pages - 1)
	page_label.text = "%d/%d" % [page + 1, pages]
	slot_title.text = "AVAILABLE // " + str(AttachmentCatalog.SLOT_NAMES[selected_slot])
	var equipped := _equipped(selected_slot)
	for row_index in part_cards.size():
		var card := part_cards[row_index]
		var index := page * PARTS_PER_PAGE + row_index
		(card.root as Control).visible = index < options.size()
		if index >= options.size(): continue
		var attachment_id: String = options[index]
		var part := AttachmentCatalog.get_attachment(attachment_id)
		(card.image as TextureRect).texture = ICONS.attachment_preview(attachment_id, selected_slot)
		(card.name as Label).text = "REMOVE" if attachment_id.is_empty() else _short_part_name(str(part.name))
		(card.delta as Label).text = "FACTORY" if attachment_id.is_empty() else _part_delta(attachment_id)
		(card.action as Button).tooltip_text = "REMOVE CURRENT %s" % AttachmentCatalog.SLOT_NAMES[selected_slot] if attachment_id.is_empty() else str(part.summary)
		var installed := attachment_id == equipped
		(card.background as ColorRect).color = OLIVE if installed else (CARD if row_index % 2 == 0 else CARD_ALT)
		(card.accent as ColorRect).color = ORANGE if installed else CYAN

func _part_delta(attachment_id: String) -> String:
	var preview := build.duplicate()
	for existing in preview.duplicate():
		if str(AttachmentCatalog.get_attachment(existing).get("slot", "")) == selected_slot: preview.remove_at(preview.find(existing))
	preview.append(attachment_id)
	var delta := WeaponStatResolver.compare(AttackCatalog.get_gun_data(weapon_id), AttackCatalog.get_gun_data(weapon_id, preview))
	var pairs := [["ACC", int(delta.accuracy)], ["CTL", int(delta.control)], ["AIM", int(delta.handling)], ["SIG", int(delta.noise)], ["CAP", int(delta.capacity)]]
	var best: Array = pairs[0]
	for pair in pairs:
		if abs(int(pair[1])) > abs(int(best[1])): best = pair
	return "%s %+d" % [best[0], best[1]]

func _short_part_name(value: String) -> String:
	return value if value.length() <= 16 else value.substr(0, 15) + "."

func _stat_icon_kind(stat: String) -> String:
	return {"accuracy": "accuracy", "control": "damage", "handling": "mobility", "mobility": "mobility", "capacity": "magazine", "noise": "noise"}.get(stat, "accuracy")

func _delta_color(value: int) -> Color:
	if value > 0: return Color("73f7a4")
	if value < 0: return Color("ff6b75")
	return Color("c8d5d3")

func _show_hint(message: String, color: Color) -> void:
	hint.text = message
	hint.modulate = color

func _close() -> void:
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()

func _label(parent: Node, node_name: String, rect: Rect2, text: String, font_size: int, color: Color, alignment := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
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

func _button(parent: Node, node_name: String, rect: Rect2, text: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.position = rect.position
	button.size = rect.size
	button.text = text
	button.add_theme_font_size_override("font_size", 5)
	parent.add_child(button)
	return button

func _add_rect(parent: Node, node_name: String, rect: Rect2, color: Color) -> ColorRect:
	var item := ColorRect.new()
	item.name = node_name
	item.position = rect.position
	item.size = rect.size
	item.color = color
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(item)
	return item

func _frame(parent: Node, rect: Rect2, color: Color) -> void:
	_add_rect(parent, "FrameTop%d" % parent.get_child_count(), Rect2(rect.position, Vector2(rect.size.x, 1)), color)
	_add_rect(parent, "FrameBottom%d" % parent.get_child_count(), Rect2(rect.position + Vector2(0, rect.size.y - 1), Vector2(rect.size.x, 1)), color)
	_add_rect(parent, "FrameLeft%d" % parent.get_child_count(), Rect2(rect.position, Vector2(1, rect.size.y)), color)
	_add_rect(parent, "FrameRight%d" % parent.get_child_count(), Rect2(rect.position + Vector2(rect.size.x - 1, 0), Vector2(1, rect.size.y)), color)

func _style_flat_buttons() -> void:
	for node in find_children("*", "Button", true, false):
		var button := node as Button
		if button.flat:
			var empty := StyleBoxEmpty.new()
			button.add_theme_stylebox_override("normal", empty)
			button.add_theme_stylebox_override("hover", empty)
			button.add_theme_stylebox_override("pressed", empty)
