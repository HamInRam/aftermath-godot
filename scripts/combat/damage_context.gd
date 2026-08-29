class_name DamageContext
extends RefCounted

var hit_position := Vector2.ZERO
var direction := Vector2.RIGHT
var damage := 1
var weapon_id := "pistol"
var travel_distance := 0.0
var lethal := false
var hit_zone := "torso"
var energy := 1.0
var source_position := Vector2.ZERO
var target: Node2D
var surface := "flesh"
var violence_profile: Dictionary = {}

static func create(position: Vector2, shot_direction: Vector2, amount: int, attack_id: String, distance: float, is_lethal: bool, zone: String, source := Vector2.ZERO, victim: Node2D = null) -> DamageContext:
	var context := DamageContext.new()
	context.hit_position = position
	context.direction = shot_direction.normalized() if shot_direction.length_squared() > 0.001 else Vector2.RIGHT
	context.damage = maxi(1, amount)
	context.weapon_id = attack_id
	context.travel_distance = maxf(0.0, distance)
	context.lethal = is_lethal
	context.hit_zone = zone
	context.source_position = source
	context.target = victim
	var profile := AttackCatalog.get_blood_profile(attack_id)
	var range_ratio := clampf(distance / maxf(1.0, float(profile.range)), 0.0, 1.0)
	context.energy = clampf((1.25 - range_ratio * 0.5) * float(profile.blood_power), 0.35, 3.5)
	context.violence_profile = AttackCatalog.get_violence_profile(attack_id)
	return context
