class_name CombatEventController
extends Node
## Owned by CombatLevel. Compatibility callbacks on the level delegate here.
var level: CombatLevel
var shot_records: Dictionary[int, ShotRecord] = {}

func handle_weapon_fired(event: WeaponFiredEvent) -> void:
	var origin := event.origin
	var direction := event.direction
	var enemy_owned := event.enemy_owned
	var weapon_id := event.weapon_id
	if not enemy_owned:
		level.combat_shots_fired += 1
		level.mission_tracker.record_player_shot(weapon_id)
		level._show_scene_consequence("BALLISTIC +1 // %s" % weapon_id.to_upper())
		var shot_id: int = level.player.gun.current_shot_id if is_instance_valid(level.player) and is_instance_valid(level.player.gun) else -1
		if shot_id >= 0:
			var shot_data: GunData = level.player.gun.gun_data if is_instance_valid(level.player) and is_instance_valid(level.player.gun) and level.player.gun.weapon_id == weapon_id else AttackCatalog.get_gun_data(weapon_id)
			shot_records[shot_id] = ShotRecord.new(shot_data.pellet_count, weapon_id)
	var data: GunData = level.player.gun.gun_data if not enemy_owned and is_instance_valid(level.player) and is_instance_valid(level.player.gun) and level.player.gun.weapon_id == weapon_id else AttackCatalog.get_gun_data(weapon_id)
	# Incoming fire is legible in world space; it must not shake the player's aim
	# simply because an unseen enemy pulled a trigger.
	if not enemy_owned: level.trauma_camera.add_trauma(data.camera_shake * 0.14)
	var casing = level.SHELL_CASING_SCENE.instantiate()
	if RuntimeBudget.try_add("shell", casing, level):
		var perpendicular = direction.rotated(PI * 0.5)
		casing.global_position = origin - direction * randf_range(4.5, 7.5) + perpendicular * randf_range(-1.8, 1.8)
		casing.rotation = randf_range(-PI, PI)
		casing.setup(direction, enemy_owned)
	var flash = level.MUZZLE_FLASH_SCENE.instantiate()
	flash.position = level.to_local(origin)
	flash.setup(direction, data.muzzle_flash_size, data.muzzle_flash_duration)
	if RuntimeBudget.try_add("transient_fx", flash, level) and not enemy_owned:
		level.player_muzzle_flash = weakref(flash)

func _on_precision_reward(weapon_id: String, streak: int) -> void:
	if level.phase != "combat" or level.run_over: return
	level.precision_reward_bonus += 120
	level.hud.show_banner("CLEAN MAG // FAST RELOAD ARMED", Color("ff68c8"))
	level.detail_label.text = "%s PRECISION x%d // EMPTY MAG RELOAD BOOST" % [weapon_id.to_upper(), streak]

func handle_shot_resolved(event: ShotResolvedEvent) -> void:
	var shot_id := event.shot_id
	var outcome := event.outcome
	var lethal := event.lethal
	if not shot_records.has(shot_id): return
	var record: ShotRecord = shot_records[shot_id]
	if outcome == ShotResolvedEvent.Outcome.ENEMY and lethal and level.roguelike_mode and is_instance_valid(level.blood_resource):
		level.blood_resource.perks.on_kill(level.player.gun, level.blood_resource.skill_cooldowns, str(record.weapon_id))
	record.accept(event)
	if outcome == ShotResolvedEvent.Outcome.ENEMY:
		if not bool(record.reported):
			record.reported = true
			if is_instance_valid(level.player) and is_instance_valid(level.player.gun): level.player.gun.report_shot_result(true, lethal)
	elif outcome == ShotResolvedEvent.Outcome.OVERKILL:
		level._show_scene_consequence("BIOLOGICAL +1 // OVERKILL")
	if record.is_complete():
		if not bool(record.reported) and is_instance_valid(level.player) and is_instance_valid(level.player.gun):
			level.player.gun.report_shot_result(false, false)
		shot_records.erase(shot_id)
	else:
		shot_records[shot_id] = record

