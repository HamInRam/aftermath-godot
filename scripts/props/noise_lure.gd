class_name NoiseLure
extends Node2D

const PIXELS := preload("res://utility/pixel_art_painter.gd")

var spent := false
var activation_radius := 180.0

func _ready() -> void:
	add_to_group("noise_lure")
	queue_redraw()

func activate() -> bool:
	if spent: return false
	spent = true
	Events.publish_combat_noise(global_position, activation_radius, "environment_lure")
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.6, 0.35, 0.25, 1.0), 0.06)
	tween.tween_property(self, "modulate", Color(0.42, 0.38, 0.4, 1.0), 0.2)
	queue_redraw()
	return true

func get_interaction_prompt() -> String:
	return "" if spent else "[ E ] TRIGGER NOISE LURE"

func _draw() -> void:
	var body_color := Color("544d52") if spent else Color("ef385f")
	PIXELS.material_panel(self, Rect2(-3, -6, 6, 12), Color("17131b"), body_color, body_color.lightened(0.2), body_color.darkened(0.25), 23, &"metal")
	PIXELS.material_panel(self, Rect2(-2, -8, 4, 3), Color("17131b"), Color("e8d8bf"), Color("fff4de"), Color("a89483"), 24, &"grain")
	PIXELS.line(self, Vector2(1, -7), Vector2(5, -5), Color("322a32"))
