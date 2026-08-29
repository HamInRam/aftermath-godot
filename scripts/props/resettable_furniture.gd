class_name ResettableFurniture
extends Node2D

var restored := false
var crooked_rotation := 0.0

func setup(angle: float) -> void:
	crooked_rotation = angle
	rotation = angle
	add_to_group("resettable_furniture")
	queue_redraw()

func interact() -> bool:
	if restored: return false
	restored = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "rotation", 0.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate", Color(0.65, 1.0, 0.82), 0.12)
	return true

func get_interaction_prompt() -> String:
	return "" if restored else "[ E ] RESTORE FURNITURE"

func _draw() -> void:
	var color := Color("657078") if restored else Color("a55745")
	draw_rect(Rect2(-6, -3, 12, 6), color)
	draw_rect(Rect2(-5, -2, 10, 2), Color("2a2228"))
