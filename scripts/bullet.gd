extends CharacterBody2D

const WALL_SPARKS_SCENE := preload("res://scenes/effects/wall_sparks.tscn")
const PIXEL_PAINTER := preload("res://utility/pixel_art_painter.gd")

const PLAYER_LAYER := 1
const ENEMY_LAYER := 2
const SOLID_LAYER := 4
const GLASS_LAYER := 8
const CORPSE_LAYER := 32
const PLAYER_PROJECTILE_MASK := ENEMY_LAYER | SOLID_LAYER | GLASS_LAYER | CORPSE_LAYER
const ENEMY_PROJECTILE_MASK := PLAYER_LAYER | SOLID_LAYER | GLASS_LAYER
const DEBRIS_PENETRATION_SPEED_RETENTION := 0.9
const DEBRIS_CLEARANCE := 5.0

signal blood_impact(hit_position: Vector2, direction: Vector2, damage: int, weapon_id: String, travel_distance: float, lethal: bool, hit_zone: String)
signal damage_impact(context: DamageContext)
signal shot_resolved(shot_id: int, outcome: String, lethal: bool, weapon_id: String)

@export var speed := 650.0
var direction := Vector2.RIGHT
var enemy_owned := false
var damage := 1
var lifetime := 1.2
var weapon_id := "pistol"
var spawn_position := Vector2.ZERO
var travel_distance := 0.0
var shot_id := -1
var resolution_emitted := false
var passed_overkill_target := false
var source_actor: CollisionObject2D
var combat_time_scale := 1.0
var visual_tail_length := 8
var penetration_power := 0.8
var property_damage := 0.8
var damage_falloff_start := 65.0
var damage_falloff_end := 170.0
var minimum_damage_ratio := 0.62
var blood_enhanced := false
var blood_budget_raw := 0
var blood_stain_radius := -1.0
var weapon_source: GunData
var blood_gore_multiplier := 1.0

func setup(dir: Vector2, is_enemy_bullet: bool, hit_damage := 43, source_weapon := "pistol", origin := Vector2.ZERO, projectile_speed := 650.0, shooter: CollisionObject2D = null, source_penetration := 0.8, source_property_damage := 0.8, falloff_start := 65.0, falloff_end := 170.0, minimum_ratio := 0.62) -> void:
	direction = dir.normalized()
	enemy_owned = is_enemy_bullet
	damage = hit_damage
	weapon_id = source_weapon
	blood_stain_radius = AttackCatalog.get_gun_data(weapon_id).blood_stain_radius
	var weapon_class := AttackCatalog.get_gun_data(weapon_id).weapon_class
	visual_tail_length = 5 if weapon_class == "shotgun" else (7 if weapon_class in ["pdw", "smg"] else (10 if weapon_class in ["dmr", "sniper", "lmg"] else 8))
	spawn_position = origin
	speed = projectile_speed
	penetration_power = source_penetration
	property_damage = source_property_damage
	damage_falloff_start = falloff_start
	damage_falloff_end = maxf(falloff_start + 1.0, falloff_end)
	minimum_damage_ratio = clampf(minimum_ratio, 0.2, 1.0)
	source_actor = shooter
	# Only query the opposing actor layer. This prevents allied bodies from
	# silently consuming rounds and does not rely on the muzzle sitting outside
	# the shooter's collision shape on every animation frame.
	collision_mask = ENEMY_PROJECTILE_MASK if enemy_owned else PLAYER_PROJECTILE_MASK
	rotation = direction.angle()
	velocity = direction * speed
	queue_redraw()
	if is_inside_tree(): _install_source_exception()

func _ready() -> void:
	_install_source_exception()

func _install_source_exception() -> void:
	if is_instance_valid(source_actor): add_collision_exception_with(source_actor)

