extends Node

const SETTINGS_SCENE := preload("res://scenes/ui/settings_screen.tscn")
const TEST_SAVE_PATH := "user://aftermath_settings_test.json"

var failures := 0

func _ready() -> void:
	var original := Settings.to_dictionary()
	var store := GameSettingsStore.new(TEST_SAVE_PATH)
	store.remove_test_save()
	store.update_values({
		"master_volume": 0.5,
		"music_volume": 0.4,
		"sfx_volume": 0.3,
		"ambience_volume": 0.2,
		"screen_shake_strength": 0.25,
		"flash_intensity": 0.3,
		"screen_effects_enabled": false,
		"ambient_camera_motion_enabled": false,
	})
	_expect(AudioServer.get_bus_index("Music") >= 0 and AudioServer.get_bus_index("SFX") >= 0 and AudioServer.get_bus_index("Ambience") >= 0, "settings should create dedicated audio buses")
	_expect(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")), linear_to_db(0.4)), "music slider should apply to the Music bus")
	var reloaded := GameSettingsStore.new(TEST_SAVE_PATH)
	_expect(reloaded.load_settings(), "settings should reload from versioned JSON")
	_expect(is_equal_approx(reloaded.screen_shake_strength, 0.25) and not reloaded.screen_effects_enabled, "accessibility settings should survive disk reload")
	Settings.update_values(store.to_dictionary(), false)
	var settings_ui = SETTINGS_SCENE.instantiate()
	add_child(settings_ui)
	await get_tree().process_frame
	_expect(settings_ui.get_node("Panel/VBox").size.y <= settings_ui.get_node("Panel").size.y, "settings UI should fit the native-resolution panel")
	_expect(is_equal_approx(settings_ui.get_node("Panel/VBox/Grid/ShakeSlider").value, 25.0), "settings screen should reflect persisted shake strength")
	_expect(not settings_ui.get_node("Panel/VBox/Toggles/ScreenEffects").button_pressed, "settings screen should reflect disabled CRT effects")
	var camera := TraumaCamera.new()
	add_child(camera)
	_expect(is_equal_approx(camera.shake_strength, 0.25) and not camera.ambient_drift_enabled, "camera should consume shake and ambient-motion accessibility settings")
	var flash := ColorRect.new()
	add_child(flash)
	var feedback := CombatFeedback.new()
	add_child(feedback)
	feedback.configure(flash, Settings.flash_intensity)
	feedback.show_flash(Color(1.0, 0.0, 0.0, 0.5), 0.2)
	_expect(is_equal_approx(flash.color.a, 0.15), "flash intensity should scale the actual full-screen flash alpha")
	settings_ui.queue_free()
	camera.queue_free()
	feedback.queue_free()
	flash.queue_free()
	store.remove_test_save()
	store.free()
	reloaded.free()
	Settings.update_values(original, false)
	if failures == 0: print("game settings regression: PASS")
	get_tree().quit(failures)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
