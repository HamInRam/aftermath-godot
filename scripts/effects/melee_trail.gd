extends Node2D

const PIXEL_PAINTER := preload("res://utility/pixel_art_painter.gd")

var radius := 30.0
var arc_angle := PI * 0.5
var trail_color := Color.WHITE
var life := 0.14
var age := 0.0
var effect_type := "fist"
var punch_jitter := 0.0
var air_motes: Array[Dictionary] = []
var connected_hit := false

func _ready() -> void:
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive

func setup(new_type: String, new_radius: float, new_arc_angle: float, new_life: float, new_color: Color, did_hit := false) -> void:
	effect_type = new_type
	radius = new_radius
	arc_angle = new_arc_angle
	life = new_life
	trail_color = new_color
	connected_hit = did_hit
	punch_jitter = randf_range(-1.0, 1.0)
	air_motes.clear()
	var mote_count := 1 if effect_type == "knife" else (3 if effect_type == "bat" else 0)
	for index in range(mote_count):
		var t := randf_range(0.35, 1.0)
		var angle := lerpf(-arc_angle * 0.5, arc_angle * 0.5, t)
		air_motes.append({
			"origin": (Vector2.RIGHT.rotated(angle) * radius * randf_range(0.72, 1.0)).round(),
			"velocity": Vector2.RIGHT.rotated(angle + randf_range(-0.12, 0.12)) * randf_range(12.0, 24.0),
			"size": 1,
		})
	queue_redraw()

func _process(delta: float) -> void:
	age += delta
	if age >= life:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var alpha := 1.0 - age / life
	var start_angle := -arc_angle * 0.5
	var end_angle := arc_angle * 0.5
	var visual_offset := Vector2.ZERO
	if effect_type == "fist":
		var punch_color := Color(trail_color, alpha * 0.25)
		PIXEL_PAINTER.line(self, visual_offset + Vector2(0, -3), visual_offset + Vector2(roundi(radius), -3 + roundi(punch_jitter)), punch_color)
		PIXEL_PAINTER.line(self, visual_offset + Vector2(0, 3), visual_offset + Vector2(roundi(radius), 3 - roundi(punch_jitter)), punch_color)
	elif effect_type == "knife":
		var knife_base := trail_color.lerp(Color("ff244f"), 0.42) if connected_hit else trail_color
		var knife_color := Color(knife_base, alpha * 0.90)
		var knife_points := PackedVector2Array()
		for index in range(7):
			var t := float(index) / 6.0
			var angle := lerpf(start_angle, end_angle, t)
			var dynamic_radius := radius * (0.85 + t * 0.15)
			knife_points.append((visual_offset + Vector2.RIGHT.rotated(angle) * dynamic_radius).round())
		PIXEL_PAINTER.polyline(self, knife_points, knife_color)
		PIXEL_PAINTER.pixel(self, knife_points[-1], Color(knife_color, alpha))
	else:
		var bat_base := trail_color.lerp(Color("ff3d45"), 0.28) if connected_hit else trail_color
		var bat_points := PackedVector2Array()
		for index in range(13):
			var t := float(index) / 12.0
			var angle := lerpf(start_angle, end_angle, t)
			var bulge := minf(2.0, radius * 0.18)
			var dynamic_radius := radius - bulge + sin(t * PI) * bulge
			bat_points.append((visual_offset + Vector2.RIGHT.rotated(angle) * dynamic_radius).round())
		PIXEL_PAINTER.polyline(self, bat_points, Color(bat_base, alpha * 0.80))
		var echo := PackedVector2Array()
		for point in bat_points: echo.append(point + Vector2(0, 1))
		PIXEL_PAINTER.polyline(self, echo, Color(bat_base, alpha * 0.34))
	_draw_air_motes(alpha)

func _draw_air_motes(alpha: float) -> void:
	for mote in air_motes:
		var position: Vector2 = (mote.origin + mote.velocity * age).round()
		var mote_color := Color(trail_color, alpha * (0.72 if effect_type == "knife" else 0.46))
		if effect_type == "knife":
			PIXEL_PAINTER.line(self, position - (mote.velocity.normalized() * 3.0).round(), position, mote_color)
		else:
			PIXEL_PAINTER.pixel(self, position, mote_color)
