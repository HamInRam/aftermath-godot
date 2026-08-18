extends Control

var profile: MissionProfile

func _ready() -> void:
	profile = MissionCatalog.get_mission(Progression.current_mission_id)
	$Panel/VBox/Actions/BackButton.pressed.connect(_back_to_menu)
	$Panel/VBox/Actions/DeployButton.pressed.connect(_deploy)
	if profile == null:
		$Panel/VBox/Title.text = "NO MISSION SELECTED"
		$Panel/VBox/Briefing.text = "RETURN TO THE CASE FILES."
		$Panel/VBox/Actions/DeployButton.disabled = true
		return
	$Panel/VBox/Kicker.text = "CASE %02d // INCOMING CALL" % profile.campaign_order if profile.is_campaign_mission else "CONTROLLED EXERCISE"
	$Panel/VBox/Title.text = profile.display_name
	$Panel/VBox/Briefing.text = profile.briefing
	var objectives := "PRIMARY // ELIMINATE ALL HOSTILES"
	if profile.required_security_shutdowns > 0:
		objectives += "\nSECONDARY // DISABLE %d SECURITY NODES" % profile.required_security_shutdowns
	$Panel/VBox/Objectives.text = objectives
	var best := Progression.get_best_result(profile.mission_id)
	$Panel/VBox/Record.text = "NO PRIOR RECORD" if best.is_empty() else "BEST // %s // %04d PTS" % [best.grade, int(best.score)]
	$Panel/VBox/Actions/DeployButton.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): _back_to_menu()

func _deploy() -> void:
	if profile != null: SceneTransition.transition_to(profile.scene_path)

func _back_to_menu() -> void:
	SceneTransition.transition_to("res://scenes/ui/title_menu.tscn")
