extends Node

class Source:
	extends Node
	var enabled := true
	var radius := 0.0
	var half_angle := 0.0
	var removed := 0
	func absorb_siphon_sector(origin: Vector2, _direction: Vector2, reach: float, angle: float, _near: float, budget: int) -> Dictionary:
		radius = reach
		half_angle = angle
		removed += budget if enabled else 0
		return {"amount": budget if enabled else 0, "positions": PackedVector2Array([origin + Vector2(8,0)]) if enabled else PackedVector2Array()}

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var level = load("res://scenes/main.tscn").instantiate()
	level.record_progress = false
	add_child(level)
	level._on_entry_loadout_confirmed(LoadoutCatalog.get_kit("balanced"))
	level.set_process(false)
	level.set_physics_process(false)
	var player = level.player
	player.set_physics_process(false)
	player.set_process(false)
	player.global_position = Vector2(-500,-500)
	player.controls_enabled = true
	for enemy in level.get_node("Enemies").get_children(): enemy.set_physics_process(false)
	var blood = level.blood_resource
	var gun = player.gun
	assert(blood.blood_rage_mode and not blood.blood_ammo_mode and blood.reserve == 0.0)
	assert(not gun.blood_fire_payment.is_valid() and gun.rage_fire_active.is_valid())
	assert(level.hud.resource_backplate.visible and level.hud.ammo_label.visible)
	var ammo_rect: Rect2 = level.hud.resource_backplate.get_rect()
	assert(ammo_rect.position.y >= 140 and ammo_rect.size == Vector2(100,34))
	assert(not ammo_rect.intersects(level.hud.vitality_backplate.get_rect()))
	assert(not ammo_rect.intersects(level.hud.blood_backplate.get_rect()))
	assert(not ammo_rect.intersects(level.hud.tutorial_label.get_rect()))
	assert(ammo_rect.encloses(level.hud.ammo_label.get_rect()))
	assert(level.hud.blood_meter.vertical)
	assert(level.hud.blood_meter.size.y > level.hud.blood_meter.size.x * 2)
	assert(level.hud.blood_backplate.get_rect().encloses(level.hud.blood_meter.get_rect()))
	assert(level.hud._compact_ammo("07/07  +∞") == "07 +INF")
	assert(level.hud._compact_ammo("30/30  +120") == "30 +120")
	var source := Source.new()
	add_child(source)
	for id in WeaponPlatformCatalog.get_weapon_ids():
		gun.set_gun_data(AttackCatalog.get_gun_data(id), true)
		gun.ammo = 2
		gun.cooldown = 0
		assert(gun.try_fire(Vector2.RIGHT), "Normal fire: " + id)
		assert(gun.ammo == 1 and blood.reserve == 0.0 and not gun.last_shot_rage)
	gun.ammo = 0
	gun.reserve_ammo = 12
	gun.cooldown = 0
	assert(not gun.try_fire(Vector2.RIGHT))
	Input.action_press("reload")
	await get_tree().physics_frame
	player._physics_process(0.016)
	Input.action_release("reload")
	assert(gun.is_reloading, "Conventional reload must be restored")
	blood.set_stance_active(true)
	for i in 43: blood.update_system(0.04, player, source)
	assert(blood.is_raging() and blood.reserve > 95.0, "RMB fills meter and starts rage")
	assert(not gun.is_reloading and gun.reload_timer.is_stopped(), "Rage cancels reload without transferring ammo")
	assert(gun.ammo == 0 and gun.reserve_ammo == 12)
	blood.set_stance_active(false)
	assert(blood.get_movement_multiplier() == 1.25)
	player.set_blood_rage_visual(true,0.1)
	assert(player.lifecycle_rig.material == player.blood_skin_material)
	assert(player.legs_visual.material == player.blood_skin_material)
	assert(player.blood_skin_material.get_shader_parameter("flow_clock") > 0.0)
	for id in WeaponPlatformCatalog.get_weapon_ids():
		gun.set_gun_data(AttackCatalog.get_gun_data(id), true)
		gun.ammo = 0
		gun.reserve_ammo = 0
		gun.cooldown = 0
		var before: float = blood.reserve
		assert(gun.try_fire(Vector2.RIGHT), "Unlimited rage fire: " + id)
		assert(gun.ammo == 0 and gun.reserve_ammo == 0 and blood.reserve == before and gun.last_shot_rage)
		gun.reload()
		assert(not gun.is_reloading)
	var active: Array = level.projectile_pool.active
	var red_count := 0
	for projectile in active:
		if projectile.blood_enhanced:
			red_count += 1
			assert(projectile.rage_visual)
			assert(projectile.breach_round, "Rage enables doubled terrain erosion and debris impulses")
			assert(projectile.blood_budget_raw > 0)
			var wound := DamageContext.new()
			projectile._apply_blood_enhancement(wound)
			assert(wound.external_blood_scale > 1.5 and wound.mist_scale > 1.5)
	assert(red_count > 0, "Production projectiles must actually be crimson")
	var checkpoint: Dictionary = Progression.run_session.capture(player,blood,{})
	blood._set_rage(false)
	assert(Progression.run_session.restore(checkpoint,player,blood) and blood.is_raging())
	var start: float = blood.reserve
	for i in 25: blood.update_system(0.04,player,source)
	assert(blood.reserve < start - 3.9 and blood.reserve > start - 4.1, "Even infinite nearby blood cannot sustain rage forever")
	assert(source.radius == 56.0 and source.half_angle == PI, "Rage automatically siphons all around, without RMB")
	assert(source.removed > 0)
	source.enabled = false
	blood.reserve = 0.1
	gun.ammo = 2
	gun.reserve_ammo = 12
	blood.update_system(0.04,player,source)
	assert(blood.reserve == 0 and not blood.is_raging() and blood.get_movement_multiplier() == 1.0)
	assert(gun.ammo == 2 and gun.reserve_ammo == 12)
	assert(player.lifecycle_rig.material == null and player.legs_visual.material == null)
	gun.cooldown = 0
	assert(gun.try_fire(Vector2.RIGHT) and gun.ammo == 1 and not gun.last_shot_rage)
	assert(not blood.request_skill("r") and not blood.consume_heal(player))
	# Real terrain removal, not merely a fake source returning energy.
	player.global_position = Vector2(32,32)
	for x in range(30,36):
		for y in range(30,36): level.blood_system.ground_canvas.add_blood_pixel(Vector2(x,y),255)
	var pixels_before: int = level.blood_system.ground_canvas.get_debug_pixel_count()
	blood.set_stance_active(true)
	blood.update_system(0.04,player,level.blood_system)
	assert(blood.reserve > 0 and level.blood_system.ground_canvas.get_debug_pixel_count() < pixels_before)
	blood.reserve = 100.0
	player.controls_enabled = false
	blood.update_system(0.04,player,source)
	assert(not blood.is_raging() and blood.reserve == 100.0, "Menus freeze charge and rage")
	player.controls_enabled = true
	blood.update_system(0.04,player,source)
	assert(blood.is_raging())
	player.is_dead = true
	blood.update_system(0.04,player,source)
	assert(not blood.is_raging() and blood.reserve == 0)
	level.queue_free()
	source.queue_free()
	await get_tree().process_frame
	print("BLOOD_RAGE_OK")
	get_tree().quit()