func _on_enemy_died(pos: Vector2, facing: float, defeated_enemy: Node = null) -> void:
	level.enemies_killed += 1
	level.remaining_enemies = maxi(0, level.remaining_enemies - 1)
	level.mission_tracker.record_enemy_eliminated()
	level.combo += 1
	level.best_combo = maxi(level.best_combo, level.combo)
	level.combo_timer = 2.2
	level._reward_combat_focus(level.pending_death_attack_id, level.pending_death_hit_zone, level.combo)
	level.trauma_camera.trigger_kill_effect(0.72, "red", level.pending_death_direction)
	var room_finish = _is_last_room_target(defeated_enemy)
	if room_finish or (level.combo >= 10 and level.combo % 10 == 0):
		level.combat_feedback.trigger_finisher(room_finish, Settings.hit_stop_strength)
	var corpse = level.CORPSE_SCENE.instantiate()
	corpse.position = level.to_local(pos)
	var rig_kind = "hound" if is_instance_valid(defeated_enemy) and str(defeated_enemy.actor_type) == "dog" else "human"
	var living_pose: Dictionary = defeated_enemy.get_lifecycle_pose() if is_instance_valid(defeated_enemy) and defeated_enemy.has_method("get_lifecycle_pose") else {}
	corpse.setup(facing, level.pending_death_direction, level.pending_death_knockback, level.pending_death_blood_power, level.pending_death_style, level.pending_death_hit_zone, level.pending_death_attack_id, level.pending_death_travel_distance, rig_kind, "enemy", living_pose)
	RuntimeBudget.add_persistent("corpse", corpse, level)
	level._show_scene_consequence("BODY +25 // BIOLOGICAL LOAD %s" % ("EXTREME" if level.pending_death_blood_power >= 1.7 else ("HIGH" if level.pending_death_blood_power >= 1.2 else "STANDARD")))
	var pool_offset = level.pending_death_hit_position - pos if level.pending_death_hit_position != Vector2.ZERO else Vector2.ZERO
	if is_instance_valid(defeated_enemy) and defeated_enemy.get_meta("polluter", false):
		level.blood_system.ground_canvas.stamp_pollution(pos, 23.0)
	elif level.pending_death_blood_enhanced:
		level.blood_system.spawn_death_burst_budgeted(pos, level.pending_death_blood_power, pool_offset, level.pending_death_direction, level.pending_death_attack_id, level.pending_death_blood_budget_raw, level.pending_death_stain_radius)
	else:
		level.blood_system.spawn_death_burst(pos, level.pending_death_blood_power, pool_offset, level.pending_death_direction, level.pending_death_attack_id, level.pending_death_stain_radius)
	Events.publish_casualty(pos, level.pending_death_direction)
	if is_instance_valid(defeated_enemy) and defeated_enemy.enemy_type == "gunner":
		var remaining_rounds: int = defeated_enemy.gun.ammo
		# The weapon is physical evidence even when the enemy emptied its magazine.
		level._spawn_weapon_pickup(pos, defeated_enemy.gun.weapon_id, remaining_rounds, defeated_enemy.gun.gun_data.installed_attachments if defeated_enemy.gun.gun_data != null else PackedStringArray())
	level.pending_death_style = "firearm"
	level.pending_death_hit_zone = "torso"
	level.pending_death_hit_position = Vector2.ZERO
	level.pending_death_attack_id = "pistol"
	level.pending_death_travel_distance = 0.0
	level.pending_death_blood_enhanced = false
	level.pending_death_blood_budget_raw = -1
	level.pending_death_stain_radius = -1.0
	level._update_combat_objective_hud()

func _on_weapon_throw_requested(origin: Vector2, direction: Vector2, weapon_id: String, rounds: int, attachment_ids: PackedStringArray) -> void:
	if level.phase != "combat" or level.run_over: return
	var thrown_weapon = level.THROWN_WEAPON_SCENE.instantiate()
	# This is player inventory in flight, not disposable visual budget.
	if not RuntimeBudget.add_persistent("thrown_weapon", thrown_weapon, level): return
	if level.roguelike_mode and is_instance_valid(level.blood_resource): level.blood_resource.perks.on_throw()
	thrown_weapon.global_position = origin
	thrown_weapon.setup(direction, weapon_id, rounds, attachment_ids)

