class_name PropRestorationAnchor
extends Node2D

const PIXELS := preload("res://utility/pixel_art_painter.gd")

var prop_size := Vector2(8, 8)
var prop_kind := "object"
var accent := Color("73f7e4")
var restoration_needed := false
var cleanup_active := false
var pulse_time := 0.0

func setup(size: Vector2, kind: String, tint: Color) -> void:
	prop_size = size
	prop_kind = kind
	accent = tint
	z_index = 1
	add_to_group("prop_restoration_anchor")
	visible = false
	set_process(false)
	queue_redraw()

func mark_needed() -> void:
	restoration_needed = true
	_refresh_visibility()

func set_cleanup_active(active: bool) -> void:
	cleanup_active = active
	_refresh_visibility()

func mark_restored() -> void:
	restoration_needed = false
	_refresh_visibility()

func _refresh_visibility() -> void:
	visible = cleanup_active and restoration_needed
	set_process(visible)
	if visible: queue_redraw()

func _process(delta: float) -> void:
	pulse_time += delta
	# Deliberately redraw at eight steps per second; the outline reads as a game
	# affordance without adding a full-rate animated effect to every prop slot.
	if int((pulse_time - delta) * 8.0) != int(pulse_time * 8.0): queue_redraw()

func _draw() -> void:
	if not restoration_needed: return
	var half := prop_size * 0.5
	var pulse := 0.32 + float(posmod(int(pulse_time * 8.0), 4)) * 0.06
	var ghost := Color(accent.lerp(Color("73f7e4"), 0.68), pulse)
	var edge := Color("a9fff3", minf(0.78, pulse + 0.28))
	PIXELS.stipple_rect(self, Rect2(-half, prop_size), ghost, 3, 3)
	PIXELS.line(self, Vector2(-half.x, -half.y), Vector2(half.x - 1, -half.y), edge)
	PIXELS.line(self, Vector2(-half.x, half.y - 1), Vector2(half.x - 1, half.y - 1), edge)
	PIXELS.line(self, Vector2(-half.x, -half.y), Vector2(-half.x, half.y - 1), edge)
	PIXELS.line(self, Vector2(half.x - 1, -half.y), Vector2(half.x - 1, half.y - 1), edge)
	# Four bright corner pixels make the exact snap footprint readable even on
	# patterned floors and beneath blood evidence.
	for point in [Vector2(-half.x, -half.y), Vector2(half.x - 1, -half.y), Vector2(-half.x, half.y - 1), Vector2(half.x - 1, half.y - 1)]:
		PIXELS.pixel(self, point, edge)
