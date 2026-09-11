extends Node

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var level = preload("res://scenes/main.tscn").instantiate()
	level.record_progress = false
	add_child(level)
	level._on_entry_loadout_confirmed(LoadoutCatalog.get_kit("balanced"))
	level.set_process(false)
	level.set_physics_process(false)
	var player = level.player
	player.set_process(false)
	player.set_physics_process(false)
	player.position = Vector2(-500, -500)
	for enemy in level.enemies_container.get_children(): enemy.set_physics_process(false)
	var blood = level.blood_resource
	var offer = level.get_node("SafeBuildOffer")
	offer.offer(3)
	level.room_run.engaged_rooms.clear()
	offer._process(1.1)
	var input := InputEventKey.new()
	input.physical_keycode = KEY_F2
	input.pressed = true
	offer._unhandled_key_input(input)
	assert("reload_breach" in blood.perks.learned and offer.consumed)
	assert(blood.build_id == "balanced", "a Rage perk must not apply a misleading retired style")
	var gun = player.gun
	gun.set_gun_data(AttackCatalog.get_gun_data("mossberg_590a1"), true)
	gun.ammo = 1
	gun.reserve_ammo = 12
	gun.reload()
	gun._on_reload_timer_timeout()
	assert(blood.perks.breach_ready, "production reload arms the reward")
	blood.reserve = 100.0
	blood._set_rage(true)
	gun.cooldown = 0
	assert(gun.try_fire(Vector2.RIGHT))
	assert(level.projectile_pool.active.size() == gun.gun_data.pellet_count)
	for bullet in level.projectile_pool.active:
		assert(is_equal_approx(bullet.penetration_power, gun.gun_data.penetration_power + 0.85 + 0.75), "every pellet receives the same one-shot upgrade")
	assert(not blood.perks.breach_ready)
	for bullet in level.projectile_pool.active.duplicate(): level.projectile_pool.release(bullet)
	gun.cooldown = 0
	assert(gun.try_fire(Vector2.RIGHT))
	for bullet in level.projectile_pool.active:
		assert(is_equal_approx(bullet.penetration_power, gun.gun_data.penetration_power + 0.85), "the next trigger must not repeat the bonus")
	for bullet in level.projectile_pool.active.duplicate(): level.projectile_pool.release(bullet)
	blood.perks.acquire("field_cycle")
	blood.perks.acquire("hot_swap")
	blood.perks.on_throw()
	gun.ammo = 0
	gun.reserve_ammo = 3
	blood.perks.on_kill(gun, blood.skill_cooldowns, gun.weapon_id)
	assert(gun.ammo == 1 and gun.reserve_ammo == 2)
	blood.update_system(1.0, player, level.blood_system)
	blood.perks.on_kill(gun, blood.skill_cooldowns, gun.weapon_id)
	assert(gun.ammo == 2 and gun.reserve_ammo == 1, "kill lock must expire in Rage mode")
	blood.update_system(4.0, player, level.blood_system)
	assert(blood.perks.swap_time == 0.0, "throw window must expire in the real update path")
	blood.perks.acquire("harvest_step")
	for x in range(-502, -495):
		for y in range(-502, -495): level.blood_system.ground_canvas.add_blood_pixel(Vector2(x,y),255)
	blood.reserve = 25.0
	blood.update_system(0.04, player, level.blood_system)
	assert(blood.perks.harvest_time > 0 and blood.get_movement_multiplier() > 1.25)
	blood.perks.acquire("blood_clock")
	assert(blood.get_rage_drain() > blood.RAGE_RECOVERY)
	var snapshot: Dictionary = Progression.run_session.capture(player, blood, {})
	blood.perks.learned.clear()
	assert(Progression.run_session.restore(snapshot, player, blood))
	assert(blood.perks.capture() == snapshot.combat_perks, "floor transfers preserve real rewards and remaining timers")
	for bullet in level.projectile_pool.active.duplicate(): level.projectile_pool.release(bullet)
	level.player_shot_records.clear()
	var previous_limit: int = RuntimeBudget.limits.bullet
	RuntimeBudget.limits.bullet = 0
	gun.cooldown = 0.0
	assert(gun.try_fire(Vector2.RIGHT))
	assert(level.player_shot_records.is_empty(), "pool saturation must settle every rejected pellet")
	RuntimeBudget.limits.bullet = previous_limit
	level.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("RAGE_PERK_INTEGRATION_OK")
	get_tree().quit()
