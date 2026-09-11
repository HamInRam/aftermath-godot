extends Node

func _ready() -> void:
	var path := "user://atomic_progress_regression.json"
	AtomicJsonStore.remove_files(path)
	var store := ProgressionStore.new(path)
	store.data.credits = 10
	assert(store.save_progress())
	store.data.credits = 20
	assert(store.save_progress())
	assert(JSON.parse_string(FileAccess.get_file_as_string(path)).credits == 20)
	assert(JSON.parse_string(FileAccess.get_file_as_string(path + ".bak")).credits == 10)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{truncated")
	file.close()
	assert(store.load_progress() and store.get_credits() == 10, "truncated primary must recover backup")
	store.data.credits = 30
	assert(store.save_progress())
	assert(JSON.parse_string(FileAccess.get_file_as_string(path + ".bak")).credits == 10, "corrupt primary must not destroy backup")
	# A failed temporary write must leave the valid primary and backup untouched.
	DirAccess.make_dir_absolute(path + ".tmp")
	assert(not store.save_progress())
	assert(JSON.parse_string(FileAccess.get_file_as_string(path)).credits == 30)
	DirAccess.remove_absolute(path + ".tmp")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema_version": 8, "mission_attempts": {"nightclub": {}}, "roguelike_records": {"best_score": []}, "weapon_builds": {"colt_m4a1": 123, "glock_17_gen5_mos": [42, {}]}}))
	file.close()
	assert(store.load_progress())
	assert(store.data.mission_attempts.is_empty() and store.data.roguelike_records.best_score == 0)
	assert(store.get_weapon_build("colt_m4a1").is_empty())
	store.reset_progress(true)
	assert(not FileAccess.file_exists(path + ".bak"))
	store.free()
	var settings := GameSettingsStore.new("user://atomic_settings_regression.json")
	settings.remove_test_save()
	settings.master_volume = 0.3
	assert(settings.save_settings())
	settings.master_volume = 0.5
	assert(settings.save_settings())
	file = FileAccess.open(settings.save_path, FileAccess.WRITE)
	file.store_string("bad json")
	file.close()
	assert(settings.load_settings() and is_equal_approx(settings.master_volume, 0.3))
	settings.update_values({"master_volume": {}, "gore_enabled": [], "screen_shake_strength": 0.2}, false)
	assert(is_equal_approx(settings.master_volume, 0.3) and settings.gore_enabled)
	assert(is_equal_approx(settings.screen_shake_strength, 0.2))
	settings.remove_test_save()
	settings.free()
	print("ATOMIC_SAVES_OK")
	get_tree().quit()
