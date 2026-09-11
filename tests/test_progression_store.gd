extends Node
const TEST_SAVE_PATH := "user://aftermath_progress_test.json"
func _ready() -> void:
	var store := ProgressionStore.new(TEST_SAVE_PATH)
	store.reset_progress(true)
	store.data.credits = 123
	store.data.roguelike_records.best_score = 500
	store.data.upgrades.mop = 3
	assert(store.save_progress())
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_SAVE_PATH))
	assert(parsed.schema_version == 8 and not parsed.has("upgrades") and not parsed.has("career_stats"))
	var loaded := ProgressionStore.new(TEST_SAVE_PATH)
	assert(loaded.load_progress())
	assert(loaded.get_credits() == 123 and loaded.data.roguelike_records.best_score == 500)
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema_version": 4, "credits": 9999}))
	file.close()
	assert(not loaded.load_progress() and loaded.get_credits() == 0)
	file = FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema_version": 8, "credits": "bad", "weapon_builds": []}))
	file.close()
	assert(loaded.load_progress() and loaded.get_credits() == 0 and loaded.data.weapon_builds is Dictionary)
	store.reset_progress(true)
	store.free()
	loaded.free()
	print("compact v8 save regression: PASS")
	get_tree().quit()
