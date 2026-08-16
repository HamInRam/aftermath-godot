extends Node2D

var amount := 1.0
var lobes: Array[Dictionary] = []

func _ready() -> void:
	rotation = randf_range(0.0, TAU)
	for i in range(14):
		lobes.append({"p": Vector2(randf_range(-10, 10), randf_range(-6, 6)), "r": randf_range(1, 4)})
	queue_redraw()

func clean_step() -> void:
	amount -= 0.12
	if amount <= 0.02: queue_free()
	else: queue_redraw()

func _draw() -> void:
	var blood := Color(0.62, 0.005, 0.035, 0.80 * amount)
	var dark := Color(0.28, 0.002, 0.015, 0.86 * amount)
	for i in range(lobes.size()):
		var data := lobes[i]
		draw_circle(data.p * amount, data.r * amount, dark if i % 4 == 0 else blood)
	draw_circle(Vector2.ZERO, 6.0 * amount, blood)
