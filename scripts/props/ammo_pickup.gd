class_name AmmoPickup
extends Area2D

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
	draw_rect(Rect2(-6, -4, 12, 8), Color("182238"), true)
	draw_rect(Rect2(-6, -4, 12, 8), Color("66e0ff"), false, 1.0)
	for x in [-3.5, 0.0, 3.5]:
		draw_rect(Rect2(x - 0.7, -2.5, 1.4, 5), Color("ffd166"), true)
