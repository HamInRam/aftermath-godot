class_name CombatReticle
extends Control

const PIXEL_PAINTER := preload("res://utility/pixel_art_painter.gd")

var spread_ratio := 0.0
var combat_visible := true
var aim_state: Dictionary = {}
var focus_active := false
var _draw_signature: Array = []
var hit_marker_start_msec := 0
var hit_marker_deadline_msec := 0
var hit_marker_kind := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(48, 48)
	size = Vector2(48, 48)
	queue_redraw()

func _process(_delta: float) -> void:
	if hit_marker_deadline_msec > Time.get_ticks_msec():
		queue_redraw()
	elif hit_marker_deadline_msec > 0:
		hit_marker_deadline_msec = 0
		hit_marker_start_msec = 0
		hit_marker_kind = ""
		queue_redraw()

func show_hit_confirmation(kind: String, lethal := false) -> void:
	hit_marker_kind = "lethal" if lethal else kind
	if hit_marker_kind not in ["flesh", "armour", "head", "lethal"]: hit_marker_kind = "flesh"
	hit_marker_start_msec = Time.get_ticks_msec()
	var duration := 165 if lethal else (140 if hit_marker_kind == "head" else (125 if hit_marker_kind == "armour" else 110))
	hit_marker_deadline_msec = hit_marker_start_msec + duration
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
		roundi(3.0 + spread_pixels * 0.45),
		bool(state.get("blocked", false)),
		clampi(int(state.get("ammo", 1)), 0, 3),
		bool(state.get("reloading", false)),
		roundi(clampf(float(state.get("reload_progress", 0.0)), 0.0, 1.0) * 12.0),
		bool(state.get("targeted", false)),
		bool(state.get("targeting_mode", false)),
		str(state.get("target_kind", "")),
		bool(state.get("precision_primed", false)),
		Settings.reticle_hud_enabled,
		focus_active,
	]
	combat_visible = enabled
	visible = enabled
	if signature == _draw_signature: return
	_draw_signature = signature
	aim_state = state.duplicate()
	aim_state["actual_offset"] = actual_offset
	queue_redraw()

func set_focus_active(active: bool) -> void:
	if focus_active == active: return
	focus_active = active
	_draw_signature = []
	queue_redraw()

func _draw() -> void:
	if not combat_visible: return
	var center := (size * 0.5).round()
	var actual_offset: Vector2 = aim_state.get("actual_offset", Vector2.ZERO)
	var actual_center := (center + actual_offset.limit_length(8.0)).round()
	var spread_pixels := clampf(float(aim_state.get("spread_pixels", spread_ratio * 6.0)), 0.0, 9.0)
	var gap := float(roundi(3.0 + spread_pixels * 0.45))
	var blocked := bool(aim_state.get("blocked", false))
	var ammo := int(aim_state.get("ammo", 1))
	var reloading := bool(aim_state.get("reloading", false))
	var color := Color("ffffff") if ammo > 0 else Color("a0a0a0")
	if blocked: color = NeonPalette.BLOOD_CRIMSON
	# One strong cross, not a second lagging cursor, target bracket, ammo ring,
	# focus frame and targeting frame competing over the same silhouette.
	PIXEL_PAINTER.pixel(self, center, Color.WHITE)
	if blocked:
		_stroke(actual_center + Vector2(-3, -3), actual_center + Vector2(3, 3), color)
		_stroke(actual_center + Vector2(-3, 3), actual_center + Vector2(3, -3), color)
	else:
		for axis in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			_stroke(actual_center + axis * gap, actual_center + axis * (gap + 7.0), color)
	if Settings.reticle_hud_enabled and reloading:
		var progress := clampf(float(aim_state.get("reload_progress", 0.0)), 0.0, 1.0)
		_stroke(center + Vector2(-6, 18), center + Vector2(6, 18), Color("4c4c4c"))
		PIXEL_PAINTER.line(self, center + Vector2(-6, 18), center + Vector2(-6 + roundi(12.0 * progress), 18), Color.WHITE)
	elif Settings.reticle_hud_enabled and ammo <= 3:
		for index in range(3):
			var pip := Color.WHITE if index < ammo else Color("4c4c4c")
			_stroke(center + Vector2(-4 + index * 3, 17), center + Vector2(-3 + index * 3, 17), pip)
	if hit_marker_deadline_msec > Time.get_ticks_msec():
		_draw_hit_marker(actual_center)

func _stroke(start: Vector2, end: Vector2, color: Color) -> void:
	# A one-pixel dark keyline keeps the native white cross legible on pale stone.
	for offset in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		PIXEL_PAINTER.line(self, start + offset, end + offset, Color("080808"))
	PIXEL_PAINTER.line(self, start, end, color)

func _draw_hit_marker(center: Vector2) -> void:
	var now := Time.get_ticks_msec()
	var duration := maxi(1, hit_marker_deadline_msec - hit_marker_start_msec)
	var progress := clampf(float(now - hit_marker_start_msec) / float(duration), 0.0, 1.0)
	var alpha := 1.0 - smoothstep(0.66, 1.0, progress)
	var marker_color := Color("ffffff")
	var radius := lerpf(8.0, 5.0, progress)
	if hit_marker_kind == "armour":
		marker_color = Color("f4f4f4")
		radius = lerpf(9.0, 6.0, progress)
	elif hit_marker_kind == "head":
		marker_color = Color("ffffff")
		radius = lerpf(9.0, 5.0, progress)
	elif hit_marker_kind == "lethal":
		marker_color = Color("ff315c")
		radius = lerpf(6.0, 9.0, progress / 0.24) if progress < 0.24 else lerpf(9.0, 5.0, (progress - 0.24) / 0.76)
	marker_color.a = alpha
	_draw_marker_x(center, radius, marker_color, hit_marker_kind == "lethal")
	if hit_marker_kind == "armour":
		_draw_marker_x(center, radius + 2.0, Color(marker_color, alpha * 0.45), false)
		for point in [Vector2(0, -2), Vector2(2, 0), Vector2(0, 2), Vector2(-2, 0)]: PIXEL_PAINTER.pixel(self, center + point, marker_color)
	elif hit_marker_kind == "head":
		var head_color := Color(NeonPalette.BLOOD_CRIMSON, alpha)
		PIXEL_PAINTER.line(self, center + Vector2(-2, -radius - 2), center + Vector2(0, -radius - 4), head_color)
		PIXEL_PAINTER.line(self, center + Vector2(0, -radius - 4), center + Vector2(2, -radius - 2), head_color)

func _draw_marker_x(center: Vector2, radius: float, color: Color, thick: bool) -> void:
	for sign_x in [-1.0, 1.0]:
		for sign_y in [-1.0, 1.0]:
			var outer := center + Vector2(sign_x, sign_y) * radius
			var inner := center + Vector2(sign_x, sign_y) * maxf(1.0, radius - 3.0)
			PIXEL_PAINTER.line(self, inner, outer, color)
			if thick: PIXEL_PAINTER.line(self, inner + Vector2(0, sign_y), outer + Vector2(0, sign_y), Color(color, color.a * 0.72))
