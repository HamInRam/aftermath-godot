class_name UIDefaults
extends RefCounted

const SMALL_FONT_SIZE := 6
const BODY_FONT_SIZE := 7
const HEADING_FONT_SIZE := 9
const TEXT_COLOR := Color("e4e1d8")
const MUTED_COLOR := Color("92989a")
const ACCENT_COLOR := Color("c43864")

static func apply_label(label: Label, size := BODY_FONT_SIZE, color := TEXT_COLOR) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 1)
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.05, 0.9))

static func apply_button(button: Button) -> void:
	button.add_theme_color_override("font_color", TEXT_COLOR)
	button.add_theme_color_override("font_hover_color", Color("f0d7a7"))
	button.add_theme_color_override("font_focus_color", Color("f0d7a7"))
	button.add_theme_color_override("font_pressed_color", Color("71bcb5"))
	button.add_theme_color_override("font_disabled_color", Color("665a68"))
	button.add_theme_constant_override("icon_max_width", 8)
	button.add_theme_constant_override("h_separation", 5)
	button.add_theme_constant_override("outline_size", 1)
	button.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.05, 0.95))
	button.focus_mode = Control.FOCUS_ALL
	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = Color(0.12, 0.48, 0.50, 0.28)
	focus_style.border_width_left = 2
	focus_style.border_color = Color("73f7e4")
	focus_style.content_margin_left = 5.0
	button.add_theme_stylebox_override("focus", focus_style)
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(0.55, 0.08, 0.28, 0.18)
	hover_style.border_width_left = 1
	hover_style.border_color = Color("ff3d78")
	hover_style.content_margin_left = 5.0
	button.add_theme_stylebox_override("hover", hover_style)

static func decorate_buttons(root: Node) -> void:
	for node in root.find_children("*", "Button", true, false):
		apply_button(node as Button)
	for node in root.find_children("*", "HSlider", true, false):
		apply_pixel_slider(node as HSlider)
	for node in root.find_children("*", "CheckButton", true, false):
		apply_pixel_check(node as CheckButton)

static func apply_pixel_slider(slider: HSlider) -> void:
	var rail := StyleBoxFlat.new()
	rail.bg_color = Color("201a25")
	rail.border_width_top = 1
	rail.border_width_bottom = 1
	rail.border_color = Color("524657")
	rail.content_margin_top = 2
	rail.content_margin_bottom = 2
	var filled := rail.duplicate() as StyleBoxFlat
	filled.bg_color = Color("24515a")
	filled.border_color = Color("73f7e4")
	slider.add_theme_stylebox_override("slider", rail)
	slider.add_theme_stylebox_override("grabber_area", filled)
	slider.add_theme_stylebox_override("grabber_area_highlight", filled)
	var grabber := _pixel_texture(["111", "101", "111"], Color("e4e1d8"))
	var active := _pixel_texture(["111", "111", "111"], Color("73f7e4"))
	slider.add_theme_icon_override("grabber", grabber)
	slider.add_theme_icon_override("grabber_highlight", active)
	slider.add_theme_icon_override("grabber_disabled", _pixel_texture(["111", "101", "111"], Color("665a68")))
	slider.custom_minimum_size.y = 7

static func apply_pixel_check(check: CheckButton) -> void:
	check.add_theme_icon_override("unchecked", _pixel_texture(["11111", "10001", "10001", "11111"], Color("92989a")))
	check.add_theme_icon_override("checked", _pixel_texture(["11111", "10101", "11011", "11111"], Color("73f7e4")))
	check.add_theme_icon_override("unchecked_disabled", _pixel_texture(["11111", "10001", "10001", "11111"], Color("514a55")))
	check.add_theme_icon_override("checked_disabled", _pixel_texture(["11111", "10101", "11011", "11111"], Color("514a55")))

static func _pixel_texture(rows: Array[String], color: Color) -> ImageTexture:
	var width := rows[0].length() if not rows.is_empty() else 1
	var image := Image.create(width, maxi(1, rows.size()), false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in range(rows.size()):
		for x in range(rows[y].length()):
			if rows[y][x] == "1": image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)

static func animate_screen_intro(panel: Control) -> void:
	if not is_instance_valid(panel): return
	panel.pivot_offset = panel.size * 0.5
	panel.modulate.a = 0.0
	panel.scale = Vector2.ONE
	var tween := panel.create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

static func pulse_control(control: Control, color := Color("73f7e4")) -> void:
	if not is_instance_valid(control): return
	control.modulate = color
	control.scale = Vector2.ONE
	var tween := control.create_tween()
	tween.tween_property(control, "modulate", Color.WHITE, 0.18)