func _physics_process(delta: float) -> void:
	if enemy_owned: delta *= combat_time_scale
	travel_distance += velocity.length() * delta
	var collision := move_and_collide(velocity * delta)
	if collision != null:
		var collider := collision.get_collider()
		# Prop fragments share the evidence/occluder layer with corpses, but are
		# not ballistic blockers. Kick the tiny fragment aside and continue the
		# round instead of making it appear to vanish in open floor space.
		if collider is Node and collider.is_in_group("environment_debris"):
			if collider.has_method("receive_projectile_glance"):
				collider.receive_projectile_glance(velocity, collision.get_position(), weapon_id, damage)
			if collider is CollisionObject2D: add_collision_exception_with(collider)
			global_position = collision.get_position() + direction * DEBRIS_CLEARANCE
			velocity *= DEBRIS_PENETRATION_SPEED_RETENTION
			speed = velocity.length()
			return
		if not enemy_owned and collider is Node and collider.is_in_group("corpse") and collider.has_method("can_receive_overkill") and collider.can_receive_overkill():
			var overkill_context := DamageContext.create(collision.get_position(), direction, damage, weapon_id, travel_distance, false, "torso", spawn_position, collider)
			_apply_blood_enhancement(overkill_context)
			damage_impact.emit(overkill_context)
			if blood_enhanced: blood_budget_raw = overkill_context.blood_budget_raw
			collider.receive_projectile_overkill(direction, collision.get_position(), weapon_id, velocity.length())
			passed_overkill_target = true
			if collider is CollisionObject2D: add_collision_exception_with(collider)
			global_position = collision.get_position() + direction * 3.0
			velocity *= 0.68
			speed = velocity.length()
			return
		var tile_world = collider.get_parent() if collider is TileMapLayer else null
		if tile_world != null and tile_world.has_method("shatter_glass_at") and tile_world.shatter_glass_at(collision.get_position(), direction):
			global_position = collision.get_position() + direction * 9.0
			return
		var hit_solid_surface: bool = collider is TileMapLayer or (collider is CollisionObject2D and collider.get_collision_layer_value(3))
		if hit_solid_surface:
			var sparks = WALL_SPARKS_SCENE.instantiate()
			var effect_parent := get_tree().current_scene if get_tree().current_scene != null else get_parent()
			if RuntimeBudget.try_add("transient_fx", sparks, effect_parent):
				sparks.global_position = collision.get_position()
				sparks.setup(direction)
		if collider is Node and collider.has_method("receive_projectile_impact_context"):
			collider.receive_projectile_impact_context(velocity, collision.get_position(), weapon_id, maxi(damage, ceili(property_damage)))
		elif collider is Node and collider.has_method("receive_projectile_impact"):
			collider.receive_projectile_impact(velocity, collision.get_position())
		if collider is Node and collider.has_method("take_damage"):
			var valid_target: bool = (enemy_owned and collider.is_in_group("player")) or ((not enemy_owned) and collider.is_in_group("enemy"))
			if valid_target:
				var current_hp: int = int(collider.get("hp"))
				var hit_zone := "torso"
				if collider.has_method("classify_ballistic_hit"):
					hit_zone = str(collider.classify_ballistic_hit(global_position, direction))
				elif collider.has_method("classify_hit_zone"):
					hit_zone = str(collider.classify_hit_zone(global_position))
				var target_max_hp := int(collider.get("max_hp"))
				var result := {"health_damage": damage, "raw_damage": float(damage), "armour_absorbed": 0.0, "distance_multiplier": 1.0, "stealth_critical": false, "lethal": current_hp <= damage, "damage_ratio": float(damage) / maxf(1.0, float(target_max_hp))}
				var weapon_class := AttackCatalog.get_gun_data(weapon_id).weapon_class
				if collider.has_method("calculate_ballistic_hit"):
					result = collider.calculate_ballistic_hit(damage, penetration_power, hit_zone, travel_distance, damage_falloff_start, damage_falloff_end, minimum_damage_ratio, weapon_class)
				result["hit_zone"] = hit_zone
				var resolved_damage := int(result.get("health_damage", damage))
				var context := DamageContext.create(global_position, direction, resolved_damage, weapon_id, travel_distance, bool(result.get("lethal", current_hp <= resolved_damage)), hit_zone, spawn_position, collider)
				context.apply_ballistic_result(result)
				context.weapon_source = weapon_source
				context.blood_stain_radius = blood_stain_radius
				_apply_blood_enhancement(context)
				# Wound simulation needs the ammunition source too. An empowered hit
				# already spends a finite blood ledger at impact, so its later bleed
				# may deal attrition but must not mint additional absorbable pixels.
				result["blood_enhanced"] = blood_enhanced
				damage_impact.emit(context)
				# A penetrating projectile carries only its unspent blood mass onward.
				# Without this write-back, every body in a penetration chain could
				# independently mint the original trigger-pull budget.
				if blood_enhanced: blood_budget_raw = context.blood_budget_raw
				if collider.has_method("apply_ballistic_hit"):
					collider.apply_ballistic_hit(result, spawn_position)
				else:
					collider.take_damage(resolved_damage, spawn_position)
				_resolve_shot("enemy", context.lethal)
				# High-energy rifle rounds may pass through a defeated target.  The
				# power budget is consumed on every body, preventing infinite chains.
				if context.lethal and penetration_power >= 1.45 and collider is CollisionObject2D:
					penetration_power -= 0.85
					add_collision_exception_with(collider)
					global_position = collision.get_position() + direction * 4.0
					velocity *= 0.72
					speed = velocity.length()
					return
		if not resolution_emitted: _resolve_shot("overkill" if passed_overkill_target else "miss", false)
		queue_free()
		return
	lifetime -= delta
	if lifetime <= 0.0:
		_resolve_shot("overkill" if passed_overkill_target else "miss", false)
		queue_free()

