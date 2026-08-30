class_name WorldContextMarker
extends Node2D

const PIXEL_ICONS := preload("res://utility/pixel_icon_factory.gd")
const PIXEL_PAINTER := preload("res://utility/pixel_art_painter.gd")

var icon := Sprite2D.new()
var ring_progress := -1.0
var pulse := 0.0

func _ready() -> void:
	z_index = 90
	icon.position = Vector2(0, -11)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(icon)
	visible = false

func show_target(world_position: Vector2, kind: String, color: Color, progress := -1.0) -> void:
	global_position = world_position
	icon.texture = PIXEL_ICONS.make(kind, color)
	ring_progress = progress
	pulse = 1.0
	visible = true
	queue_redraw()

func hide_target() -> void:
	visible = false

func _process(delta: float) -> void:
	if not visible: return
	pulse = maxf(0.0, pulse - delta * 4.0)
	icon.position.y = -11 + roundi(sin(Time.get_ticks_msec() * 0.008))
	icon.scale = Vector2.ONE
	queue_redraw()

func _draw() -> void:
	if ring_progress < 0.0: return
	PIXEL_PAINTER.arc(self, Vector2(0, -11), 6, -PI * 0.5, -PI * 0.5 + TAU * clampf(ring_progress, 0.0, 1.0), Color("73f7e4"), 12)
