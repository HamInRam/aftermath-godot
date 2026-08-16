class_name Gun
extends Node2D

signal fired(origin: Vector2, direction: Vector2, enemy_owned: bool, damage: int, weapon_id: String)
signal ammo_changed(current: int, maximum: int)

@export var fire_interval := 0.1
@export var max_ammo := 12
@export var projectile_damage := 1
@export var enemy_owned := false
@export var automatic := true
@export var weapon_id := "pistol"

var ammo := 12
var cooldown := 0.0
var recoil := 0.0

func _ready() -> void:
	ammo = max_ammo
	ammo_changed.emit(ammo, max_ammo)
	queue_redraw()

func _process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	recoil = move_toward(recoil, 0.0, 24.0 * delta)
	queue_redraw()

func try_fire(direction: Vector2) -> bool:
	if cooldown > 0.0 or ammo <= 0 or direction.length_squared() < 0.001:
		return false
	cooldown = fire_interval
	ammo -= 1
	recoil = 2.0
	var normalized_direction := direction.normalized()
	fired.emit(global_position + normalized_direction * 8.0, normalized_direction, enemy_owned, projectile_damage, weapon_id)
	ammo_changed.emit(ammo, max_ammo)
	return true

func reload() -> void:
	ammo = max_ammo
	ammo_changed.emit(ammo, max_ammo)

func _draw() -> void:
	var gun_color := Color("181820") if not enemy_owned else Color("28151f")
	draw_rect(Rect2(1.0 - recoil, -1.0, 9.0, 3.0), gun_color)
	draw_rect(Rect2(3.0 - recoil, 2.0, 2.0, 2.0), Color("34313b"))
