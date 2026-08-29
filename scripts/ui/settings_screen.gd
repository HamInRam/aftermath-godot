extends Control

const PIXEL_ICONS := preload("res://utility/pixel_icon_factory.gd")

const SLIDER_PATHS := {
	"Panel/VBox/PageStack/AudioPage/Grid/MasterSlider": "master_volume",
	"Panel/VBox/PageStack/AudioPage/Grid/MusicSlider": "music_volume",
	"Panel/VBox/PageStack/AudioPage/Grid/SFXSlider": "sfx_volume",
	"Panel/VBox/PageStack/AudioPage/Grid/AmbienceSlider": "ambience_volume",
	"Panel/VBox/PageStack/AccessPage/Content/Grid/ShakeSlider": "screen_shake_strength",
	"Panel/VBox/PageStack/AccessPage/Content/Grid/FlashSlider": "flash_intensity",
}

const CATEGORY_NAMES := ["audio", "access", "aim"]
var current_category := 0

func _ready() -> void:
	UIDefaults.animate_screen_intro($Panel)
	UIDefaults.decorate_buttons(self)
	PIXEL_ICONS.assign($Panel/VBox/Actions/DefaultsButton, "settings", Color("fff0a8"))
	PIXEL_ICONS.assign($Panel/VBox/Actions/BackButton, "back", Color("bdaebe"))
	PIXEL_ICONS.assign($Panel/VBox/Actions/EffectsButton, "target", Color("82d8ff"))
	for slider_path in SLIDER_PATHS:
		var slider := get_node(slider_path) as HSlider
		slider.value_changed.connect(_on_slider_changed.bind(SLIDER_PATHS[slider_path]))
		slider.drag_ended.connect(_on_slider_drag_ended)
	$Panel/VBox/PageStack/AccessPage/Content/Toggles/ScreenEffects.toggled.connect(_on_toggle.bind("screen_effects_enabled"))
	$Panel/VBox/PageStack/AccessPage/Content/Toggles/CameraMotion.toggled.connect(_on_toggle.bind("ambient_camera_motion_enabled"))
	$Panel/VBox/PageStack/AccessPage/Content/Toggles/HighContrast.toggled.connect(_on_toggle.bind("high_contrast_enemies"))
	$Panel/VBox/PageStack/AimPage/AimOptions/AimAssist.add_item("OFF", 0)
	$Panel/VBox/PageStack/AimPage/AimOptions/AimAssist.add_item("LOW", 1)
	$Panel/VBox/PageStack/AimPage/AimOptions/AimAssist.add_item("MED", 2)
	$Panel/VBox/PageStack/AimPage/AimOptions/AimAssist.add_item("HIGH", 3)
	$Panel/VBox/PageStack/AimPage/AimOptions/AimAssist.item_selected.connect(_on_aim_assist_selected)
	$Panel/VBox/PageStack/AimPage/AimOptions/AimLaser.toggled.connect(_on_toggle.bind("aim_laser_enabled"))
	$Panel/VBox/PageStack/AimPage/AimOptions/ReticleHUD.toggled.connect(_on_toggle.bind("reticle_hud_enabled"))
	$Panel/VBox/PageStack/AimPage/AimOptions/Ragdoll.toggled.connect(_on_toggle.bind("ragdoll_enabled"))
	$Panel/VBox/CategoryTabs/AudioButton.pressed.connect(_show_category.bind(0))
	$Panel/VBox/CategoryTabs/AccessButton.pressed.connect(_show_category.bind(1))
	$Panel/VBox/CategoryTabs/AimButton.pressed.connect(_show_category.bind(2))
	$Panel/VBox/Actions/DefaultsButton.pressed.connect(_reset_defaults)
	$Panel/VBox/Actions/EffectsButton.pressed.connect(_open_effects)
	$Panel/VBox/Actions/BackButton.pressed.connect(_back)
	_sync_controls()
	_show_category(0)
	$Panel/VBox/CategoryTabs/AudioButton.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): _back()
	elif event.is_action_pressed("ui_page_down"):
		_show_category((current_category + 1) % CATEGORY_NAMES.size())
	elif event.is_action_pressed("ui_page_up"):
		_show_category(posmod(current_category - 1, CATEGORY_NAMES.size()))

