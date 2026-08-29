extends Node

const SETTINGS_SCENE := preload("res://scenes/ui/settings_screen_paged.tscn")
const EFFECTS_SCENE := preload("res://scenes/ui/effects_settings_screen.tscn")
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
		"high_contrast_enemies": true,
		"hit_stop_strength": 0.5,
		"camera_tilt_strength": 0.0,
		"chromatic_aberration_strength": 0.25,
		"blood_density": 0.6,
		"gore_enabled": false,
		"aim_assist_strength": 0.33,
		"aim_laser_enabled": false,
		"reticle_hud_enabled": false,
		"ragdoll_enabled": true,
	})
	_expect(AudioServer.get_bus_index("Music") >= 0 and AudioServer.get_bus_index("SFX") >= 0 and AudioServer.get_bus_index("Ambience") >= 0, "settings should create dedicated audio buses")
	_expect(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")), linear_to_db(0.4)), "music slider should apply to the Music bus")
	var reloaded := GameSettingsStore.new(TEST_SAVE_PATH)
	_expect(reloaded.load_settings(), "settings should reload from versioned JSON")
	_expect(is_equal_approx(reloaded.screen_shake_strength, 0.25) and not reloaded.screen_effects_enabled, "accessibility settings should survive disk reload")
	_expect(is_equal_approx(reloaded.blood_density, 0.6) and not reloaded.gore_enabled, "violence comfort settings should survive disk reload")
	_expect(is_equal_approx(reloaded.aim_assist_strength, 0.33) and not reloaded.aim_laser_enabled and not reloaded.reticle_hud_enabled and reloaded.ragdoll_enabled, "aiming and ragdoll settings should survive disk reload")
	Settings.update_values(store.to_dictionary(), false)
	var settings_ui = SETTINGS_SCENE.instantiate()
	add_child(settings_ui)
	await get_tree().process_frame
	var settings_panel := settings_ui.get_node("Panel") as Control
	var page_stack := settings_ui.get_node("Panel/VBox/PageStack") as Control
	var actions := settings_ui.get_node("Panel/VBox/Actions") as Control
	_expect(settings_ui.get_node("Panel/VBox").size.y <= settings_panel.size.y, "settings shell should fit the native-resolution panel")
	_expect(actions.position.y + actions.size.y <= settings_panel.size.y + 0.01, "fixed settings footer should remain inside the safe area")
	_expect(page_stack.position.y + page_stack.size.y <= actions.position.y + 0.01, "paged content should never overlap the fixed footer")
	_expect(settings_ui.get_node("Panel/VBox/PageStack/AudioPage") is ScrollContainer and settings_ui.get_node("Panel/VBox/PageStack/AccessPage") is ScrollContainer and settings_ui.get_node("Panel/VBox/PageStack/AimPage") is ScrollContainer, "every settings category should own an independent scroll viewport")
	_expect(is_equal_approx(settings_ui.get_node("Panel/VBox/PageStack/AccessPage/Content/Grid/ShakeSlider").value, 25.0), "settings screen should reflect persisted shake strength")
	_expect(not settings_ui.get_node("Panel/VBox/PageStack/AccessPage/Content/Toggles/ScreenEffects").button_pressed, "settings screen should reflect disabled CRT effects")
	_expect(settings_ui.get_node("Panel/VBox/PageStack/AccessPage/Content/Toggles/HighContrast").button_pressed, "settings screen should expose the high-contrast enemy outline option")
	_expect(settings_ui.get_node("Panel/VBox/PageStack/AimPage/AimOptions/AimAssist").selected == 1, "settings screen should expose controller aim-assist strength")
	_expect(not settings_ui.get_node("Panel/VBox/PageStack/AimPage/AimOptions/AimLaser").button_pressed and settings_ui.get_node("Panel/VBox/PageStack/AimPage/AimOptions/Ragdoll").button_pressed, "settings screen should expose aim laser and ragdoll toggles")
	settings_ui._show_category(2)
	_expect(settings_ui.get_node("Panel/VBox/PageStack/AimPage").visible and not settings_ui.get_node("Panel/VBox/PageStack/AudioPage").visible, "category switching should expose exactly one settings page")
	var aim_options := settings_ui.get_node("Panel/VBox/PageStack/AimPage/AimOptions") as GridContainer
	for index in range(24):
		var future_option := CheckButton.new()
		future_option.text = "FUTURE %02d" % index
		aim_options.add_child(future_option)
	await get_tree().process_frame
	_expect(aim_options.size.y > page_stack.size.y and actions.position.y + actions.size.y <= settings_panel.size.y + 0.01, "future settings should overflow only inside their scroll page, never below the footer")
	var effects_ui = EFFECTS_SCENE.instantiate()
	add_child(effects_ui)
	await get_tree().process_frame
	_expect(effects_ui.get_node("Panel/VBox").size.y <= effects_ui.get_node("Panel").size.y, "effect controls should fit their dedicated page")
	_expect(is_equal_approx(effects_ui.get_node("Panel/VBox/Grid/Blood").value, 60.0), "effects page should reflect blood-density comfort settings")
	_expect(not effects_ui.get_node("Panel/VBox/Gore").button_pressed, "effects page should expose an independent dismemberment toggle")
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
	feedback.trigger_hit_stop(0.03)
	var first_deadline := feedback.hit_stop_deadline_msec
	feedback.trigger_hit_stop(0.08)
	_expect(feedback.hit_stop_deadline_msec > first_deadline and feedback.hit_stop_active, "overlapping hit-stop should preserve the longest remaining deadline")
	feedback.reset()
	settings_ui.queue_free()
	effects_ui.queue_free()
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
