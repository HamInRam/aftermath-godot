class_name PixelActorPart
extends Node2D

const PIXELS := preload("res://utility/pixel_art_painter.gd")

@export_enum("legs", "upper") var part := "upper"
@export_enum("player", "enemy", "dog") var actor_kind := "enemy"
@export var body_color := Color("7c235b")
@export var accent_color := Color("f2e9f4")
@export var skin_color := Color("d39a83")

var movement_ratio := 0.0
var stride_phase := 0.0
var action := "idle"
var action_amount := 0.0
var hit_direction := Vector2.ZERO
var knocked_down := false
var facing_motion := Vector2.RIGHT

func configure(kind: String, color: Color, accent := Color("f2e9f4")) -> void:
	actor_kind = kind
	body_color = color
	accent_color = accent
	queue_redraw()

func update_pose(delta: float, local_velocity: Vector2, speed_reference: float, next_action := "idle", amount := 0.0) -> void:
	movement_ratio = clampf(local_velocity.length() / maxf(speed_reference, 1.0), 0.0, 1.4)
	if local_velocity.length_squared() > 0.5: facing_motion = local_velocity.normalized()
	stride_phase += delta * lerpf(5.0, 14.0, movement_ratio)
	action = next_action
	action_amount = clampf(amount, 0.0, 1.0)
	queue_redraw()

func set_knocked(enabled: bool) -> void:
	knocked_down = enabled
	queue_redraw()

func flash_hit(direction: Vector2) -> void:
	hit_direction = direction.normalized()
	action = "hit"
	action_amount = 1.0
	queue_redraw()

func _draw() -> void:
	if part == "legs": _draw_legs()
	else: _draw_upper()

func _draw_legs() -> void:
	# Living legs are deliberately absent at rest in a strict overhead view. When
	# moving, two compact shoes peek out from below the torso and alternate over a
	# four-frame cycle. Every cell is authored as one world pixel.
	if movement_ratio <= 0.12 or knocked_down:
		return
	if actor_kind == "dog":
		var dog_step := _four_frame_step() * 1.5
		_draw_flat_foot(Vector2(-3.0 + dog_step, -3.0), Color("090909"), Color("c7c7c7"))
		_draw_flat_foot(Vector2(-3.0 - dog_step, 2.0), Color("090909"), Color("919191"))
		return
	var step := _four_frame_step() * 1.7
	var shoe_fill := Color("f0f0f0") if actor_kind == "player" else Color("585858")
	_draw_flat_foot(Vector2(-3.0 + step, -2.0), Color("080808"), shoe_fill)
	_draw_flat_foot(Vector2(-3.0 - step, 2.0), Color("080808"), shoe_fill.darkened(0.20))

func _draw_flat_foot(center: Vector2, outline: Color, fill: Color) -> void:
	var origin := center.round() - Vector2(1, 1)
	PIXELS.rect(self, Rect2(origin, Vector2(3, 2)), outline)
	PIXELS.rect(self, Rect2(origin + Vector2(1, 0), Vector2(2, 1)), fill)

func _four_frame_step() -> float:
	var frame := wrapi(floori(stride_phase * 0.9), 0, 4)
	return [-1.0, 0.0, 1.0, 0.0][frame]

func _draw_upper() -> void:
	if actor_kind == "dog":
		_draw_dog_upper()
		return
	var lean := Vector2.ZERO
	var arm_swing := sin(stride_phase * 2.0) * movement_ratio
	if action == "reload": lean = Vector2(-1, 1)
	elif action == "drag": lean = Vector2(-2, 1)
	elif action == "clean": lean = Vector2(2.0 * action_amount, 0)
	elif action == "attack": lean = Vector2(3.0 * action_amount, 0)
	elif action == "hit": lean = -hit_direction * 2.0 * action_amount
	elif action == "execute": lean = Vector2(2.0, 0)
	# Back arm, torso, head, front arm. Large color blocks keep the silhouette readable at 3x.
	PIXELS.material_line(self, lean + Vector2(-1, 3), lean + Vector2(4 + roundf(arm_swing), 5), body_color.darkened(0.28), 2, 29)
	_block(Rect2(lean + Vector2(-4, -4), Vector2(8, 8)), body_color, 31)
	_block(Rect2(lean + Vector2(-3, -3), Vector2(3, 6)), body_color.lightened(0.11), 37)
	PIXELS.material_circle(self, lean + Vector2(4, 0), 3, skin_color, skin_color.lightened(0.12), skin_color.darkened(0.18), 41)
	_block(Rect2(lean + Vector2(4, -2), Vector2(2, 4)), skin_color.lightened(0.12), 43)
	PIXELS.pixel(self, lean + Vector2(5, -2), Color("301b27"))
	var front_hand := lean + Vector2(6, -3 - arm_swing)
	if action == "reload": front_hand = lean + Vector2(1, 3)
	elif action == "drag": front_hand = lean + Vector2(-5, 1)
	elif action == "execute": front_hand = lean + Vector2(7, 0)
	PIXELS.material_line(self, lean + Vector2(0, -3), front_hand.round(), body_color.lightened(0.08), 2, 47)
	PIXELS.material_circle(self, front_hand.round(), 1, skin_color, skin_color.lightened(0.12), skin_color.darkened(0.18), 53)
	# One-pixel identity accents replace the old debug-like full circular outline.
	PIXELS.line(self, Vector2(-4, -5), Vector2(1, -5), accent_color)
	_block(Rect2(-4, 4, 2, 1), accent_color.darkened(0.15), 59)
	if action == "alert":
		_block(Rect2(3, -4, 3, 1), Color("ff355f"), 61)
	elif action == "attack":
		_block(Rect2(4, -4, 3, 1), Color("ffe06b"), 67)

func _draw_dog_upper() -> void:
	var crouch := 2.0 * action_amount if action == "attack" else 0.0
	_block(Rect2(-5, -3 + roundf(crouch), 9, 6 - roundf(crouch)), body_color, 71)
	_block(Rect2(2, -4 + roundf(crouch), 5, 5), body_color.lightened(0.1), 73)
	_block(Rect2(5, -5 + roundf(crouch), 2, 2), Color("261822"), 79)
	_block(Rect2(6, -2 + roundf(crouch), 2, 1), skin_color, 83)
	PIXELS.line(self, Vector2(-5, 0), Vector2(-8, -3), body_color.lightened(0.08))

func _block(area: Rect2, color: Color, seed: int) -> void:
	PIXELS.material_rect(self, area, color, color.lightened(0.12), color.darkened(0.18), seed, &"fabric")
