extends CharacterBody2D

@export var speed := 295.0
var direction := Vector2.RIGHT
var enemy_owned := false
var damage := 1
var lifetime := 1.2

func setup(dir: Vector2, is_enemy_bullet: bool, hit_damage := 1) -> void:
	direction = dir.normalized()
	enemy_owned = is_enemy_bullet
	damage = hit_damage
	rotation = direction.angle()
	velocity = direction * speed

func _physics_process(delta: float) -> void:
	var collision := move_and_collide(velocity * delta)
	if collision != null:
		var collider := collision.get_collider()
		if collider is Node and collider.has_method("take_damage"):
			var valid_target: bool = (enemy_owned and collider.is_in_group("player")) or ((not enemy_owned) and collider.is_in_group("enemy"))
			if valid_target: collider.take_damage(damage, global_position - direction * 2.0)
		queue_free()
		return
	lifetime -= delta
	if lifetime <= 0.0: queue_free()

func _draw() -> void:
	var color := Color("ffe48a") if not enemy_owned else Color("ff3868")
	draw_line(Vector2(-5, 0), Vector2.ZERO, Color(color, 0.3), 1.0)
	draw_rect(Rect2(-1, -1, 2, 2), color)