func set_combat_time_scale(value: float) -> void:
	combat_time_scale = clampf(value, 0.2, 1.0) if enemy_owned else 1.0
	queue_redraw()

func set_blood_enhanced(enabled: bool, raw_budget := 0, gore_multiplier := 1.0) -> void:
	blood_enhanced = enabled
	blood_budget_raw = maxi(0, raw_budget)
	blood_gore_multiplier = maxf(1.0, gore_multiplier)
	queue_redraw()

func _apply_blood_enhancement(context: DamageContext) -> void:
	if not blood_enhanced: return
	context.blood_enhanced = true
	context.blood_budget_raw = blood_budget_raw
	context.gore_force_multiplier = blood_gore_multiplier
	context.energy = minf(4.8, context.energy * 1.28)
	context.mist_scale *= 1.32
	context.exit_wound_scale *= 1.28
	context.external_blood_scale *= 1.18
	var violence := context.violence_profile.duplicate(true)
	violence["drops"] = maxi(int(violence.get("drops", 8)), 18)
	violence["gore"] = maxi(int(violence.get("gore", 3)), 8)
	violence["limbs"] = maxi(int(violence.get("limbs", 0)), 1 if context.hit_zone != "head" else 2)
	violence["wound"] = "blast" if context.hit_zone != "limb" else "dismember"
	violence["pool_bias"] = maxf(float(violence.get("pool_bias", 1.0)), 1.28)
	context.violence_profile = violence

func _resolve_shot(outcome: String, lethal: bool) -> void:
	if resolution_emitted or enemy_owned or shot_id < 0: return
	resolution_emitted = true
	shot_resolved.emit(shot_id, outcome, lethal, weapon_id)

func _draw() -> void:
	var core := NeonPalette.BLOOD_CRIMSON if blood_enhanced else Color("ffffff")
	var tracer := NeonPalette.BLOOD_CRIMSON if blood_enhanced else Color("d8d8d8")
	var ink := Color(0.055, 0.025, 0.055, 0.92)
	var tail_end := -float(visual_tail_length)
	# The silhouette stays built from one-world-pixel cells. A dark separator
	# prevents bright floors, blood and muzzle flashes from swallowing the round.
	PIXEL_PAINTER.line(self, Vector2(tail_end - 1.0, 0), Vector2(2, 0), ink)
	PIXEL_PAINTER.line(self, Vector2(-2, -1), Vector2(1, -1), ink)
	PIXEL_PAINTER.line(self, Vector2(-2, 1), Vector2(1, 1), ink)
	PIXEL_PAINTER.line(self, Vector2(tail_end, 0), Vector2(-4, 0), Color(tracer, 0.38))
	PIXEL_PAINTER.line(self, Vector2(-4, 0), Vector2(-1, 0), Color(tracer, 0.82))
	PIXEL_PAINTER.line(self, Vector2(-1, 0), Vector2(1, 0), core)
	PIXEL_PAINTER.pixel(self, Vector2.ZERO, tracer)
