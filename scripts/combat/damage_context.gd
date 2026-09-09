class_name DamageContext
extends RefCounted

var hit_position := Vector2.ZERO
var direction := Vector2.RIGHT
var damage := 1
var raw_damage := 1.0
var damage_ratio := 0.0
var armor_absorbed := 0.0
var distance_multiplier := 1.0
var stealth_critical := false
var penetration_power := 0.0
var penetration_ratio := 0.0
var energy_transfer := 1.0
var projectile_exited := true
var projectile_retained := false
var entry_wound_scale := 1.0
var exit_wound_scale := 1.0
var mist_scale := 1.0
var external_blood_scale := 1.0
var blood_enhanced := false
## Remaining siphonable ground-blood mass for this projectile. Negative means
## the normal unbudgeted blood path; empowered rounds always use a finite value.
var blood_budget_raw := -1
var blood_budget_spent_raw := 0
var blood_yield_multiplier := 1.0
var blood_emitted := false

## Reward valid live hits without enlarging droplets or bypassing legacy ledgers.
func configure_blood_yield(blood_ammo_mode: bool, chain: int) -> void:
	blood_yield_multiplier = 1.0
	if not blood_ammo_mode or blood_enhanced or blood_budget_raw >= 0 or damage <= 0: return
	if not is_instance_valid(target) or not target is Actor: return
	if not target.is_in_group("enemy") or target.is_dead or target.hp <= 0 or target.get_meta("polluter", false): return
	blood_yield_multiplier = 1.0 + 0.1 * clampi(chain + (1 if lethal else 0), 0, 10)

var gore_force_multiplier := 1.0
var bleed_rate := 0.0
var bleed_duration := 0.0
var bleed_dps := 0.0
var wound_severity := 0.0
var weapon_id := "pistol"
## Detached launch-time resource. Consumers must treat it as read-only.
var weapon_source: GunData
var blood_stain_radius := -1.0
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
	context.raw_damage = float(context.damage)
	context.weapon_id = attack_id
	if AttackCatalog.GUNS.has(attack_id): context.blood_stain_radius = AttackCatalog.get_gun_data(attack_id).blood_stain_radius
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

func apply_ballistic_result(result: Dictionary) -> void:
	raw_damage = float(result.get("raw_damage", damage))
	damage_ratio = float(result.get("damage_ratio", damage_ratio))
	armor_absorbed = float(result.get("armour_absorbed", 0.0))
	distance_multiplier = float(result.get("distance_multiplier", 1.0))
	stealth_critical = bool(result.get("stealth_critical", false))
	penetration_power = float(result.get("penetration_power", 0.0))
	penetration_ratio = float(result.get("penetration_ratio", 0.0))
	energy_transfer = float(result.get("energy_transfer", 1.0))
	projectile_exited = bool(result.get("projectile_exited", true))
	projectile_retained = bool(result.get("projectile_retained", false))
	entry_wound_scale = float(result.get("entry_wound_scale", 1.0))
	exit_wound_scale = float(result.get("exit_wound_scale", 1.0))
	mist_scale = float(result.get("mist_scale", 1.0))
	external_blood_scale = float(result.get("external_blood_scale", 1.0))
	bleed_rate = float(result.get("bleed_rate", 0.0))
	bleed_duration = float(result.get("bleed_duration", 0.0))
	bleed_dps = float(result.get("bleed_dps", 0.0))
	wound_severity = float(result.get("wound_severity", 0.0))
