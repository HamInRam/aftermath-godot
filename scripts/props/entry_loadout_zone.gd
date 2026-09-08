class_name EntryLoadoutZone
extends Node2D

signal player_arrived

const PIXELS := preload("res://utility/pixel_art_painter.gd")

@export var activation_radius := 20.0
var player: Node2D
var active := true
var deployed := false
var waiting_for_exit := false
var pulse := 0.0

func setup(actor: Node2D) -> void:
	player = actor
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	pulse += delta
	if waiting_for_exit and is_instance_valid(player) and global_position.distance_to(player.global_position) > activation_radius + 6.0:
		waiting_for_exit = false
		active = true
	if active and is_instance_valid(player) and global_position.distance_to(player.global_position) <= activation_radius:
		active = false
		player_arrived.emit()
	queue_redraw()

func rearm_after_exit() -> void:
	active = false
	waiting_for_exit = true
	queue_redraw()

func set_deployed() -> void:
	deployed = true
	active = false
	queue_redraw()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.45)
	tween.tween_callback(queue_free)

func _draw() -> void:
	var flicker := 0.72 + sin(pulse * 5.0) * 0.18
	var cyan := Color(0.95, 0.95, 0.95, flicker)
	var dark := Color("171717")
	var metal := Color("909090")
	# A native-pixel field case positioned on the exterior side of the entry
	# threshold. It reads as equipment, not another extraction marker.
	PIXELS.rect(self, Rect2(-12, -7, 24, 14), dark)
	PIXELS.rect(self, Rect2(-11, -6, 22, 12), Color("333333"))
	PIXELS.line(self, Vector2(-11, -1), Vector2(11, -1), metal)
	PIXELS.line(self, Vector2(-3, -7), Vector2(3, -7), cyan)
	PIXELS.line(self, Vector2(-3, -6), Vector2(3, -6), cyan)
	# Two compact firearm silhouettes identify the purpose without a text sign.
	PIXELS.line(self, Vector2(-8, 2), Vector2(1, 2), Color("e4ece9"))
	PIXELS.line(self, Vector2(-5, 3), Vector2(-3, 5), Color("e4ece9"))
	PIXELS.line(self, Vector2(2, 3), Vector2(8, 3), Color("cccccc"))
	PIXELS.line(self, Vector2(4, 4), Vector2(5, 6), Color("cccccc"))
	if active:
		var corner := 14 + (floori(pulse * 4.0) & 1)
		PIXELS.pixel(self, Vector2(-corner, -9), cyan)
		PIXELS.pixel(self, Vector2(corner, -9), cyan)
		PIXELS.pixel(self, Vector2(-corner, 9), cyan)
		PIXELS.pixel(self, Vector2(corner, 9), cyan)