func _on_blood_impact(hit_position: Vector2, direction: Vector2, damage: int, weapon_id: String, travel_distance: float, lethal: bool, hit_zone: String) -> void:
	_on_damage_impact(DamageContext.create(hit_position, direction, damage, weapon_id, travel_distance, lethal, hit_zone))

func _on_damage_impact(context: DamageContext) -> void:
	# Only living hostile flesh feeds the roguelike blood economy. Player hits,
	# player death and corpse overkill retain impact feedback without creating a
	# self-recycling blood source under the player.
	context.configure_blood_yield(is_instance_valid(level.blood_resource) and level.blood_resource.blood_ammo_mode, level.combo if level.combo_timer > 0.0 else 0)
	if context.blood_enhanced and is_instance_valid(level.blood_resource) and level.blood_resource.blood_rage_mode:
		context.blood_yield_multiplier = 2.0
	if is_instance_valid(context.target) and context.target.is_in_group("enemy") and context.target is Actor and not context.target.is_dead and context.target.hp > 0 and context.damage > 0:
		if context.target.get_meta("polluter", false):
			# Lethal patch is stamped once in _on_enemy_died. Limit repeated
			# nonlethal pellet hits to one surface upload burst per 150 ms.
			var now = Time.get_ticks_msec()
			if not context.lethal and now >= int(context.target.get_meta("next_pollution_ms", 0)):
				context.target.set_meta("next_pollution_ms", now + 150)
				level.blood_system.ground_canvas.stamp_pollution(context.hit_position, 12.0)
		else:
			level.blood_system.emit_context(context)
	var hit_position = context.hit_position
	var direction = context.direction
	var weapon_id = context.weapon_id
	var lethal = context.lethal
	if is_instance_valid(context.target) and context.target != level.player:
		var feedback_kind = "armour" if context.armor_absorbed >= float(context.damage) * 0.42 else ("head" if context.hit_zone == "head" else "flesh")
		level.hud.show_hit_confirmation(feedback_kind, lethal)
		level.combat_feedback.trigger_hit_confirmation(feedback_kind, lethal)
	if is_instance_valid(context.target) and context.target.has_method("apply_lifecycle_impact"):
		var target_rig = "hound" if context.target.is_in_group("enemy") and str(context.target.get("actor_type")) == "dog" else "human"
		var physical = level.RAGDOLL_IMPACT.resolve(weapon_id, context.travel_distance, context.hit_zone, target_rig)
		var force_scale = 0.66 if context.blood_enhanced else 0.58
		context.target.apply_lifecycle_impact(direction, float(physical.limb_force) * force_scale, context.hit_zone)
	if lethal:
		var data = AttackCatalog.get_gun_data(weapon_id)
		if context.target == level.player:
			level.last_player_death_cause = weapon_id.to_upper()
			level.pending_player_death_context = {
				"direction": direction,
				"knockback": data.knockback,
				"blood_power": data.blood_power,
				"style": data.death_style,
				"hit_zone": context.hit_zone,
				"hit_position": hit_position,
				"attack_id": weapon_id,
				"travel_distance": context.travel_distance,
			}
		else:
			level.pending_death_direction = direction
			level.pending_death_knockback = data.knockback * (1.12 if context.blood_enhanced else 1.0)
			level.pending_death_blood_power = data.blood_power * (1.48 if context.blood_enhanced else 1.0)
			if context.blood_enhanced:
				var weapon_class = str(data.weapon_class)
				level.pending_death_style = "firearm_gib" if context.hit_zone == "head" or weapon_class in ["shotgun", "sniper", "lmg"] else "firearm_torn"
			else:
				level.pending_death_style = data.death_style
			level.pending_death_hit_zone = context.hit_zone
			level.pending_death_hit_position = hit_position
			level.pending_death_attack_id = weapon_id
			level.pending_death_travel_distance = context.travel_distance
			level.pending_death_blood_enhanced = context.blood_enhanced
			level.pending_death_blood_budget_raw = context.blood_budget_raw
			level.pending_death_stain_radius = context.blood_stain_radius
			# A lethal impact transfers ownership of the remaining finite blood
			# ledger to the terminal burst spawned by _on_enemy_died. Clear the
			# projectile context now so a through-shot cannot reuse the same mass on
			# every downstream body after the death signal returns.
			if context.blood_enhanced: context.blood_budget_raw = 0
		if is_instance_valid(context.target) and context.target.is_in_group("enemy"):
			level.combat_feedback.trigger_critical_hit_stop(true, context.hit_zone == "head", Settings.hit_stop_strength)
	elif is_instance_valid(context.target) and context.target != level.player:
		# Body-hit pellets use local stagger/flash, leaving the global beat for kills/headshots.
		level.combat_feedback.trigger_critical_hit_stop(false, context.hit_zone == "head", Settings.hit_stop_strength)

