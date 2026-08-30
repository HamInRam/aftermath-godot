class_name CombatReticle
extends Control

const PIXEL_PAINTER := preload("res://utility/pixel_art_painter.gd")

var spread_ratio := 0.0
var combat_visible := true
var aim_state: Dictionary = {}
var _draw_signature: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(32, 32)
	size = Vector2(32, 32)
	queue_redraw()

func set_feedback(ratio: float, enabled: bool) -> void:
	var next_ratio := clampf(ratio, 0.0, 1.0)
	if is_equal_approx(next_ratio, spread_ratio) and enabled == combat_visible: return
	spread_ratio = next_ratio
	combat_visible = enabled
	visible = enabled
	aim_state = {"spread_pixels": next_ratio * 6.0}
	queue_redraw()

func set_aim_feedback(state: Dictionary, enabled: bool) -> void:
	var actual_offset: Vector2 = state.get("actual_offset", Vector2.ZERO)
	actual_offset = actual_offset.limit_length(8.0).round()
	var spread_pixels := clampf(float(state.get("spread_pixels", spread_ratio * 6.0)), 0.0, 9.0)
	# Only values that alter painted pixels belong in the signature. Cursor motion
	# moves this Control directly and no longer forces the reticle to repaint.
	var signature: Array = [
		enabled,
		actual_offset,
		roundi(2.0 + spread_pixels),
		bool(state.get("blocked", false)),
		clampi(int(state.get("ammo", 1)), 0, 3),
		bool(state.get("reloading", false)),
		roundi(clampf(float(state.get("reload_progress", 0.0)), 0.0, 1.0) * 12.0),
		bool(state.get("targeted", false)),
		bool(state.get("precision_primed", false)),
		Settings.reticle_hud_enabled,
	]
	combat_visible = enabled
	visible = enabled
	if signature == _draw_signature: return
	_draw_signature = signature
	aim_state = state.duplicate()
	aim_state["actual_offset"] = actual_offset
	queue_redraw()

func _draw() -> void:
	if not combat_visible: return
	var center := (size * 0.5).round()
	var actual_offset: Vector2 = aim_state.get("actual_offset", Vector2.ZERO)
	actual_offset = actual_offset.limit_length(8.0)
	var actual_center := (center + actual_offset).round()
	var spread_pixels := clampf(float(aim_state.get("spread_pixels", spread_ratio * 6.0)), 0.0, 9.0)
	var gap := float(roundi(2.0 + spread_pixels))
	var blocked := bool(aim_state.get("blocked", false))
	var empty := int(aim_state.get("ammo", 1)) <= 0
	var reloading := bool(aim_state.get("reloading", false))
	var targeted := bool(aim_state.get("targeted", false))
	var primed := bool(aim_state.get("precision_primed", false))
	var color := Color("73f7e4").lerp(Color("ffcf66"), clampf(spread_pixels / 9.0, 0.0, 1.0))
	if targeted: color = Color("ffe56b")
	if primed: color = Color("ff68c8")
	if empty: color = Color("b99aa8")
	if blocked: color = Color("ff536e")
	# The tiny center point is player intent. The four ticks are the weapon's
	# actual ballistic solution and visibly catch up after a fast flick.
	PIXEL_PAINTER.pixel(self, center, Color("e8ffff"))
	if actual_offset.length() > 1.25: PIXEL_PAINTER.line(self, center, actual_center, Color(color, 0.34))
	if blocked:
		PIXEL_PAINTER.line(self, actual_center + Vector2(-3, -3), actual_center + Vector2(3, 3), color)
		PIXEL_PAINTER.line(self, actual_center + Vector2(-3, 3), actual_center + Vector2(3, -3), color)
	else:
		PIXEL_PAINTER.line(self, actual_center + Vector2(-gap - 2.0, 0), actual_center + Vector2(-gap, 0), color)
		PIXEL_PAINTER.line(self, actual_center + Vector2(gap, 0), actual_center + Vector2(gap + 2.0, 0), color)
		PIXEL_PAINTER.line(self, actual_center + Vector2(0, -gap - 2.0), actual_center + Vector2(0, -gap), color)
		PIXEL_PAINTER.line(self, actual_center + Vector2(0, gap), actual_center + Vector2(0, gap + 2.0), color)
	if reloading:
		var progress := clampf(float(aim_state.get("reload_progress", 0.0)), 0.0, 1.0)
		PIXEL_PAINTER.arc(self, actual_center, 8, -PI * 0.5, -PI * 0.5 + TAU * progress, Color("82d8ff"), 12)
	if Settings.reticle_hud_enabled:
		var ammo := clampi(int(aim_state.get("ammo", 0)), 0, 3)
		for index in range(3):
			var pip_color := Color("ffe5a8") if index < ammo else Color(0.24, 0.2, 0.25, 0.75)
			PIXEL_PAINTER.line(self, center + Vector2(-4 + index * 3, 11), center + Vector2(-3 + index * 3, 11), pip_color)
	if primed:
		PIXEL_PAINTER.line(self, actual_center + Vector2(-2, -10), actual_center + Vector2(0, -12), color)
		PIXEL_PAINTER.line(self, actual_center + Vector2(0, -12), actual_center + Vector2(2, -10), color)
