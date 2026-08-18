extends Node

const TITLE_SCENE := preload("res://scenes/ui/title_menu.tscn")
const BRIEFING_SCENE := preload("res://scenes/ui/briefing_screen.tscn")
const DEBRIEF_SCENE := preload("res://scenes/ui/debrief_screen.tscn")

var failures := 0

func _ready() -> void:
	_expect(ProjectSettings.get_setting("display/window/stretch/mode") == "canvas_items", "UI should render at output resolution instead of being enlarged from the native viewport")
	_expect(ProjectSettings.get_setting("display/window/stretch/scale_mode") == "integer", "pixel art and UI should retain integer output scaling")
	var theme := load("res://utility/themes/default_theme.tres") as Theme
	var system_font := theme.default_font as SystemFont
	_expect(system_font != null and system_font.font_names[0] == "Segoe UI", "Windows UI should prefer the highly legible Segoe UI face")
	_expect(system_font.antialiasing == TextServer.FONT_ANTIALIASING_GRAY and system_font.subpixel_positioning == TextServer.SUBPIXEL_POSITIONING_AUTO, "UI font rasterization should retain grayscale smoothing and automatic output-scale sampling")
	var original_data: Dictionary = Progression.data.duplicate(true)
	var original_current: String = Progression.current_mission_id
	var original_result: Dictionary = Progression.last_result.duplicate(true)
	Progression.reset_progress(false)
	var title = TITLE_SCENE.instantiate()
	add_child(title)
	await get_tree().process_frame
	_expect(title.get_node("Panel/VBox").size.y <= title.get_node("Panel").size.y, "campaign menu should fit inside the native 180px viewport panel")
	_expect(not title.get_node("Panel/VBox/NightclubButton").disabled, "first campaign case should be selectable")
	_expect(title.get_node("Panel/VBox/SandwichButton").disabled, "second case should render locked before progression")
	_expect(title.get_node("Panel/VBox/AfterHoursButton").disabled, "final case should render locked before progression")
	_expect(not title.get_node("Panel/VBox/TacticalLabButton").disabled, "training should remain available outside campaign progression")
	title.queue_free()
	await get_tree().process_frame
	Progression.current_mission_id = "after_hours"
	var briefing = BRIEFING_SCENE.instantiate()
	add_child(briefing)
	await get_tree().process_frame
	_expect(briefing.get_node("Panel/VBox").size.y <= briefing.get_node("Panel").size.y, "briefing content should fit its native-resolution panel")
	_expect("AFTER HOURS" in briefing.get_node("Panel/VBox/Title").text, "briefing should load the selected mission narrative")
	_expect("DISABLE 2" in briefing.get_node("Panel/VBox/Objectives").text, "briefing should list authored security requirements")
	briefing.queue_free()
	await get_tree().process_frame
	var best := {"mission_id": "nightclub", "score": 1300, "grade": "A", "elapsed": 90.0, "cleanup_ratio": 1.0, "alarms": 1, "evidence_left": 0}
	Progression.data.completed_missions = ["nightclub"]
	Progression.data.best_results = {"nightclub": best.duplicate(true)}
	Progression.current_mission_id = "nightclub"
	Progression.last_result = best.duplicate(true)
	Progression.last_result["first_completion"] = true
	Progression.last_result["new_best"] = true
	var debrief = DEBRIEF_SCENE.instantiate()
	add_child(debrief)
	await get_tree().process_frame
	_expect(debrief.get_node("Panel/VBox").size.y <= debrief.get_node("Panel").size.y, "debrief content should fit its native-resolution panel")
	_expect("GRADE A" in debrief.get_node("Panel/VBox/Title").text, "debrief should display the recorded grade")
	_expect("NEW PERSONAL BEST" in debrief.get_node("Panel/VBox/Record").text, "debrief should identify a new record")
	_expect(not debrief.get_node("Panel/VBox/Actions/NextButton").disabled, "closing a case should enable the newly unlocked next mission")
	debrief.queue_free()
	await get_tree().process_frame
	Progression.data = original_data
	Progression.current_mission_id = original_current
	Progression.last_result = original_result
	if failures == 0: print("campaign UI regression: PASS")
	get_tree().quit(failures)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
