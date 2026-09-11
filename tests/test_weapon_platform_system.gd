extends Node

const ARMORY_SCENE := preload("res://scenes/ui/armory_screen.tscn")
const GUNSMITH_SCENE := preload("res://scenes/ui/gunsmith_screen.tscn")
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const TEST_SAVE_PATH := "user://aftermath_weapon_platform_test.json"

var failures := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_data: Dictionary = Progression.data.duplicate(true)
	var original_save_path: String = Progression.save_path
	var original_slot := Progression.editing_loadout_slot
	var original_weapon := Progression.editing_weapon_id
	Progression.save_path = TEST_SAVE_PATH
	Progression.reset_progress(false)
	var weapon_ids := WeaponPlatformCatalog.get_weapon_ids()
	_expect(weapon_ids.size() == 24, "armory should contain 24 distinct weapon platforms")
	for weapon_class in WeaponPlatformCatalog.CLASS_ORDER:
		_expect(WeaponPlatformCatalog.get_class_weapon_ids(weapon_class).size() == 3, "%s should contain three distinct platforms" % weapon_class)
	_expect(WeaponPlatformCatalog.canonical_id("pistol") == "glock_17_gen5_mos", "legacy saves should migrate pistol aliases")
	var m4_base := AttackCatalog.get_gun_data("colt_m4a1")
	var m4_suppressed := AttackCatalog.get_gun_data("colt_m4a1", PackedStringArray(["surefire_socom556_rc2"]))
	_expect(m4_suppressed.hearing_radius < m4_base.hearing_radius and m4_suppressed.muzzle_flash_size < m4_base.muzzle_flash_size, "a compatible RC2 should reduce M4 report and flash")
	_expect(m4_suppressed.overall_length_mm > m4_base.overall_length_mm and m4_suppressed.weapon_length_multiplier > 1.0, "a suppressor should lengthen both the physical and visual weapon")
	var m4_scoped := AttackCatalog.get_gun_data("colt_m4a1", PackedStringArray(["nightforce_atacr_1_8"]))
	_expect(m4_scoped.spread_degrees < m4_base.spread_degrees and m4_scoped.camera_look_ahead_multiplier > 1.4, "magnified optics should trade handling for precision and view reach")
	var rejected := AttackCatalog.get_gun_data("colt_m4a1", PackedStringArray(["obsidian_45"]))
	_expect(rejected.installed_attachments.is_empty() and is_equal_approx(rejected.hearing_radius, m4_base.hearing_radius), "incompatible calibre hardware must not alter the weapon")
	_expect(WeaponPlatformCatalog.canonical_id("hk_mp5sd6") == "hk_mp5a5", "removed SMG definitions must merge into the retained class platform")
	_expect(Progression.select_loadout_weapon("primary", "colt_m4a1"), "starter carbine should equip as primary")
	_expect(not Progression.select_loadout_weapon("secondary", "colt_m4a1"), "a carbine must not fit the secondary slot")
	_expect(Progression.select_loadout_weapon("secondary", "glock_17_gen5_mos"), "starter handgun should equip as secondary")
	_expect(bool(Progression.set_weapon_attachment("colt_m4a1", "optic", "aimpoint_micro_t2").success), "compatible optic should persist to a build")
	var player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.set_physics_process(false)
	player.configure_field_kit(LoadoutCatalog.get_kit("custom"))
	_expect(player.owned_gun_indices.size() == 2 and player.gun.weapon_id == "colt_m4a1", "custom kit should issue the selected primary and secondary")
	_expect("aimpoint_micro_t2" in player.gun.gun_data.installed_attachments, "mission issue should apply the saved build")
	player.queue_free()
	await get_tree().process_frame
	Progression.editing_loadout_slot = "primary"
	Progression.editing_weapon_id = "colt_m4a1"
	var armory = ARMORY_SCENE.instantiate()
	add_child(armory)
	await get_tree().process_frame
	_expect(armory.get_node("Panel/Layout").size.y <= armory.get_node("Panel").size.y, "armory controls should fit inside the native viewport")
	_expect("VISUAL PLATFORM" in armory.get_node("Panel/Layout/Kicker").text, "armory should identify its image-first platform selector")
	_expect(armory.get_node("Panel/Layout/Preview").texture != null, "armory should render the selected firearm instead of relying on its name")
	armory.queue_free()
	await get_tree().process_frame
	var gunsmith = GUNSMITH_SCENE.instantiate()
	add_child(gunsmith)
	await get_tree().process_frame
	_expect(gunsmith.get_node("Panel/Layout").size.y <= gunsmith.get_node("Panel").size.y, "gunsmith controls should fit inside the native viewport")
	_expect("COLT M4A1" in gunsmith.get_node("Panel/Layout/Weapon").text, "gunsmith should open on the selected platform")
	_expect(gunsmith.get_node("Panel/Layout/VisualDeck/WeaponPreview").texture != null and gunsmith.get_node("Panel/Layout/VisualDeck/PartPreview").texture != null, "gunsmith should preview both the assembled weapon and selected hardpoint")
	gunsmith.queue_free()
	await get_tree().process_frame
	Progression.data = original_data
	Progression.save_path = original_save_path
	Progression.editing_loadout_slot = original_slot
	Progression.editing_weapon_id = original_weapon
	if FileAccess.file_exists(TEST_SAVE_PATH): DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
	if failures == 0: print("weapon platform system regression: PASS")
	get_tree().quit(failures)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