func _on_melee_impact(target: CharacterBody2D, hit_position: Vector2, direction: Vector2, melee_type: String, lethal: bool) -> void:
	if not is_instance_valid(target) or target.is_dead: return
	if not lethal:
		target.take_door_hit(direction, "knockdown")
		level.trauma_camera.add_trauma(0.16)
		return
	var profile = AttackCatalog.get_impact_profile(melee_type)
	if target.has_method("apply_lifecycle_impact"): target.apply_lifecycle_impact(direction, float(profile.knockback) * 0.72, "torso")
	level.pending_death_direction = direction
	level.pending_death_knockback = float(profile.knockback)
	level.pending_death_blood_power = float(profile.blood_power)
	level.pending_death_style = str(profile.style)
	level.pending_death_attack_id = melee_type
	level.pending_death_hit_position = hit_position
	level.pending_death_travel_distance = target.global_position.distance_to(level.player.global_position) if is_instance_valid(level.player) else 0.0
	level.blood_system.emit_hit(hit_position, direction, 1, melee_type, 0.0, true)
	level.trauma_camera.add_trauma(float(profile.trauma))
	level._on_impact_flash_requested(Color(1.0, 0.06, 0.35, 0.2 if melee_type == "bat" else 0.13))
	level._trigger_hit_stop(float(profile.hit_stop))
	target.take_damage(maxi(1, target.hp), hit_position - direction * 2.0)

func _is_last_room_target(target: Node) -> bool:
	if not is_instance_valid(target) or not is_instance_valid(level.room_run): return level.remaining_enemies == 0
	var room_id = str(target.get_meta("rogue_room_id", ""))
	if room_id.is_empty() or not level.room_run.room_members.has(room_id): return level.remaining_enemies == 0
	for member in level.room_run.room_members[room_id]:
		if is_instance_valid(member) and member != target and not member.is_dead: return false
	return true

func _on_player_directional_hit(amount: int, source_position: Vector2) -> void:
	if amount <= 0 or not is_instance_valid(level.player): return
	level.trauma_camera.add_directional_impulse(level.player.global_position - source_position, 2.8)
	level.trauma_camera.add_trauma(0.20)

func _on_execution_impact(hit_position: Vector2, direction: Vector2, lethal: bool, execution_type: String) -> void:
	var attack_id = execution_type if lethal else "fist"
	level.blood_system.emit_hit(hit_position, direction, 1, attack_id, 0.0, lethal)
	level.trauma_camera.add_trauma(0.42 if lethal else 0.2)
	level.trauma_camera.add_directional_impulse(-direction, 4.0 if lethal else 1.0)
	if lethal:
		var profile = AttackCatalog.get_impact_profile(execution_type)
		level.pending_death_direction = direction
		level.pending_death_knockback = float(profile.knockback)
		level.pending_death_blood_power = float(profile.blood_power)
		level.pending_death_style = str(profile.style)
		level.pending_death_attack_id = attack_id
		level.pending_death_hit_position = hit_position
		level.pending_death_travel_distance = 0.0
		level._on_impact_flash_requested(Color(0.9, 0.02, 0.12, 0.28))
		level._trigger_hit_stop(float(profile.hit_stop))

