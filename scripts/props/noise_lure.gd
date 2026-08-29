class_name NoiseLure
extends Node2D

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
	draw_rect(Rect2(-3, -6, 6, 12), body_color)
	draw_rect(Rect2(-2, -8, 4, 3), Color("e8d8bf"))
	draw_line(Vector2(1, -7), Vector2(5, -5), Color("322a32"), 1.0)
