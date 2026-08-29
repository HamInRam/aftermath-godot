extends Control

const SLIDERS := {
	"HitStop": "hit_stop_strength",
	"Tilt": "camera_tilt_strength",
	"Chromatic": "chromatic_aberration_strength",
	"Blood": "blood_density",
}

func _ready() -> void:
	UIDefaults.animate_screen_intro($Panel)
	UIDefaults.decorate_buttons(self)
	for node_name in SLIDERS:
		var slider := get_node("Panel/VBox/Grid/" + node_name) as HSlider
		slider.set_value_no_signal(float(Settings.get(SLIDERS[node_name])) * 100.0)
		slider.value_changed.connect(_change.bind(SLIDERS[node_name]))
		slider.drag_ended.connect(_save)
	$Panel/VBox/Gore.set_pressed_no_signal(Settings.gore_enabled)
	$Panel/VBox/Gore.toggled.connect(_toggle_gore)
	$Panel/VBox/Back.pressed.connect(_back)
	$Panel/VBox/Back.grab_focus()

func _change(value: float, key: String) -> void:
	Settings.update_values({key: value / 100.0}, false)
	$Panel/VBox/Status.text = "%s // %d%%" % [key.to_upper().replace("_", " "), roundi(value)]

func _save(_changed: bool) -> void:
	Settings.save_settings()

func _toggle_gore(enabled: bool) -> void:
	Settings.update_values({"gore_enabled": enabled})
	$Panel/VBox/Status.text = "DISMEMBERMENT // %s" % ("ON" if enabled else "OFF")

func _back() -> void:
	Settings.save_settings()
	SceneTransition.transition_to("res://scenes/ui/settings_screen_paged.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): _back()
