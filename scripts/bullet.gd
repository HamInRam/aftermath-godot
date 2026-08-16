extends CharacterBody2D

signal blood_impact(hit_position: Vector2, direction: Vector2, damage: int, weapon_id: String, travel_distance: float, lethal: bool)

@export var speed := 650.0
var direction := Vector2.RIGHT
var enemy_owned := false
var damage := 1
var lifetime := 1.2
var weapon_id := "pistol"
var spawn_position := Vector2.ZERO
var travel_distance := 0.0

func setup(dir: Vector2, is_enemy_bullet: bool, hit_damage := 1, source_weapon := "pistol", origin := Vector2.ZERO, projectile_speed := 650.0) -> void:
	direction = dir.normalized()
	enemy_owned = is_enemy_bullet
	damage = hit_damage
	weapon_id = source_weapon
	spawn_position = origin
	speed = projectile_speed
	rotation = direction.angle()
	velocity = direction * speed

func _physics_process(delta: float) -> void:
	travel_distance += velocity.length() * delta
	var collision := move_and_collide(velocity * delta)
	if collision != null:
		var collider := collision.get_collider()
		if collider is Node and collider.has_method("receive_projectile_impact"):
			collider.receive_projectile_impact(velocity, collision.get_position())
		if collider is Node and collider.has_method("take_damage"):
			var valid_target: bool = (enemy_owned and collider.is_in_group("player")) or ((not enemy_owned) and collider.is_in_group("enemy"))
			if valid_target:
				var current_hp: int = int(collider.get("hp"))
				blood_impact.emit(global_position, direction, damage, weapon_id, travel_distance, current_hp <= damage)
				collider.take_damage(damage, global_position - direction * 2.0)
		queue_free()
		return
	lifetime -= delta
	if lifetime <= 0.0: queue_free()

func _draw() -> void:
	var color := Color("ffe48a") if not enemy_owned else Color("ff3868")
	draw_line(Vector2(-5, 0), Vector2.ZERO, Color(color, 0.3), 1.0)
	draw_rect(Rect2(-1, -1, 2, 2), color)
