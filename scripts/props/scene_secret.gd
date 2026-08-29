class_name SceneSecret
extends Node2D

var secret_type := "clue"
var resolved := false

func setup(kind: String) -> void:
	secret_type = kind
	add_to_group("scene_secret")
	queue_redraw()

func interact(steal := false) -> Dictionary:
	if resolved: return {}
	resolved = true
	queue_free()
	return {"type": secret_type, "stolen": steal and secret_type == "valuable", "value": 140 if secret_type == "valuable" else 90}

func get_interaction_prompt() -> String:
	if secret_type == "valuable": return "[ E ] SECURE VALUABLE // [ SHIFT+E ] POCKET IT"
	return "[ E ] COLLECT CASE CLUE"

func _draw() -> void:
	var color := Color("ffd35a") if secret_type == "valuable" else Color("65f7ff")
	draw_rect(Rect2(-3, -2, 6, 4), Color(color, 0.72))
	draw_line(Vector2(-2, 0), Vector2(2, 0), Color.WHITE, 1.0)
