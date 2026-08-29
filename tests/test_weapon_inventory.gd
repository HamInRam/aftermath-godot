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
	_expect(player.acquire_gun("smg", 7), "SMG acquisition must succeed")
	_expect(player.gun.weapon_id == "smg" and player.gun.ammo == 7, "acquired SMG must equip with dropped rounds")
	player.gun.ammo = 4
	player.gun.ammo_by_weapon["smg"] = 4
	player._cycle_gun()
	_expect(player.gun.weapon_id == "pistol" and player.gun.ammo == 12, "cycling must restore pistol magazine")
	player._cycle_gun()
	_expect(player.gun.weapon_id == "smg" and player.gun.ammo == 4, "cycling must preserve SMG magazine")
	var pickup = PICKUP_SCENE.instantiate()
	pickup.setup("lmg", 9)
	add_child(pickup)
	_expect(pickup.collect(player), "LMG pickup must be collectible")
	_expect(player.gun.weapon_id == "lmg" and player.gun.ammo == 9, "pickup must equip LMG with stored rounds")
	_expect(player.owned_gun_indices.size() == 3, "all collected guns must enter inventory")
	player.gun.set_weapon_ammo("lmg", 58)
	player.gun.set_reserve_ammo("lmg", 0)
	_expect(player.acquire_gun("lmg", 12), "duplicate LMG pickup must be accepted")
	_expect(player.gun.ammo == 60 and player.gun.reserve_ammo == 10, "duplicate weapon rounds above magazine capacity must overflow into reserve")
	var empty_pickup = PICKUP_SCENE.instantiate()
	empty_pickup.setup("smg", 0)
	add_child(empty_pickup)
	_expect(empty_pickup.rounds == 0, "weapon pickups must not fabricate ammunition")
	var pistol_data = player.PLAYER_GUNS[0]
	var smg_data = player.PLAYER_GUNS[1]
	var lmg_data = player.PLAYER_GUNS[2]
	_expect(pistol_data.spread_degrees < smg_data.spread_degrees, "pistol should remain the precision weapon")
	_expect(smg_data.movement_speed_multiplier > pistol_data.movement_speed_multiplier, "SMG should support the fastest assault movement")
	_expect(lmg_data.movement_speed_multiplier < pistol_data.movement_speed_multiplier, "LMG weight should slow its carrier")
	_expect(lmg_data.reload_duration > smg_data.reload_duration, "LMG should expose a longer reload vulnerability")
	_expect(lmg_data.maximum_spread_bonus > smg_data.maximum_spread_bonus, "LMG sustained fire should become the least accurate")
	player.gun.set_gun_data(lmg_data, false)
	_expect(is_equal_approx(player.get_equipped_movement_multiplier(), 0.78), "equipped LMG movement penalty should be active")
	player.configure_field_kit(LoadoutCatalog.get_kit("assault"))
	_expect(player.gun.get_current_spread_degrees() >= 0.0 and player.gun.get_spread_feedback_ratio() >= 0.0, "equipped guns should expose readable live spread feedback for the combat reticle")
	_expect(player.owned_gun_indices == [1, 2, 3] and player.gun.weapon_id == "smg", "assault kit should trade cleaning capacity for a heavy three-gun loadout")
	_expect(player.gun.ammo == smg_data.ammo_capacity and player.gun.reserve_ammo == smg_data.ammo_capacity, "assault kit must deploy with a full SMG and one reserve magazine")
	_expect(player.gun.get_weapon_ammo("lmg") == lmg_data.ammo_capacity and player.gun.get_reserve_ammo("lmg") == lmg_data.ammo_capacity, "every secondary assault-kit weapon must be initialized with ammunition")
	player.configure_field_kit(LoadoutCatalog.get_kit("stealth"))
	_expect(player.owned_gun_indices == [0] and player.gun.field_noise_multiplier < 0.6, "ghost kit should restrict the arsenal and reduce weapon report")
	_expect(player.gun.ammo == pistol_data.ammo_capacity and player.gun.reserve_ammo == pistol_data.ammo_capacity * 2, "switching briefing kits must reset the issued pistol to a usable state")
	if failures == 0: print("weapon inventory regression: PASS")
	for audio_node in player.find_children("*", "AudioStreamPlayer", true, false):
		(audio_node as AudioStreamPlayer).stop()
	player.queue_free()
	await get_tree().process_frame
	get_tree().quit(failures)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
