class_name ProjectileSpawner
extends RefCounted
## Stateless integration controller; the scene retains lifetime and signal ownership.

static func _on_projectile_requested(actor: Node2D, origin: Vector2, direction: Vector2, enemy_owned: bool, damage: int, weapon_id: String, shooter: CollisionObject2D = null) -> void:
	if actor.phase != "combat" or actor.run_over: return
	var data = AttackCatalog.get_gun_data(weapon_id)
	if is_instance_valid(shooter):
		var shooter_gun = shooter.get("gun")
		if is_instance_valid(shooter_gun) and shooter_gun.gun_data != null and shooter_gun.weapon_id == weapon_id: data = shooter_gun.gun_data
	actor._ensure_projectile_pool()
	var bullet = actor.projectile_pool.acquire()
	if bullet == null:
		# A rejected pellet still closes its trigger ledger; sustained fire at the
		# pool cap must not accumulate unresolved shot records for the whole floor.
		if not enemy_owned and is_instance_valid(actor.player) and is_instance_valid(actor.player.gun):
			actor._on_player_shot_resolved(actor.player.gun.current_shot_id, "budget", false, weapon_id)
		return
	bullet.global_position = origin
	if not bullet.damage_impact.is_connected(actor._on_damage_impact): bullet.damage_impact.connect(actor._on_damage_impact)
	if not enemy_owned and is_instance_valid(actor.player) and is_instance_valid(actor.player.gun):
		bullet.shot_id = actor.player.gun.current_shot_id
		if not bullet.shot_resolved.is_connected(actor._on_player_shot_resolved): bullet.shot_resolved.connect(actor._on_player_shot_resolved)
	var resolved_damage = damage
	var resolved_penetration = data.penetration_power
	var blood_round = false
	var blood_budget_per_projectile = 0
	var overload_round: bool = not enemy_owned and is_instance_valid(actor.blood_resource) and actor.blood_resource.blood_ammo_mode and actor.blood_resource.last_shot_overload
	if overload_round:
		blood_round = true
		blood_budget_per_projectile = floori(actor.blood_resource.last_shot_blood_cost * 0.72 / actor.blood_resource.RAW_TO_RESOURCE / maxi(1,data.pellet_count))
	var rage_round: bool = not enemy_owned and is_instance_valid(actor.blood_resource) and actor.blood_resource.blood_rage_mode and actor.player.gun.last_shot_rage
	if rage_round:
		blood_round = true
		var rage_enhancement: Dictionary = actor.blood_resource.resolve_rage_round(actor.player.gun.current_shot_id)
		resolved_damage = maxi(1, roundi(float(damage) * float(rage_enhancement.damage_multiplier)))
		resolved_penetration += float(rage_enhancement.penetration_bonus)
		# Rage is bounded by its recovery rate, not the retired paid-shot ledger.
		# Give the stronger spray headroom without multiplying a trigger's mass by pellets.
		blood_budget_per_projectile = maxi(120000, roundi(data.blood_power * 240000.0)) / maxi(1, data.pellet_count)
	if actor.roguelike_mode and not enemy_owned and is_instance_valid(actor.blood_resource) and not actor.blood_resource.blood_ammo_mode and not actor.blood_resource.blood_rage_mode:
		var shot_id: int = int(actor.player.gun.current_shot_id) if is_instance_valid(actor.player) and is_instance_valid(actor.player.gun) else -1
		var enhancement: Dictionary = actor.blood_resource.consume_enhanced_round(shot_id, is_instance_valid(actor.player.gun) and actor.player.gun.ammo == 0)
		blood_round = bool(enhancement.enhanced)
		if blood_round:
			resolved_damage = maxi(1, roundi(float(damage) * float(enhancement.damage_multiplier)))
			resolved_penetration += float(enhancement.penetration_bonus)
			# One trigger pull owns one finite return budget. Multi-pellet weapons
			# divide it so a shotgun cannot duplicate blood for every pellet.
			blood_budget_per_projectile = floori(float(enhancement.raw_blood_budget) / float(maxi(1, data.pellet_count)))
	bullet.setup(direction, enemy_owned, resolved_damage, weapon_id, origin, data.bullet_speed, shooter, resolved_penetration, data.property_damage, data.damage_falloff_start, data.damage_falloff_end, data.minimum_damage_ratio)
	bullet.blood_stain_radius = data.blood_stain_radius
	bullet.rage_visual = rage_round
	bullet.breach_round = overload_round or rage_round
	# Detach from the equipped resource: swapping/modifying a gun must not
	# retroactively change an in-flight projectile's terrain signature.
	bullet.weapon_source = data.duplicate(true) as GunData
	# The fire event precedes the projectile event. Color the same-frame muzzle
	# only after the gameplay ledger actually paid for this trigger pull.
	if not enemy_owned and actor.player_muzzle_flash != null:
		var active_flash = actor.player_muzzle_flash.get_ref()
		if is_instance_valid(active_flash): active_flash.set_blood_enhanced(blood_round)
	if blood_round and bullet.has_method("set_blood_enhanced"): bullet.set_blood_enhanced(true, blood_budget_per_projectile, 1.38)
	if enemy_owned and bullet.has_method("set_combat_time_scale"): bullet.set_combat_time_scale(actor.hostile_combat_time_scale)

