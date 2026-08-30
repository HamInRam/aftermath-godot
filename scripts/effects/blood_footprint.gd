class_name BloodFootprint
extends Node2D

const PIXEL_PAINTER := preload("res://utility/pixel_art_painter.gd")

var blood_amount := 1.0
var left_foot := true
var cleanup_steps_remaining := 2
var surface_spread := 1.0
var surface_darken := 0.0
var smudged := false

func _ready() -> void:
	CleanupRegistry.register_target(self)
	queue_redraw()

func setup(strength: float, is_left_foot: bool, surface_profile := {}, is_smudged := false) -> void:
	blood_amount = clampf(strength, 0.18, 1.0)
	left_foot = is_left_foot
	cleanup_steps_remaining = get_cleanup_cost()
	surface_spread = clampf(float(surface_profile.get("spread", 1.0)), 0.78, 1.45)
	surface_darken = float(surface_profile.get("darken", 0.0))
	smudged = is_smudged
	queue_redraw()

func clean_step() -> void:
	cleanup_steps_remaining = maxi(0, cleanup_steps_remaining - 1)
	if cleanup_steps_remaining == 0:
		CleanupRegistry.unregister_target(self)
		queue_free()
		return
	blood_amount *= 0.45
	queue_redraw()

func get_cleanup_type() -> String:
	return "blood_footprint"

func get_cleanup_cost() -> int:
	return 2

func get_cleanup_progress() -> float:
	return 1.0 - float(cleanup_steps_remaining) / float(get_cleanup_cost())

func _draw() -> void:
	var blood := Color(0.47, 0.004, 0.025, 0.88 * blood_amount).darkened(surface_darken)
	var dark_blood := Color(0.20, 0.002, 0.012, 0.92 * blood_amount).darkened(surface_darken)
	var side := -1 if left_foot else 1
	PIXEL_PAINTER.pixel(self, Vector2(-2, side), dark_blood)
	PIXEL_PAINTER.pixel(self, Vector2(-1, side), dark_blood)
	PIXEL_PAINTER.pixel(self, Vector2(0, side), blood)
	PIXEL_PAINTER.pixel(self, Vector2(1, side), blood)
	if surface_spread > 1.08: PIXEL_PAINTER.pixel(self, Vector2(0, side + (1 if left_foot else -1)), Color(blood, blood.a * 0.7))
	if smudged:
		PIXEL_PAINTER.pixel(self, Vector2(2, side), Color(blood, blood.a * 0.66))
		PIXEL_PAINTER.pixel(self, Vector2(3, side), Color(blood, blood.a * 0.36))
