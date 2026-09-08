extends Control

const PIXEL_ICONS := preload("res://utility/pixel_icon_factory.gd")

func _ready() -> void:
	UIDefaults.decorate_buttons(self)
	UIDefaults.animate_screen_intro($Panel)
	$Panel/VBox/NightclubButton.text = "START NEW RUN"
	$Panel/VBox/SandwichButton.text = "ARMORY"
	$Panel/VBox/AfterHoursButton.text = "GUNSMITH"
	$Panel/VBox/TacticalLabButton.visible = false
	$Panel/VBox/NightclubButton.pressed.connect(_start_roguelike_run)
	$Panel/VBox/SandwichButton.pressed.connect(_open_armory)
	$Panel/VBox/AfterHoursButton.pressed.connect(_open_gunsmith)
	$Panel/VBox/SettingsButton.pressed.connect(_open_settings)
	$Panel/VBox/HelpButton.pressed.connect(_open_help)
	$Panel/VBox/QuitButton.pressed.connect(get_tree().quit)
	PIXEL_ICONS.assign($Panel/VBox/NightclubButton, "play", Color("d10b32"))
	PIXEL_ICONS.assign($Panel/VBox/SandwichButton, "ammo", Color("f4f4f4"))
	PIXEL_ICONS.assign($Panel/VBox/AfterHoursButton, "weapon", Color("a8a8a8"))
	PIXEL_ICONS.assign($Panel/VBox/SettingsButton, "settings", Color("b8b8b8"))
	PIXEL_ICONS.assign($Panel/VBox/HelpButton, "case", Color("e4e4e4"))
	PIXEL_ICONS.assign($Panel/VBox/QuitButton, "quit", Color("b8b8b8"))
	$Panel/VBox/Subtitle.text = "v%s // RANDOMIZED ROOM RUN" % str(ProjectSettings.get_setting("application/config/version", "DEV"))
	_refresh_career_label()
	$Panel/VBox/NightclubButton.grab_focus()
	$Panel/VBox.move_child($Panel/VBox/QuitButton, $Panel/VBox.get_child_count() - 1)
	for child in $Panel/VBox.get_children():
		if child is Button:
			child.alignment = HORIZONTAL_ALIGNMENT_LEFT
			child.custom_minimum_size.y = 14
			child.add_theme_font_size_override("font_size", 7)
			var ink := StyleBoxFlat.new()
			ink.bg_color = Color("101010")
			ink.content_margin_left = 5
			ink.content_margin_right = 3
			ink.content_margin_top = 1
			ink.content_margin_bottom = 1
			child.add_theme_stylebox_override("normal", ink)
	$Panel/VBox/SettingsButton.text = "SETTINGS"
	$Panel/VBox/Subtitle.text = "RANDOMIZED ROOM RUN"

func _start_roguelike_run() -> void:
	if SceneTransition.busy: return
	var profile := Progression.begin_roguelike_run()
	if profile != null: SceneTransition.transition_to(profile.scene_path)

func _open_armory() -> void:
	SceneTransition.transition_to("res://scenes/ui/armory_screen.tscn")

func _open_gunsmith() -> void:
	SceneTransition.transition_to("res://scenes/ui/gunsmith_screen.tscn")

func _open_settings() -> void:
	SceneTransition.transition_to("res://scenes/ui/settings_screen_paged.tscn")

func _open_help() -> void:
	SceneTransition.transition_to("res://scenes/ui/run_help.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo: return
	if event.physical_keycode == KEY_H: _open_help()

func _refresh_career_label() -> void:
	var records: Dictionary = Progression.data.get("roguelike_records", {})
	$Panel/VBox/ProgressLabel.text = "6 FLOORS // ONE DESCENT\nBEST %d ROOMS // %d WINS" % [int(records.get("best_rooms", 0)), int(records.get("victories", 0))]
