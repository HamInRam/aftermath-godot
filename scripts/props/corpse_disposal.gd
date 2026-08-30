class_name CorpseDisposal
extends Node2D

const PIXELS := preload("res://utility/pixel_art_painter.gd")

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
	var body := Color(color, 0.9 if active else 0.45)
	PIXELS.material_panel(self, Rect2(-8, -5, 16, 10), Color("17131b"), body, body.lightened(0.18), body.darkened(0.28), 22, &"metal")
	PIXELS.line(self, Vector2(-6, -3), Vector2(5, -3), Color("1e2527"))
	for x in range(-5, 6, 4): PIXELS.pixel(self, Vector2(x, 2), color.lightened(0.25))
	if active: PIXELS.circle(self, Vector2.ZERO, 10, Color(color, 0.5), true)
