extends Control

const SLIDER_KEYS := {
	"MasterSlider": "master_volume",
	"MusicSlider": "music_volume",
	"SFXSlider": "sfx_volume",
	"AmbienceSlider": "ambience_volume",
	"ShakeSlider": "screen_shake_strength",
	"FlashSlider": "flash_intensity",
}

func _ready() -> void:
	for slider_name in SLIDER_KEYS:
		var slider := get_node("Panel/VBox/Grid/" + slider_name) as HSlider
		slider.value_changed.connect(_on_slider_changed.bind(SLIDER_KEYS[slider_name]))
		slider.drag_ended.connect(_on_slider_drag_ended)
	$Panel/VBox/Toggles/ScreenEffects.toggled.connect(_on_toggle.bind("screen_effects_enabled"))
	$Panel/VBox/Toggles/CameraMotion.toggled.connect(_on_toggle.bind("ambient_camera_motion_enabled"))
	$Panel/VBox/Actions/DefaultsButton.pressed.connect(_reset_defaults)
	$Panel/VBox/Actions/BackButton.pressed.connect(_back)
	_sync_controls()
	$Panel/VBox/Actions/BackButton.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): _back()

func _sync_controls() -> void:
	for slider_name in SLIDER_KEYS:
		var slider := get_node("Panel/VBox/Grid/" + slider_name) as HSlider
		slider.set_value_no_signal(float(Settings.get(SLIDER_KEYS[slider_name])) * 100.0)
	$Panel/VBox/Toggles/ScreenEffects.set_pressed_no_signal(Settings.screen_effects_enabled)
	$Panel/VBox/Toggles/CameraMotion.set_pressed_no_signal(Settings.ambient_camera_motion_enabled)
	$Panel/VBox/Status.text = "LIVE PREVIEW // SETTINGS SAVED ON RELEASE"

func _on_slider_changed(value: float, key: String) -> void:
	Settings.update_values({key: value / 100.0}, false)
	$Panel/VBox/Status.text = "%s // %d%%" % [key.to_upper().replace("_", " "), roundi(value)]

func _on_slider_drag_ended(_value_changed: bool) -> void:
	Settings.save_settings()

func _on_toggle(enabled: bool, key: String) -> void:
	Settings.update_values({key: enabled})
	$Panel/VBox/Status.text = "%s // %s" % [key.to_upper().replace("_", " "), "ON" if enabled else "OFF"]

func _reset_defaults() -> void:
	Settings.reset_to_defaults()
	_sync_controls()
	$Panel/VBox/Status.text = "DEFAULTS RESTORED"

func _back() -> void:
	Settings.save_settings()
	SceneTransition.transition_to("res://scenes/ui/title_menu.tscn")
