extends Node

const TITLE_SCENE := preload("res://scenes/ui/title_menu.tscn")
const BRIEFING_SCENE := preload("res://scenes/ui/briefing_screen.tscn")
const INTEL_SCENE := preload("res://scenes/ui/intel_screen.tscn")
const CONTRACT_SCENE := preload("res://scenes/ui/contract_screen.tscn")
const LOADOUT_SCENE := preload("res://scenes/ui/loadout_screen.tscn")
const DEBRIEF_SCENE := preload("res://scenes/ui/debrief_screen.tscn")
const UPGRADE_SCENE := preload("res://scenes/ui/upgrade_screen.tscn")
const SAFEHOUSE_SCENE := preload("res://scenes/ui/safehouse_screen.tscn")

var failures := 0

func _ready() -> void:
	_expect(ProjectSettings.get_setting("display/window/stretch/mode") == "canvas_items", "UI should render at output resolution instead of being enlarged from the native viewport")
	_expect(ProjectSettings.get_setting("display/window/stretch/scale_mode") == "integer", "pixel art and UI should retain integer output scaling")
	var theme := load("res://utility/themes/default_theme.tres") as Theme
	_expect(theme.default_font != null and theme.default_font.resource_path.ends_with("Silkscreen-Regular.ttf"), "UI should use the bundled grid-designed Silkscreen pixel font")
	var original_data: Dictionary = Progression.data.duplicate(true)
	var original_current: String = Progression.current_mission_id
	var original_result: Dictionary = Progression.last_result.duplicate(true)
	var compact_hud := HudController.new()
	add_child(compact_hud)
	await get_tree().process_frame
	_expect(compact_hud.tutorial_label.text.length() < 40, "onboarding should use a short progressive hint instead of a permanent control paragraph")
	_expect(compact_hud.ammo_meter != null, "combat HUD should express ammunition visually as well as numerically")
	_expect(compact_hud.ammo_meter.size.x <= 26.0 and compact_hud.ammo_meter.size.y <= 1.0, "combat ammunition should use the same true-pixel micro-gauge language as cleanup")
	compact_hud.set_combat_focus(0.5, true)
	_expect(compact_hud.focus_meter.visible and compact_hud.focus_meter.size.y <= 1.0, "combat focus should use a contextual one-pixel gauge rather than another permanent text panel")
	compact_hud.set_interaction("[ E ] SECURE NEARBY EVIDENCE x4 // OPTIONAL")
	await get_tree().process_frame
	_expect(compact_hud.interaction_label.text.length() <= 24 and compact_hud.context_backplate.visible, "context prompts should appear as compact icon-backed actions")
	_expect(compact_hud.context_backplate.size.x <= 102.0 and compact_hud.context_backplate.size.y <= 12.0, "context actions should occupy only a restrained lower-center strip")
	_expect(compact_hud.keycap_label.text == "E", "context actions should separate the input keycap from the action phrase")
	compact_hud.set_combat_counts(6, 2, 1)
	_expect(compact_hud.enemy_count_label.text == "x6" and compact_hud.camera_count_label.text == "x2" and compact_hud.alarm_count_label.text == "x1", "combat objectives should use three glanceable icon counters")
	_expect(compact_hud.tactical_backplate.get_rect().intersection(compact_hud.status_backplate.get_rect()).get_area() == 0.0, "tactical counters and transient status must occupy disjoint safe zones")
	compact_hud.set_phase("cleanup")
	_expect("UV" in compact_hud.tutorial_label.text and compact_hud.tutorial_label.text.length() < 40, "cleanup onboarding should disclose tools with a compact contextual strip")
	compact_hud.set_cleanup_summary(0.84, 12, 75.0)
	compact_hud.set_cleanup_tool("mop", 0.55)
	compact_hud.set_cleanup_context("kitchen", 0.96, false, true, {"blood": 3, "corpse": 1, "shell": 2})
	_expect(is_equal_approx(compact_hud.cleanup_meter.value, 84.0) and compact_hud.cleanup_percent_label.text == "84%" and compact_hud.cleanup_police_label.text == "01:15", "cleanup HUD should prioritize total cleanliness and response time without a text wall")
	_expect(compact_hud.cleanup_tool_label.text == "MOP" and is_equal_approx(compact_hud.cleanup_tool_meter.value, 9.0 / 16.0), "cleanup tool state should use the same cacheable sixteen-step visual value as the gradual mop icon")
	_expect(compact_hud.cleanup_tool_meter.size.x <= 26.0 and compact_hud.cleanup_tool_meter.size.y <= 1.0, "cleanup tool condition should never inherit stock ProgressBar minimum sizing")
	_expect(compact_hud.cleanup_scan_label.visible and "B3" in compact_hud.cleanup_scan_label.text and compact_hud.detail_label.text.is_empty(), "forensic counts and current workflow should only appear in active scan mode while room verification stays transient")
	_expect(compact_hud.cleanup_meter.size.x <= 26.0 and compact_hud.cleanup_meter.size.y <= 1.0 and compact_hud.cleanup_meter.position.x <= 16.0, "cleanup progress should remain a genuinely tiny peripheral upper-left guide after integer viewport scaling")
	compact_hud.queue_free()
	await get_tree().process_frame
	Progression.reset_progress(false)
	var title = TITLE_SCENE.instantiate()
	add_child(title)
	await get_tree().process_frame
	var panel := title.get_node("Panel") as Control
	var menu := title.get_node("Panel/VBox") as Control
	_expect(menu.size.x <= panel.size.x and menu.size.y <= panel.size.y, "career status must not stretch or clip the centered level-select panel")
	_expect(title.get_node("Panel/VBox").size.y <= title.get_node("Panel").size.y, "campaign menu should fit inside the native 180px viewport panel")
	_expect(not title.get_node("Panel/VBox/NightclubButton").disabled, "first campaign case should be selectable")
	_expect(title.get_node("Panel/VBox/NightclubButton").icon != null, "unlocked cases should expose a readable pixel case icon")
	_expect(title.get_node("Panel/VBox/SettingsButton").icon != null, "settings navigation should expose a semantic pixel icon")
	_expect(title.get_node("Panel/VBox/SandwichButton").disabled, "second case should render locked before progression")
	_expect(title.get_node("Panel/VBox/AfterHoursButton").disabled, "final case should render locked before progression")
	_expect(title.get_node("Panel/VBox/TacticalLabButton").disabled, "fourth campaign case should render locked on the first page")
	_expect("12" in title.get_node("Panel/VBox/Subtitle").text, "case-file pagination should expose the complete campaign size")
	title.queue_free()
	await get_tree().process_frame
	Progression.data.credits = 500
	var workshop = UPGRADE_SCENE.instantiate()
	add_child(workshop)
	await get_tree().process_frame
	_expect(workshop.get_node("Panel/VBox/UpgradeList").get_child_count() == 5, "workshop should expose all five independent career upgrade routes")
	_expect(workshop.get_node("Panel/VBox").size.y <= workshop.get_node("Panel").size.y, "workshop should fit the native-resolution panel")
	_expect("BALANCE" in workshop.get_node("Panel/VBox/Header/Credits").text, "workshop should expose the current spendable balance")
	workshop.queue_free()
	await get_tree().process_frame
	Progression.data.specialization_points = 1
	var safehouse = SAFEHOUSE_SCENE.instantiate()
	add_child(safehouse)
	await get_tree().process_frame
	_expect(safehouse.get_node("Panel/VBox").size.y <= safehouse.get_node("Panel").size.y, "safehouse should fit the native-resolution panel")
	var safehouse_actions := safehouse.get_node("Panel/VBox/Actions") as Control
	_expect(safehouse_actions.global_position.y + safehouse_actions.size.y <= 178.0, "safehouse action buttons must remain fully visible above the native viewport edge")
	_expect("HEAT" in safehouse.get_node("Panel/VBox/Status").text, "safehouse should expose persistent heat")
	_expect(not safehouse.get_node("Panel/VBox/Specializations/Executioner").disabled, "available specialization points should enable career branches")
	safehouse.queue_free()
	await get_tree().process_frame
	Progression.current_mission_id = "after_hours"
	var briefing = BRIEFING_SCENE.instantiate()
	add_child(briefing)
	await get_tree().process_frame
	_expect(briefing.get_node("Panel/VBox").size.y <= briefing.get_node("Panel").size.y, "briefing content should fit its native-resolution panel")
	_expect("AFTER HOURS" in briefing.get_node("Panel/VBox/Title").text, "briefing should load the selected mission narrative")
	_expect("DISABLE 2" in briefing.get_node("Panel/VBox/Objectives").text, "briefing should list authored security requirements")
	_expect("CAMERAS PRESERVE" in briefing.get_node("Panel/VBox/Objectives").text, "briefing should teach the selected case's unique gameplay rule")
	_expect("STANDARD TERMS" in briefing.get_node("Panel/VBox/Contract").text, "briefing should expose the selected contract")
	_expect(briefing.get_node("Panel/VBox/Actions/ContractButton") != null, "briefing should route contract selection to its own screen")
	_expect(briefing.get_node("Panel/VBox/Actions/LoadoutButton") != null, "briefing should route weapon configuration to its own screen")
	_expect(briefing.get_node("Panel/VBox/Actions/IntelButton") != null, "briefing should progressively disclose detailed intelligence on its own screen")
	briefing.queue_free()
	await get_tree().process_frame
	var intel = INTEL_SCENE.instantiate()
	add_child(intel)
	await get_tree().process_frame
	_expect(intel.get_node("Panel/Layout").size.y <= intel.get_node("Panel").size.y, "intel footer and summary should fit while long text scrolls")
	_expect(intel.get_node("Panel/Layout/Scroll") is ScrollContainer, "detailed mission intelligence should use a scroll container")
	_expect("SECURITY" in intel.get_node("Panel/Layout/Scroll/Body").text, "intel page should preserve authored mission hazards and objectives")
	intel.queue_free()
	await get_tree().process_frame
	var contract_screen = CONTRACT_SCENE.instantiate()
	add_child(contract_screen)
	await get_tree().process_frame
	_expect(contract_screen.get_node("Panel/VBox").size.y <= contract_screen.get_node("Panel").size.y, "contract selection should fit its dedicated panel")
	_expect("STANDARD" in contract_screen.get_node("Panel/VBox/Title").text, "contract selection should open on the persisted contract")
	_expect("PAYOUT" in contract_screen.get_node("Panel/VBox/Payout").text, "contract selection should explain its payout consequence")
	contract_screen.queue_free()
	await get_tree().process_frame
	var loadout_screen = LOADOUT_SCENE.instantiate()
	add_child(loadout_screen)
	await get_tree().process_frame
	_expect(loadout_screen.get_node("Panel/VBox").size.y <= loadout_screen.get_node("Panel").size.y, "weapon configuration should fit its dedicated panel")
	_expect("PISTOL" in loadout_screen.get_node("Panel/VBox/Weapons").text, "weapon configuration should identify issued weapons")
	_expect("+" in loadout_screen.get_node("Panel/VBox/Weapons").text, "weapon configuration should show magazine and reserve ammunition")
	_expect("AFTERMATH" in loadout_screen.get_node("Panel/VBox/Stats").text, "loadout selection should forecast the later cleanup burden")
	loadout_screen.queue_free()
	await get_tree().process_frame
	var best := {"mission_id": "nightclub", "score": 1300, "grade": "A", "elapsed": 90.0, "cleanup_ratio": 1.0, "alarms": 1, "evidence_left": 0}
	best["forensic_report"] = {"classification": "CERTIFIED", "traces": ["SECURITY RESPONSE LOGGED"]}
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
	_expect(debrief.get_node("Panel/VBox").size.x <= debrief.get_node("Panel").size.x, "debrief report text must wrap instead of widening and offsetting the panel")
	for report_node in ["Narrative", "Stats", "Forensics", "Record"]:
		_expect(debrief.get_node("Panel/VBox/" + report_node).size.x <= debrief.get_node("Panel").size.x, "debrief %s must remain inside the horizontal safe area" % report_node)
	_expect("GRADE A" in debrief.get_node("Panel/VBox/Title").text, "debrief should display the recorded grade")
	_expect("NEW PERSONAL BEST" in debrief.get_node("Panel/VBox/Record").text, "debrief should identify a new record")
	_expect("FORENSICS CERTIFIED" in debrief.get_node("Panel/VBox/Forensics").text, "debrief should expose the scene's forensic consequence summary")
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
