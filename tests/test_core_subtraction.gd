extends Node2D

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	assert(WeaponPlatformCatalog.get_weapon_ids().size() == 24)
	for kind in WeaponPlatformCatalog.CLASS_ORDER:
		assert(WeaponPlatformCatalog.get_class_weapon_ids(kind).size() == 3)
	var store := ProgressionStore.new("user://core_subtraction_test.json")
	store.data.credits = 123
	store.data.upgrades.mop = 3
	assert(store.save_progress())
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(store.save_path))
	assert(saved.schema_version == 8 and saved.credits == 123)
	assert(not saved.has("upgrades") and not saved.has("career_stats") and not saved.has("cleaner_mode"))
	assert(store.load_progress() and store.get_credits() == 123)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(store.save_path))
	store.free()
	var enemy = preload("res://scenes/enemy.tscn").instantiate()
	add_child(enemy)
	enemy.set_room_combat_active(false)
	var before: Vector2 = enemy.position
	enemy.path_refresh = 0.75
	for index in 120: enemy._physics_process(1.0 / 60.0)
	assert(enemy.position == before and enemy.path_refresh == 0.75)
	assert(not enemy.gun.is_processing())
	enemy.set_room_combat_active(true)
	assert(enemy.state == enemy.State.CHASE and enemy.gun.is_processing())
	enemy.queue_free()
	var prop := DestructibleProp.new()
	assert(not prop.has_method("begin_drag") and not prop.has_method("enter_cleanup_restore_state"))
	prop.free()
	assert(MicroDebrisField.LIMIT == 256)
	await get_tree().process_frame
	print("core subtraction regression: PASS")
	get_tree().quit()
