extends Control

func _ready() -> void:
	$Panel/VBox.move_child($Panel/VBox/AfterHoursButton, $Panel/VBox/SandwichButton.get_index() + 1)
	_configure_button($Panel/VBox/NightclubButton, "nightclub")
	_configure_button($Panel/VBox/SandwichButton, "sandwich_shop")
	_configure_button($Panel/VBox/AfterHoursButton, "after_hours")
	_configure_button($Panel/VBox/TacticalLabButton, "tactical_lab")
	$Panel/VBox/QuitButton.pressed.connect(get_tree().quit)
	$Panel/VBox/ProgressLabel.text = "CASES CLOSED // %d/3" % Progression.get_campaign_completion_count()
	for button in [$Panel/VBox/NightclubButton, $Panel/VBox/SandwichButton, $Panel/VBox/AfterHoursButton, $Panel/VBox/TacticalLabButton]:
		if not button.disabled:
			button.grab_focus()
			if not Progression.is_mission_completed(str(button.get_meta("mission_id"))): break

func _configure_button(button: Button, mission_id: String) -> void:
	var profile := MissionCatalog.get_mission(mission_id)
	button.set_meta("mission_id", mission_id)
	var unlocked := Progression.is_mission_unlocked(profile)
	button.disabled = not unlocked
	if not unlocked:
		button.text = "LOCKED // " + profile.display_name
	else:
		var best := Progression.get_best_result(mission_id)
		button.text = profile.display_name if best.is_empty() else "%s // %s %04d" % [profile.display_name, best.grade, int(best.score)]
	button.pressed.connect(_open_mission.bind(mission_id))

func _open_mission(mission_id: String) -> void:
	if not Progression.begin_mission(mission_id): return
	get_tree().change_scene_to_file("res://scenes/ui/briefing_screen.tscn")
