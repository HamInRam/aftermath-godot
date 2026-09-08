extends CharacterBody2D

const PIXEL_PAINTER := preload("res://utility/pixel_art_painter.gd")

var spin := 0.0
var simulated_rotation := 0.0
var chunk_kind := 0
var settled := false
var attack_style := "firearm"

func setup(flight_direction: Vector2, intensity: float, variant: int, new_attack_style := "firearm") -> void:
	attack_style = new_attack_style
	chunk_kind = variant % (6 if attack_style in ["lmg", "bat", "execution", "execution_bat"] else 4)
	velocity = flight_direction.normalized() * randf_range(28.0, 62.0) * clampf(intensity, 0.7, 2.8)
	spin = randf_range(-9.0, 9.0)
	rotation = randf_range(-PI, PI)
	simulated_rotation = rotation
	queue_redraw()

func _physics_process(delta: float) -> void:
	if settled: return
	var collision := move_and_collide(velocity * delta)
	if collision != null:
		velocity = velocity.bounce(collision.get_normal()) * 0.28
		spin *= 0.45
	velocity = velocity.move_toward(Vector2.ZERO, 88.0 * delta)
	simulated_rotation += spin * delta
	rotation = snappedf(simulated_rotation, PI / 8.0)
	spin = move_toward(spin, 0.0, 12.0 * delta)
	if velocity.length() < 1.0:
		settled = true
		velocity = Vector2.ZERO
		set_physics_process(false)

func _draw() -> void:
	# Irregular tissue and exposed pale bone, rather than tiled rectangular
	# confetti. Crimson belongs exclusively to the finite liquid blood system.
	var shapes := [
		["..ii...", ".issii.", "issssi.", ".iiisni", "....ii."],
		[".ii.", "inni", ".nsi", ".isi", "..ii"],
		[".ii..", "issii", "isnsi", ".isi.", "..i.."],
		[".iii.", "innsi", ".nsi.", "..ii."],
		["...ii....", "..innni..", ".isssnii.", "iissssssi", "...iii..."],
		["..ii...", ".issi..", "issssii", ".isnssi", "..isssi", "...iii."],
	]
	var colors := {"i": Color("171717"), "s": Color("747474"), "n": Color("dedede")}
	var art := preload("res://utility/pixel_actor_art.gd")
	var cells := {}
	art._stamp(cells, shapes[chunk_kind % shapes.size()], Vector2.ZERO, colors, "tissue")
	var rotated := art.rotate_pixels(cells, global_rotation)
	draw_set_transform(Vector2.ZERO, -global_rotation, Vector2.ONE)
	for cell: Vector2 in rotated: PIXEL_PAINTER.pixel(self, cell, rotated[cell].color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
