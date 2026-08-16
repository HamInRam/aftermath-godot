class_name UIDefaults
extends RefCounted

const SMALL_FONT_SIZE := 6
const BODY_FONT_SIZE := 7
const HEADING_FONT_SIZE := 9
const TEXT_COLOR := Color("f4edf2")
const MUTED_COLOR := Color("a697a4")
const ACCENT_COLOR := Color("ff3d78")

static func apply_label(label: Label, size := BODY_FONT_SIZE, color := TEXT_COLOR) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 1)
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.05, 0.9))
