extends Control

var profile: MissionProfile
var next_profile: MissionProfile

func _ready() -> void:
	$Panel/VBox/Actions/MenuButton.pressed.connect(_back_to_menu)
	$Panel/VBox/Actions/RetryButton.pressed.connect(_retry)
	$Panel/VBox/Actions/NextButton.pressed.connect(_continue_campaign)
	var result: Dictionary = Progression.last_result
	profile = MissionCatalog.get_mission(str(result.get("mission_id", Progression.current_mission_id)))
	if result.is_empty() or profile == null:
		$Panel/VBox/Title.text = "NO ACTION REPORT"
		$Panel/VBox/Narrative.text = "COMPLETE A MISSION TO GENERATE A REPORT."
		$Panel/VBox/Actions/RetryButton.disabled = true
		$Panel/VBox/Actions/NextButton.disabled = true
		$Panel/VBox/Actions/MenuButton.grab_focus()
		return
	$Panel/VBox/Title.text = "GRADE %s // %04d PTS" % [result.grade, int(result.score)]
	$Panel/VBox/Narrative.text = profile.debrief_text
	$Panel/VBox/Stats.text = "TIME %05.1fs // CLEAN %3d%% // ALARMS %d // RISK %d" % [float(result.elapsed), roundi(float(result.cleanup_ratio) * 100.0), int(result.alarms), int(result.evidence_left)]
	var record_text := "NEW PERSONAL BEST" if bool(result.get("new_best", false)) else "BEST // %04d PTS" % int(Progression.get_best_result(profile.mission_id).get("score", result.score))
	if bool(result.get("first_completion", false)): record_text += " // CASE CLOSED"
	$Panel/VBox/Record.text = record_text
	next_profile = Progression.get_next_unlocked_mission()
	if next_profile == null:
		$Panel/VBox/Actions/NextButton.text = "CAMPAIGN COMPLETE" if profile.is_campaign_mission else "NO NEXT CASE"
		$Panel/VBox/Actions/NextButton.disabled = true
	else:
		$Panel/VBox/Actions/NextButton.text = "NEXT CASE"
		$Panel/VBox/Actions/NextButton.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): _back_to_menu()

func _retry() -> void:
	if profile == null: return
	Progression.begin_mission(profile.mission_id)
	SceneTransition.transition_to(profile.scene_path)

func _continue_campaign() -> void:
	if next_profile == null or not Progression.begin_mission(next_profile.mission_id): return
	SceneTransition.transition_to("res://scenes/ui/briefing_screen.tscn")

func _back_to_menu() -> void:
	SceneTransition.transition_to("res://scenes/ui/title_menu.tscn")
