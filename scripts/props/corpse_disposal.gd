class_name CorpseDisposal
extends Node2D

var disposal_type := "dumpster"
var capacity := 2
var used := 0
var active := false
var noise_radius := 80.0

func setup(kind: String, max_bodies: int) -> void:
	disposal_type = kind
	capacity = maxi(1, max_bodies)
	noise_radius = 125.0 if kind == "incinerator" else 72.0
	add_to_group("corpse_disposal")
	queue_redraw()

func set_active(enabled: bool) -> void:
	active = enabled
	queue_redraw()

func can_accept() -> bool:
	return active and used < capacity

func dispose(corpse: Node2D) -> bool:
	if not can_accept() or not is_instance_valid(corpse) or not corpse.has_method("is_bagged") or not corpse.is_bagged(): return false
	used += 1
	Events.publish_combat_noise(global_position, noise_radius, "corpse_disposal")
	corpse.extract_bag()
	queue_redraw()
	return true

func get_interaction_prompt() -> String:
	if not active: return ""
	if used >= capacity: return "%s FULL" % disposal_type.to_upper()
	return "[ E ] DISPOSE BODY // %s %d/%d" % [disposal_type.to_upper(), used, capacity]

func _draw() -> void:
	var color := Color("e06a36") if disposal_type == "incinerator" else Color("477c70")
	draw_rect(Rect2(-8, -5, 16, 10), Color(color, 0.9 if active else 0.45))
	draw_rect(Rect2(-7, -4, 14, 2), Color("1e2527"))
	if active: draw_arc(Vector2.ZERO, 10.0, 0.0, TAU, 20, Color(color, 0.5), 1.0)
