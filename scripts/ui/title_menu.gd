extends Control

const PIXEL_ICONS := preload("res://utility/pixel_icon_factory.gd")

const CASES_PER_PAGE := 4
var page := 0
var campaign: Array[MissionProfile] = []
var case_buttons: Array[Button] = []

func _ready() -> void:
	UIDefaults.decorate_buttons(self)
	UIDefaults.animate_screen_intro($Panel)
	$Panel/VBox.move_child($Panel/VBox/SettingsButton, $Panel/VBox/QuitButton.get_index())
	case_buttons = [$Panel/VBox/NightclubButton, $Panel/VBox/SandwichButton, $Panel/VBox/AfterHoursButton, $Panel/VBox/TacticalLabButton]
	for button in case_buttons: button.pressed.connect(_open_button_mission.bind(button))
	$Panel/VBox/SettingsButton.pressed.connect(_open_settings)
	$Panel/VBox/QuitButton.pressed.connect(get_tree().quit)
	PIXEL_ICONS.assign($Panel/VBox/SettingsButton, "settings", Color("82d8ff"))
	PIXEL_ICONS.assign($Panel/VBox/QuitButton, "quit", Color("ff658c"))
	campaign = MissionCatalog.get_campaign_missions()
	var selected_index := 0
	for index in range(campaign.size()):
		if campaign[index].mission_id == Progression.current_mission_id: selected_index = index
	page = selected_index / CASES_PER_PAGE
	_refresh_page()

func _refresh_page() -> void:
	var page_count := maxi(1, ceili(float(campaign.size()) / CASES_PER_PAGE))
	page = posmod(page, page_count)
	for slot in range(case_buttons.size()):
		var button := case_buttons[slot]
		var index := page * CASES_PER_PAGE + slot
		button.visible = index < campaign.size()
		if button.visible: _configure_button(button, campaign[index])
	$Panel/VBox/Subtitle.text = "v%s // CASES %02d-%02d / %02d" % [str(ProjectSettings.get_setting("application/config/version", "DEV")), page * CASES_PER_PAGE + 1, mini(campaign.size(), (page + 1) * CASES_PER_PAGE), campaign.size()]
	_refresh_career_label()
	for button in case_buttons:
		if button.visible and not button.disabled:
			button.grab_focus()
			break

func _configure_button(button: Button, profile: MissionProfile) -> void:
	button.set_meta("mission_id", profile.mission_id)
	var unlocked := Progression.is_mission_unlocked(profile)
	button.disabled = not unlocked
	if not unlocked: button.text = "LOCKED // " + profile.display_name
	else:
		var best := Progression.get_best_result(profile.mission_id)
		button.text = profile.display_name if best.is_empty() else "%s // %s %04d" % [profile.display_name, best.grade, int(best.score)]
	PIXEL_ICONS.assign(button, "case" if unlocked else "lock", Color("73f7e4") if unlocked else Color("665a68"))

func _open_button_mission(button: Button) -> void:
	_open_mission(str(button.get_meta("mission_id", "")))

func _open_mission(mission_id: String) -> void:
	if not Progression.begin_mission(mission_id): return
	SceneTransition.transition_to("res://scenes/ui/briefing_screen.tscn")

func _open_settings() -> void:
	SceneTransition.transition_to("res://scenes/ui/settings_screen_paged.tscn")

func _open_upgrades() -> void:
	SceneTransition.transition_to("res://scenes/ui/upgrade_screen.tscn")

func _open_safehouse() -> void:
	SceneTransition.transition_to("res://scenes/ui/safehouse_screen.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo: return
	if event.physical_keycode == KEY_U: _open_upgrades()
	elif event.physical_keycode == KEY_H: _open_safehouse()
	elif event.physical_keycode == KEY_T:
		Progression.toggle_cleaner_mode()
		_refresh_career_label()
	elif event.physical_keycode == KEY_L: _open_mission("tactical_lab")
	elif event.physical_keycode == KEY_M:
		Progression.cycle_run_mode()
		_refresh_career_label()
	elif event.physical_keycode in [KEY_A, KEY_LEFT]:
		page -= 1
		_refresh_page()
	elif event.physical_keycode in [KEY_D, KEY_RIGHT]:
		page += 1
		_refresh_page()

func _refresh_career_label() -> void:
	var mode_text := Progression.get_run_mode().to_upper().replace("_", " ")
	$Panel/VBox/ProgressLabel.text = "%d/%d   $%d   HEAT %d%%   %s\nA/D PAGE   H HOME   U SHOP   M MODE" % [Progression.get_campaign_completion_count(), campaign.size(), Progression.get_credits(), Progression.get_heat(), mode_text]
