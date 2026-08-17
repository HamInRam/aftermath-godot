extends Node2D

var radius := 30.0
var arc_angle := PI * 0.5
var trail_color := Color.WHITE
var life := 0.14
var age := 0.0
var effect_type := "fist"
var punch_jitter := 0.0
var air_motes: Array[Dictionary] = []

func _ready() -> void:
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive

func setup(new_type: String, new_radius: float, new_arc_angle: float, new_life: float, new_color: Color) -> void:
	effect_type = new_type
	radius = new_radius
	arc_angle = new_arc_angle
	life = new_life
	trail_color = new_color
	punch_jitter = randf_range(-1.0, 1.0)
	air_motes.clear()
	var mote_count := 1 if effect_type == "knife" else (3 if effect_type == "bat" else 0)
	for index in range(mote_count):
		var t := randf_range(0.35, 1.0)
		var angle := lerpf(-arc_angle * 0.5, arc_angle * 0.5, t)
		air_motes.append({
			"origin": Vector2.RIGHT.rotated(angle) * radius * randf_range(0.72, 1.0),
			"velocity": Vector2.RIGHT.rotated(angle + randf_range(-0.12, 0.12)) * randf_range(12.0, 24.0),
			"size": 1.0 if effect_type == "knife" else randf_range(1.0, 2.0),
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
		draw_line(visual_offset + Vector2(0, -3), visual_offset + Vector2(radius, -3 + punch_jitter), punch_color, 1.0)
		draw_line(visual_offset + Vector2(0, 3), visual_offset + Vector2(radius, 3 - punch_jitter), punch_color, 1.0)
	elif effect_type == "knife":
		var knife_color := Color(trail_color, alpha * 0.90)
		var knife_points := PackedVector2Array()
		for index in range(7):
			var t := float(index) / 6.0
			var angle := lerpf(start_angle, end_angle, t)
			var dynamic_radius := radius * (0.85 + t * 0.15)
			knife_points.append(visual_offset + Vector2.RIGHT.rotated(angle) * dynamic_radius)
		draw_polyline(knife_points, knife_color, 2.0)
	else:
		var bat_points := PackedVector2Array()
		for index in range(13):
			var t := float(index) / 12.0
			var angle := lerpf(start_angle, end_angle, t)
			var bulge := minf(2.0, radius * 0.18)
			var dynamic_radius := radius - bulge + sin(t * PI) * bulge
			bat_points.append(visual_offset + Vector2.RIGHT.rotated(angle) * dynamic_radius)
		draw_polyline(bat_points, Color(trail_color, alpha * 0.35), 6.0)
		draw_polyline(bat_points, Color(trail_color, alpha * 0.80), 1.5)
	_draw_air_motes(alpha)

func _draw_air_motes(alpha: float) -> void:
	for mote in air_motes:
		var position: Vector2 = mote.origin + mote.velocity * age
		var mote_color := Color(trail_color, alpha * (0.72 if effect_type == "knife" else 0.46))
		if effect_type == "knife":
			draw_line(position - mote.velocity.normalized() * 3.0, position, mote_color, 1.0)
		else:
			draw_rect(Rect2(position, Vector2(mote.size, mote.size)), mote_color)