func _show_category(index: int) -> void:
	current_category = clampi(index, 0, CATEGORY_NAMES.size() - 1)
	$Panel/VBox/PageStack/AudioPage.visible = current_category == 0
	$Panel/VBox/PageStack/AccessPage.visible = current_category == 1
	$Panel/VBox/PageStack/AimPage.visible = current_category == 2
	$Panel/VBox/CategoryTabs/AudioButton.set_pressed_no_signal(current_category == 0)
	$Panel/VBox/CategoryTabs/AccessButton.set_pressed_no_signal(current_category == 1)
	$Panel/VBox/CategoryTabs/AimButton.set_pressed_no_signal(current_category == 2)
	$Panel/VBox/Status.text = "%s SETTINGS // WHEEL TO SCROLL" % CATEGORY_NAMES[current_category].to_upper()

func _sync_controls() -> void:
	for slider_path in SLIDER_PATHS:
		var slider := get_node(slider_path) as HSlider
		slider.set_value_no_signal(float(Settings.get(SLIDER_PATHS[slider_path])) * 100.0)
	$Panel/VBox/PageStack/AccessPage/Content/Toggles/ScreenEffects.set_pressed_no_signal(Settings.screen_effects_enabled)
	$Panel/VBox/PageStack/AccessPage/Content/Toggles/CameraMotion.set_pressed_no_signal(Settings.ambient_camera_motion_enabled)
	$Panel/VBox/PageStack/AccessPage/Content/Toggles/HighContrast.set_pressed_no_signal(Settings.high_contrast_enemies)
	$Panel/VBox/PageStack/AimPage/AimOptions/AimAssist.select(clampi(roundi(Settings.aim_assist_strength * 3.0), 0, 3))
	$Panel/VBox/PageStack/AimPage/AimOptions/AimLaser.set_pressed_no_signal(Settings.aim_laser_enabled)
	$Panel/VBox/PageStack/AimPage/AimOptions/ReticleHUD.set_pressed_no_signal(Settings.reticle_hud_enabled)
	$Panel/VBox/PageStack/AimPage/AimOptions/Ragdoll.set_pressed_no_signal(Settings.ragdoll_enabled)
	$Panel/VBox/Status.text = "LIVE PREVIEW // SETTINGS SAVED ON RELEASE"

func _on_slider_changed(value: float, key: String) -> void:
	Settings.update_values({key: value / 100.0}, false)
	$Panel/VBox/Status.text = "%s // %d%%" % [key.to_upper().replace("_", " "), roundi(value)]

func _on_slider_drag_ended(_value_changed: bool) -> void:
	Settings.save_settings()

func _on_toggle(enabled: bool, key: String) -> void:
	Settings.update_values({key: enabled})
	$Panel/VBox/Status.text = "%s // %s" % [key.to_upper().replace("_", " "), "ON" if enabled else "OFF"]

func _on_aim_assist_selected(index: int) -> void:
	var strength := float(clampi(index, 0, 3)) / 3.0
	Settings.update_values({"aim_assist_strength": strength})
	$Panel/VBox/Status.text = "AIM ASSIST // %s" % ["OFF", "LOW", "MED", "HIGH"][clampi(index, 0, 3)]

func _reset_defaults() -> void:
	Settings.reset_to_defaults()
	_sync_controls()
	$Panel/VBox/Status.text = "DEFAULTS RESTORED"

func _back() -> void:
	Settings.save_settings()
	SceneTransition.transition_to("res://scenes/ui/title_menu.tscn")

func _open_effects() -> void:
	Settings.save_settings()
	SceneTransition.transition_to("res://scenes/ui/effects_settings_screen.tscn")
