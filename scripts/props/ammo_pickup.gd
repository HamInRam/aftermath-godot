class_name AmmoPickup
extends Area2D

const PIXELS := preload("res://utility/pixel_art_painter.gd")

@export var weapon_id := "pistol"
@export var rounds := 12

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	queue_redraw()

func setup(new_weapon_id: String, new_rounds: int) -> void:
	weapon_id = new_weapon_id
	rounds = maxi(1, new_rounds)
	queue_redraw()

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player") or not body.has_method("add_reserve_ammo"): return
	if body.add_reserve_ammo(weapon_id, rounds): queue_free()

func _draw() -> void:
	PIXELS.material_panel(self, Rect2(-6, -4, 12, 8), Color("17131b"), Color("182238"), Color("66e0ff"), Color("0b1020"), 21, &"metal")
	for x in [-4, 0, 4]:
		PIXELS.line(self, Vector2(x, -2), Vector2(x, 2), Color("ffd166"))
		PIXELS.pixel(self, Vector2(x, -2), Color("fff0a3"))
