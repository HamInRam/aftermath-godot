class_name ThrownWeapon
extends CharacterBody2D

const PICKUP_SCENE := preload("res://scenes/props/weapon_pickup.tscn")
const WEAPON_ART := preload("res://utility/weapon_pixel_art.gd")

var weapon_id := "pistol"
var rounds := 0
var attachment_ids := PackedStringArray()
var lifetime := 0.8
var settled := false
var flight_angle := 0.0
var age := 0.0
var wall_bounces := 0
var impact_resolved := false
const LAUNCH_SPEED := 320.0
const AIR_DRAG := 245.0

func _ready() -> void:
	z_index = 10
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func setup(direction: Vector2, new_weapon_id: String, remaining_rounds: int, new_attachment_ids := PackedStringArray()) -> void:
	weapon_id = WeaponPlatformCatalog.canonical_id(new_weapon_id)
	rounds = maxi(0, remaining_rounds)
	attachment_ids = new_attachment_ids.duplicate()
	velocity = direction.normalized() * LAUNCH_SPEED
	lifetime = 0.8
	settled = false
	impact_resolved = false
	wall_bounces = 0
	age = 0.0
	$WeaponSprite.texture = null
	$WeaponSprite.visible = false
	rotation = 0.0
	flight_angle = direction.angle()
	queue_redraw()

func _draw() -> void:
	# Rotate the authored pixel locations, not the CanvasItem. This keeps every
	# airborne gun on the same one-pixel grid as the scenery and pickups.
	WEAPON_ART.draw_weapon(self, weapon_id, Vector2.ZERO, Vector2.RIGHT.rotated(flight_angle), true, attachment_ids)

func _physics_process(delta: float) -> void:
	if settled: return
	age += delta
	flight_angle += 18.0 * delta
	var collision := move_and_collide(velocity * delta)
	if collision != null:
		var collider := collision.get_collider()
		if collider is Node and (collider.is_in_group("enemy") or collider.is_in_group("destructible_prop") or collider.is_in_group("breach_panel")):
			_resolve_impact(collider)
		else:
			# Swept motion stops at thin walls; a short bounce communicates weight
			# without sending inventory through the wall or outside the room.
			Events.publish_combat_noise(global_position, 74.0, "thrown_weapon")
			velocity = velocity.bounce(collision.get_normal()) * 0.24
			wall_bounces += 1
			lifetime = minf(lifetime, 0.14)
			if wall_bounces >= 2 or velocity.length() < 24.0: _settle_as_pickup()
		queue_redraw()
		return
	velocity = velocity.move_toward(Vector2.ZERO, AIR_DRAG * delta)
	lifetime -= delta
	if lifetime <= 0.0 or velocity.length() < 30.0: _settle_as_pickup()
	queue_redraw()

func _resolve_impact(collider: Object) -> void:
	if settled or impact_resolved: return
	impact_resolved = true
	if collider is Node and collider.is_in_group("breach_panel"):
		collider.receive_projectile_impact_context(velocity,global_position,"thrown",90)
	elif collider is Node and collider.is_in_group("enemy") and collider.has_method("take_door_hit"):
		collider.take_door_hit(velocity.normalized(), "knockdown")
	elif collider is Node and collider.is_in_group("destructible_prop") and collider.has_method("take_damage"):
		if collider.has_method("receive_thrown_impact"):
			collider.receive_thrown_impact(velocity.normalized(), clampf(velocity.length() / 180.0, 0.5, 1.5))
		else:
			collider.take_damage(1, global_position - velocity.normalized() * 2.0)
	Events.publish_combat_noise(global_position, 92.0, "thrown_weapon")
	_settle_as_pickup()

func _settle_as_pickup() -> void:
	if settled: return
	settled = true
	var pickup = PICKUP_SCENE.instantiate()
	var parent := get_tree().current_scene if get_tree().current_scene != null else get_parent()
	if not RuntimeBudget.add_persistent("weapon_pickup", pickup, parent):
		queue_free()
		return
	pickup.global_position = global_position
	pickup.rotation = snappedf(flight_angle, PI / 4.0)
	pickup.setup(weapon_id, rounds, attachment_ids)
	queue_free()
