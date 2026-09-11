extends Node2D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const PICKUP_SCENE := preload("res://scenes/props/weapon_pickup.tscn")
var failures := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.set_physics_process(false)
	_expect(player.owned_gun_indices == [0], "player must begin with pistol only")
	_expect(player.acquire_gun("hk_mp5a5", 7), "MP5 acquisition must succeed")
	_expect(player.gun.weapon_id == "hk_mp5a5" and player.gun.ammo == 7, "acquired MP5 must equip with dropped rounds")
	player.gun.ammo = 4
	player.gun.ammo_by_weapon["hk_mp5a5"] = 4
	player._cycle_gun()
	_expect(player.gun.weapon_id == "glock_17_gen5_mos" and player.gun.ammo == 17, "cycling must restore Glock magazine")
	player._cycle_gun()
	_expect(player.gun.weapon_id == "hk_mp5a5" and player.gun.ammo == 4, "cycling must preserve MP5 magazine")
	var pickup = PICKUP_SCENE.instantiate()
	pickup.setup("fn_m249_para", 9)
	add_child(pickup)
	_expect(pickup.collect(player), "LMG pickup must be collectible")
	_expect(not pickup.collect(player), "a pickup cannot transfer its ammunition twice before queue_free completes")
	_expect(player.gun.weapon_id == "fn_m249_para" and player.gun.ammo == 9, "pickup must equip M249 with stored rounds")
	_expect(player.owned_gun_indices.size() == 3, "all collected guns must enter inventory")
	player.gun.set_weapon_ammo("fn_m249_para", 98)
	player.gun.set_reserve_ammo("fn_m249_para", 0)
	_expect(player.acquire_gun("fn_m249_para", 12), "duplicate M249 pickup must be accepted")
	_expect(player.gun.ammo == 100 and player.gun.reserve_ammo == 10, "duplicate weapon rounds above magazine capacity must overflow into reserve")
	var empty_pickup = PICKUP_SCENE.instantiate()
	empty_pickup.setup("hk_mp5a5", 0)
	add_child(empty_pickup)
	_expect(empty_pickup.rounds == 0, "weapon pickups must not fabricate ammunition")
	var pistol_data = AttackCatalog.get_gun_data("glock_17_gen5_mos")
	var smg_data = AttackCatalog.get_gun_data("hk_mp5a5")
	var lmg_data = AttackCatalog.get_gun_data("fn_m249_para")
	_expect(pistol_data.spread_degrees < smg_data.spread_degrees, "pistol should remain the precision weapon")
	_expect(smg_data.automatic and smg_data.recoil_strength < pistol_data.recoil_strength, "MP5 should trade handgun mobility for controllable automatic fire")
	_expect(lmg_data.movement_speed_multiplier < pistol_data.movement_speed_multiplier, "LMG weight should slow its carrier")
	_expect(lmg_data.reload_duration > smg_data.reload_duration, "LMG should expose a longer reload vulnerability")
	_expect(lmg_data.maximum_spread_bonus > smg_data.maximum_spread_bonus, "LMG sustained fire should become the least accurate")
	player.gun.set_gun_data(lmg_data, false)
	_expect(is_equal_approx(player.get_equipped_movement_multiplier(), lmg_data.movement_speed_multiplier), "equipped LMG movement penalty should be active")
	player.configure_field_kit(LoadoutCatalog.get_kit("assault"))
	_expect(player.gun.get_current_spread_degrees() >= 0.0 and player.gun.get_spread_feedback_ratio() >= 0.0, "equipped guns should expose readable live spread feedback for the combat reticle")
	_expect(player.owned_gun_indices.size() == 2 and player.gun.weapon_id == "fn_m249_para", "assault kit should issue its authored M249 and shotgun")
	_expect(player.gun.ammo == lmg_data.ammo_capacity and player.gun.reserve_ammo == lmg_data.ammo_capacity, "assault kit must deploy with a full M249 and one reserve belt")
	var shotgun_data := AttackCatalog.get_gun_data("mossberg_590a1")
	_expect(player.gun.get_weapon_ammo("mossberg_590a1") == shotgun_data.ammo_capacity and player.gun.get_reserve_ammo("mossberg_590a1") == shotgun_data.ammo_capacity, "every secondary assault-kit weapon must be initialized with ammunition")
	player.configure_field_kit(LoadoutCatalog.get_kit("stealth"))
	_expect(player.owned_gun_indices.size() == 2 and player.gun.weapon_id == "hk_mp5a5" and player.gun.field_noise_multiplier < 0.8, "ghost kit should issue two retained low-signature platforms")
	var stealth_data := AttackCatalog.get_gun_data("hk_mp5sd6")
	_expect(player.gun.ammo == stealth_data.ammo_capacity and player.gun.reserve_ammo == stealth_data.ammo_capacity * 2, "switching briefing kits must reset the issued primary to a usable state")
	# Fresh-trigger semantics on the real player input handler.
	player.gun.set_weapon_ammo(player.gun.weapon_id, 0)
	player.gun.set_reserve_ammo(player.gun.weapon_id, 5)
	player._handle_primary_input(false, true)
	_expect(not player.gun.is_reloading, "holding the last shot must not automatically start another magazine")
	player._handle_primary_input(true, true)
	_expect(player.gun.is_reloading and player.gun.ammo == 0 and player.gun.reserve_ammo == 5, "fresh left click should begin reloading without creating rounds early")
	await get_tree().process_frame
	player.gun._on_reload_timer_timeout()
	_expect(player.gun.ammo == 5 and player.gun.reserve_ammo == 0, "auto reload must transfer only the finite reserve")
	player.gun.set_weapon_ammo(player.gun.weapon_id, 0)
	player.gun.cooldown = 0.0
	var before_owned: Array = player.owned_gun_indices.duplicate()
	player._handle_primary_input(true, true)
	_expect(not player.gun.is_reloading and player.gun.ammo == 0 and player.owned_gun_indices == before_owned and player.gun.cooldown > 0.0, "fully empty left click must give dry feedback and keep the gun")
	await get_tree().process_frame
	player.gun.set_weapon_ammo(player.gun.weapon_id, 5)
	player.gun.cooldown = 0.0
	Input.action_press("shoot")
	player._cycle_gun()
	var switched_ammo: int = player.gun.ammo
	player._handle_primary_input(false, true)
	_expect(player.primary_requires_release and player.gun.ammo == switched_ammo, "held trigger must not fire a newly switched weapon")
	Input.action_release("shoot")
	player._handle_primary_input(false, false)
	player.gun.cooldown = 0.0
	player._handle_primary_input(true, true)
	_expect(player.gun.ammo == switched_ammo - 1, "releasing and pressing again must fire the new weapon")
	await get_tree().process_frame
	player.gun.set_weapon_ammo(player.gun.weapon_id, 0)
	player.gun.set_reserve_ammo(player.gun.weapon_id, 10)
	player.gun.reload()
	await get_tree().process_frame
	player._equip_weapon("fist")
	player.gun._on_reload_timer_timeout()
	_expect(not player.gun.is_reloading and player.gun.ammo == 0 and player.gun.reserve_ammo == 10, "switching to melee cancels reload without moving reserve ammunition")
	var carried: Dictionary = player.capture_run_loadout()
	player.configure_field_kit(LoadoutCatalog.get_kit("assault"))
	player.restore_run_loadout(carried)
	if player.capture_run_loadout() != carried:
		print("expected loadout: ", carried)
		print("restored loadout: ", player.capture_run_loadout())
	_expect(player.capture_run_loadout() == carried, "room transitions must preserve full inventory, attachments, magazines, reserves and melee selection exactly")
	player._equip_weapon("gun")
	while not player.owned_gun_indices.is_empty(): player.throw_equipped_gun(Vector2.RIGHT)
	var unarmed: Dictionary = player.capture_run_loadout()
	player.configure_field_kit(LoadoutCatalog.get_kit("assault"))
	player.restore_run_loadout(unarmed)
	_expect(player.owned_gun_indices.is_empty() and player.equipped_mode == "melee" and player.gun.gun_data == null, "an unarmed room checkpoint must never gift a starter gun")
	if failures == 0: print("weapon inventory regression: PASS")
	for audio_node in player.find_children("*", "AudioStreamPlayer", true, false):
		(audio_node as AudioStreamPlayer).stop()
		(audio_node as AudioStreamPlayer).stream = null
	# Multiple input cases play/replace streams in one frame. Allow the audio
	# mixer to retire those playbacks before tearing down its owning nodes.
	await get_tree().create_timer(0.12).timeout
	player.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(failures)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