func _on_player_died(source_position := Vector2.ZERO) -> void:
	if level.run_over: return
	level.final_grade = ""
	level.blood_resource.set_stance_active(false)
	if is_instance_valid(level.playtest_telemetry):
		var world = level.get_node_or_null("TileMap")
		var room_id: String = str(world.get_tactical_room_id(level.player.global_position)) if is_instance_valid(world) and world.has_method("get_tactical_room_id") else "unknown"
		level.playtest_telemetry.record_death(level.player.global_position, room_id)
	level.run_over = true
	if is_instance_valid(level.player) and level.player.has_method("set_controls_enabled"): level.player.set_controls_enabled(false)
	_spawn_player_death_ragdoll(source_position)
	level.trauma_camera.add_trauma(1.0)
	level._trigger_death_flash()
	level.status_label.text = "YOU ARE DEAD"
	var attack_direction = "UNKNOWN"
	if source_position != Vector2.ZERO and is_instance_valid(level.player):
		var delta = source_position - level.player.global_position
		if absf(delta.x) > absf(delta.y): attack_direction = "EAST" if delta.x > 0.0 else "WEST"
		else: attack_direction = "SOUTH" if delta.y > 0.0 else "NORTH"
	level.detail_label.text = "%s FROM %s // R TO RESTART" % [level.last_player_death_cause, attack_direction]
	level._show_run_end_prompt("YOU DIED // ATTACK FROM %s" % attack_direction, false)

func _spawn_player_death_ragdoll(source_position: Vector2) -> void:
	if not is_instance_valid(level.player) or is_instance_valid(level.player_death_corpse): return
	var death: Dictionary = level.pending_player_death_context.duplicate()
	if death.is_empty():
		var attack_id = "fist"
		var closest_distance = INF
		for enemy_node in level.get_tree().get_nodes_in_group("enemy"):
			if not enemy_node is Node2D or not is_instance_valid(enemy_node): continue
			var distance = (enemy_node as Node2D).global_position.distance_to(source_position)
			if distance < closest_distance:
				closest_distance = distance
				attack_id = "hound_bite" if str(enemy_node.get("actor_type")) == "dog" else "fist"
		var profile = AttackCatalog.get_impact_profile(attack_id)
		var direction = source_position.direction_to(level.player.global_position)
		if direction.length_squared() < 0.001: direction = Vector2.RIGHT.rotated(level.player.rotation)
		death = {
			"direction": direction,
			"knockback": profile.knockback,
			"blood_power": profile.blood_power,
			"style": profile.style,
			"hit_zone": "torso",
			"hit_position": level.player.global_position,
			"attack_id": attack_id,
			"travel_distance": closest_distance if closest_distance < INF else 0.0,
		}
		level.last_player_death_cause = attack_id.to_upper().replace("_", " ")
	var corpse = level.CORPSE_SCENE.instantiate()
	corpse.position = level.to_local(level.player.global_position)
	var living_pose: Dictionary = level.player.get_lifecycle_pose() if level.player.has_method("get_lifecycle_pose") else {}
	corpse.setup(
		level.player.rotation,
		death.get("direction", Vector2.RIGHT),
		float(death.get("knockback", 18.0)),
		float(death.get("blood_power", 1.0)),
		str(death.get("style", "melee")),
		str(death.get("hit_zone", "torso")),
		str(death.get("attack_id", "fist")),
		float(death.get("travel_distance", 0.0)),
		"human",
		"player",
		living_pose
	)
	RuntimeBudget.add_persistent("player_ragdoll", corpse, level)
	level.player_death_corpse = corpse
	level.player.collision_layer = 0
	level.player.collision_mask = 0
	level.player.visible = false
	level.pending_player_death_context.clear()
