class_name ThrownWeapon
extends CharacterBody2D

const PICKUP_SCENE := preload("res://scenes/props/weapon_pickup.tscn")

var weapon_id := "pistol"
var rounds := 0
var lifetime := 0.8
var settled := false

func setup(direction: Vector2, new_weapon_id: String, remaining_rounds: int) -> void:
	weapon_id = new_weapon_id
	rounds = maxi(0, remaining_rounds)
	velocity = direction.normalized() * 245.0
	var data := AttackCatalog.get_gun_data(weapon_id)
	$WeaponSprite.texture = data.weapon_texture
	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	if settled: return
	rotation += 14.0 * delta
	var collision := move_and_collide(velocity * delta)
	if collision != null:
		_resolve_impact(collision.get_collider())
		return
	velocity = velocity.move_toward(Vector2.ZERO, 165.0 * delta)
	lifetime -= delta
	if lifetime <= 0.0 or velocity.length() < 30.0: _settle_as_pickup()

func _resolve_impact(collider: Object) -> void:
	if collider is Node and collider.is_in_group("enemy") and collider.has_method("take_door_hit"):
		collider.take_door_hit(velocity.normalized(), "knockdown")
	Events.publish_combat_noise(global_position, 92.0, "thrown_weapon")
	_settle_as_pickup()

func _settle_as_pickup() -> void:
	if settled: return
	settled = true
	var pickup = PICKUP_SCENE.instantiate()
	var parent := get_tree().current_scene if get_tree().current_scene != null else get_parent()
	if not RuntimeBudget.try_add("weapon_pickup", pickup, parent):
		queue_free()
		return
	pickup.global_position = global_position
	pickup.rotation = rotation
	pickup.setup(weapon_id, rounds)
	queue_free()
