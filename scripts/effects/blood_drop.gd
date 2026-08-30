class_name BloodDrop
extends Node2D

const PIXEL_PAINTER := preload("res://utility/pixel_art_painter.gd")

var amount := 1.0
var elongated := false
var spread_multiplier := 1.0
var darken := 0.0
var cleanup_cost := 2
var cleanup_steps_remaining := 2

func _ready() -> void:
	CleanupRegistry.register_target(self)
	add_to_group("blood_source")
	add_to_group("micro_blood_drop")

func setup(strength: float, direction := Vector2.RIGHT, surface_profile := {}) -> void:
	amount = clampf(strength, 0.2, 1.0)
	elongated = direction.length_squared() > 0.2
	rotation = snappedf(direction.angle(), PI / 4.0)
	spread_multiplier = float(surface_profile.get("spread", 1.0))
	darken = float(surface_profile.get("darken", 0.0))
	cleanup_cost = int(surface_profile.get("cleanup", 2))
	cleanup_steps_remaining = cleanup_cost
	queue_redraw()

func clean_step() -> void:
	cleanup_steps_remaining = maxi(0, cleanup_steps_remaining - 1)
	if cleanup_steps_remaining == 0:
		CleanupRegistry.unregister_target(self)
		queue_free()
	else:
		amount = float(cleanup_steps_remaining) / float(cleanup_cost)
		queue_redraw()

func absorb_drop(strength: float, direction: Vector2) -> void:
	amount = clampf(amount + strength * 0.28, 0.2, 1.0)
	cleanup_steps_remaining = mini(cleanup_cost + 1, maxi(cleanup_steps_remaining, cleanup_cost))
	if direction.length_squared() > 0.2:
		elongated = true
		rotation = snappedf(lerp_angle(rotation, direction.angle(), 0.35), PI / 4.0)
	queue_redraw()

func get_cleanup_progress() -> float:
	return 1.0 - float(cleanup_steps_remaining) / maxf(1.0, float(cleanup_cost))

func get_cleanup_type() -> String: return "blood"
func get_cleanup_cost() -> int: return cleanup_cost

func _draw() -> void:
	var color := Color(0.48, 0.003, 0.025, 0.86 * amount).darkened(darken)
	var length := clampi(roundi(2.0 + spread_multiplier), 2, 4)
	if elongated: PIXEL_PAINTER.line(self, Vector2(-length, 0), Vector2(length, 0), color)
	PIXEL_PAINTER.pixel(self, Vector2.ZERO, color)
	if amount > 0.55: PIXEL_PAINTER.pixel(self, Vector2(0, 1), color.darkened(0.12))
