class_name Actor
extends CharacterBody2D

signal health_changed(current_hp: int, max_hp: int)
signal armor_changed(current_armor: float, max_armor: float)
signal actor_died(source_position: Vector2)
signal hit_received(amount: int, source_position: Vector2)

const BALLISTIC_DAMAGE := preload("res://scripts/combat/ballistic_damage_resolver.gd")

@export var max_hp := 100
@export var move_speed := 80.0
@export_group("Ballistic Protection")
@export_range(0.0, 3.0, 0.05) var armor_protection := 0.0
@export_range(0.0, 0.7, 0.01) var armor_damage_reduction := 0.0
@export_range(0.0, 150.0, 1.0) var max_armor_durability := 0.0
@export var armor_covers_head := false
var hp := 100
var armor_durability := 0.0
var is_dead := false

func _ready() -> void:
	hp = max_hp
	armor_durability = max_armor_durability

func move_actor(input_direction: Vector2) -> void:
	velocity = input_direction.normalized() * move_speed
	var intended_velocity := velocity
	move_and_slide()
	push_contact_bodies(intended_velocity)

func push_contact_bodies(intended_velocity: Vector2) -> void:
	for collision_index in get_slide_collision_count():
		var collision := get_slide_collision(collision_index)
		var collider := collision.get_collider()
		if collider is Node and collider.has_method("push_door_open") and intended_velocity.length_squared() > 0.01:
			collider.push_door_open(self, intended_velocity)
		elif collider is Node and collider.has_method("receive_actor_push"):
			collider.receive_actor_push(intended_velocity, collision.get_position())

func take_damage(amount: int, source_position := Vector2.ZERO) -> void:
	if is_dead or amount <= 0:
		return
	hit_received.emit(amount, source_position)
	hp = maxi(0, hp - amount)
	health_changed.emit(hp, max_hp)
	if hp == 0:
		is_dead = true
		actor_died.emit(source_position)

func calculate_ballistic_hit(base_damage: float, penetration: float, hit_zone: String, travel_distance: float, falloff_start: float, falloff_end: float, minimum_damage_ratio: float, weapon_class := "handgun") -> Dictionary:
	return BALLISTIC_DAMAGE.resolve(base_damage, penetration, hit_zone, travel_distance, falloff_start, falloff_end, minimum_damage_ratio, hp, max_hp, armor_protection, armor_damage_reduction, armor_durability, armor_covers_head, is_unaware_for_ballistics(), weapon_class)

func apply_ballistic_hit(result: Dictionary, source_position := Vector2.ZERO) -> void:
	if is_dead: return
	var armor_loss := float(result.get("armour_damage", 0.0))
	if armor_loss > 0.0:
		armor_durability = maxf(0.0, armor_durability - armor_loss)
		armor_changed.emit(armor_durability, max_armor_durability)
	take_damage(int(result.get("health_damage", 1)), source_position)
	if not is_dead: _on_ballistic_wound(result, source_position)

func _on_ballistic_wound(_result: Dictionary, _source_position: Vector2) -> void:
	pass

func is_unaware_for_ballistics() -> bool:
	return false

func set_max_health(value: int, refill := true) -> void:
	max_hp = maxi(1, value)
	hp = max_hp if refill else clampi(hp, 0, max_hp)
	health_changed.emit(hp, max_hp)

func configure_armor(protection: float, reduction: float, durability: float, covers_head := false, refill := true) -> void:
	armor_protection = clampf(protection, 0.0, 3.0)
	armor_damage_reduction = clampf(reduction, 0.0, 0.7)
	max_armor_durability = maxf(0.0, durability)
	armor_covers_head = covers_head
	armor_durability = max_armor_durability if refill else clampf(armor_durability, 0.0, max_armor_durability)
	armor_changed.emit(armor_durability, max_armor_durability)

func heal_full() -> void:
	hp = max_hp
	armor_durability = max_armor_durability
	is_dead = false
	health_changed.emit(hp, max_hp)
	armor_changed.emit(armor_durability, max_armor_durability)

func heal(amount: int) -> int:
	if is_dead or amount <= 0 or hp >= max_hp: return 0
	var before := hp
	hp = mini(max_hp, hp + amount)
	health_changed.emit(hp, max_hp)
	return hp - before
