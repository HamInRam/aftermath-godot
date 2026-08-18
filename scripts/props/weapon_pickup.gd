class_name WeaponPickup
extends Area2D

var weapon_id := "pistol"
var rounds := 1
var cleanup_amount := 1.0
@onready var weapon_sprite: Sprite2D = $WeaponSprite

func _ready() -> void:
	CleanupRegistry.register_target(self)
	_apply_visual()

func setup(new_weapon_id: String, new_rounds: int) -> void:
	weapon_id = new_weapon_id
	rounds = maxi(0, new_rounds)
	if is_node_ready(): _apply_visual()

func collect(player: Node) -> bool:
	if not is_instance_valid(player) or not player.has_method("acquire_gun"): return false
	if not player.acquire_gun(weapon_id, rounds): return false
	CleanupRegistry.unregister_target(self)
	queue_free()
	return true

func collect_enemy(enemy: Node) -> bool:
	if rounds <= 0 or not is_instance_valid(enemy) or not enemy.has_method("equip_dropped_weapon"): return false
	if not enemy.equip_dropped_weapon(weapon_id, rounds): return false
	CleanupRegistry.unregister_target(self)
	queue_free()
	return true

func clean_step() -> void:
	cleanup_amount -= 0.34
	modulate.a = clampf(cleanup_amount, 0.2, 1.0)
	if cleanup_amount <= 0.02: queue_free()

func get_cleanup_type() -> String:
	return "dropped_weapon"

func get_cleanup_cost() -> int:
	return 3

func _apply_visual() -> void:
	var data := AttackCatalog.get_gun_data(weapon_id)
	weapon_sprite.texture = data.weapon_texture
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 7.0, Color(0.15, 0.95, 0.88, 0.12))
	draw_arc(Vector2.ZERO, 7.0, 0.0, TAU, 16, Color(0.35, 1.0, 0.9, 0.62), 1.0)
