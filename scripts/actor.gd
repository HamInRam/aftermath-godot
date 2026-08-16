class_name Actor
extends CharacterBody2D

signal health_changed(current_hp: int, max_hp: int)
signal actor_died(source_position: Vector2)

@export var max_hp := 1
@export var move_speed := 80.0
var hp := 1
var is_dead := false

func _ready() -> void:
	hp = max_hp

func move_actor(input_direction: Vector2) -> void:
	velocity = input_direction.normalized() * move_speed
	move_and_slide()

func take_damage(amount: int, source_position := Vector2.ZERO) -> void:
	if is_dead or amount <= 0:
		return
	hp = maxi(0, hp - amount)
	health_changed.emit(hp, max_hp)
	if hp == 0:
		is_dead = true
		actor_died.emit(source_position)

func heal_full() -> void:
	hp = max_hp
	is_dead = false
	health_changed.emit(hp, max_hp)
