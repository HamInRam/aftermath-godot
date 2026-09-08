extends Control

const PIXEL_ICONS := preload("res://utility/pixel_icon_factory.gd")

var profile: MissionProfile
var next_profile: MissionProfile
var roguelike_result := false
var transition_requested := false

func _ready() -> void:
	UIDefaults.decorate_buttons(self)
	UIDefaults.animate_screen_intro($Panel)
	PIXEL_ICONS.assign($Panel/VBox/Actions/MenuButton, "case", Color("82d8ff"))
	PIXEL_ICONS.assign($Panel/VBox/Actions/RetryButton, "back", Color("fff0a8"))
	PIXEL_ICONS.assign($Panel/VBox/Actions/NextButton, "play", Color("73f7e4"))
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
	var forensic: Dictionary = result.get("forensic_report", {})
	roguelike_result = str(forensic.get("mode", "")) == "roguelike"
	if roguelike_result:
		_configure_run_report(result, forensic)
		return
	if roguelike_result: $Panel/VBox/Narrative.text = "THE FLOOR IS QUIET. THE BLOOD REMEMBERS THE ROUTE YOU TOOK."
	if profile.mission_id == "last_call":
		match str(result.get("ending_id", "professional")):
			"clean_break": $Panel/VBox/Narrative.text = "CLEAN BREAK // NO TRACE CONNECTS THE TWELVE SCENES. YOU LEAVE THE PHONE BEHIND."
			"exposed": $Panel/VBox/Narrative.text = "EXPOSED // THE CITY CONNECTS THE BLOOD, ALARMS AND MISSING PROPERTY. THE HUNT BEGINS."
			"ghost": $Panel/VBox/Narrative.text = "GHOST // TWELVE SCENES, NO ALARM CHAIN, NO STOLEN PROPERTY. THE CITY NEVER LEARNS YOUR NAME."
			"kingpin": $Panel/VBox/Narrative.text = "KINGPIN // THE NETWORK DIES VIOLENTLY. ITS MONEY, FEAR AND VACANT TERRITORY NOW BELONG TO YOU."
			_: $Panel/VBox/Narrative.text = "PROFESSIONAL // THE NETWORK IS GONE, BUT THE WORK HAS MADE YOU PART OF ITS REPLACEMENT."
	$Panel/VBox/Stats.text = ("TIME %05.1fs  ROOMS %d  KILLS %d  ALARMS %d" % [float(result.elapsed), int(forensic.get("rooms_cleared", 0)), int(forensic.get("kills", 0)), int(result.alarms)]) if roguelike_result else ("TIME %05.1fs  CLEAN %3d%%  ALARMS %d  RISK %d" % [float(result.elapsed), roundi(float(result.cleanup_ratio) * 100.0), int(result.alarms), int(result.evidence_left)])
	if not forensic.is_empty():
		$Panel/VBox/Stats.text += "\nROUTE %d+%d" % [int(forensic.get("combat_route", 0)), int(forensic.get("cleanup_route", 0))]
		var total_phase := float(forensic.get("combat_seconds", 0.0)) + float(forensic.get("cleanup_seconds", 0.0))
		if total_phase > 0.0: $Panel/VBox/Stats.text += "  FLOW %d/%d" % [roundi(float(forensic.get("combat_seconds", 0.0)) / total_phase * 100.0), roundi(float(forensic.get("cleanup_seconds", 0.0)) / total_phase * 100.0)]
		if str(forensic.get("dominant_weapon", "none")) != "none": $Panel/VBox/Stats.text += "  DRIVER %s" % str(forensic.dominant_weapon).to_upper()
	if roguelike_result:
		$Panel/VBox/Forensics.text = "RUN REPORT // %d ROOMS CONSUMED\nROUTE %dPX  SHOTS %d  DRIVER %s" % [int(forensic.get("rooms_cleared", 0)), int(forensic.get("combat_route", 0)), int(forensic.get("shots", 0)), str(forensic.get("dominant_weapon", "NONE")).to_upper()]
	elif forensic.is_empty():
		$Panel/VBox/Forensics.text = "FORENSICS // NO TRACE ANALYSIS"
	else:
		var traces: Array = forensic.get("traces", [])
		var contract_status := "%s %s" % [str(forensic.get("contract_name", "STANDARD TERMS")), "COMPLETE" if bool(forensic.get("contract_success", true)) else "FAILED"]
		$Panel/VBox/Forensics.text = "FORENSICS %s // %s\nCONTRACT // %s\nRESTORE -%d  DRIVER %s  ROOMS %d\nREVIEW // %s" % [str(forensic.get("classification", "UNKNOWN")), str(traces[0] if not traces.is_empty() else "NO ACTIONABLE TRACE CHAIN"), contract_status, int(forensic.get("restoration_cost", 0)), str(forensic.get("dominant_cost", "NONE")), int(forensic.get("rooms_verified", 0)), ContractCatalog.get_action_review(forensic)]
	var record_text := "NEW PERSONAL BEST" if bool(result.get("new_best", false)) else "BEST // %04d PTS" % int(Progression.get_best_result(profile.mission_id).get("score", result.score))
	if bool(result.get("first_completion", false)): record_text += " // CASE CLOSED"
	var mastery: Dictionary = result.get("mastery", {})
	var mastery_count := 0
	for achieved in mastery.values():
		if bool(achieved): mastery_count += 1
	record_text += " // MASTERY %d/5" % mastery_count
	$Panel/VBox/Record.text = "%s\nPAY $%d  BAL $%d" % [record_text, int(result.get("payout", 0)), int(result.get("credits", Progression.get_credits()))]
	next_profile = null if roguelike_result else Progression.get_next_unlocked_mission()
	if roguelike_result:
		$Panel/VBox/Actions/NextButton.text = "NEXT FLOOR"
		$Panel/VBox/Actions/NextButton.disabled = false
		$Panel/VBox/Actions/NextButton.grab_focus()
	elif next_profile == null:
		$Panel/VBox/Actions/NextButton.text = "COMPLETE" if profile.is_campaign_mission else "NO NEXT"
		$Panel/VBox/Actions/NextButton.disabled = true
	else:
		$Panel/VBox/Actions/NextButton.text = "NEXT"
		$Panel/VBox/Actions/NextButton.grab_focus()
	_play_report_reveal()

func _play_report_reveal() -> void:
	var cards: Array[Control] = [$Panel/VBox/Title, $Panel/VBox/Stats, $Panel/VBox/Forensics, $Panel/VBox/Record, $Panel/VBox/Actions]
	for card in cards: card.modulate.a = 0.0
	var tween := create_tween()
	for card in cards:
		tween.tween_property(card, "modulate:a", 1.0, 0.12)
		tween.tween_interval(0.05)

func _configure_run_report(result: Dictionary, forensic: Dictionary) -> void:
	var run: Dictionary = forensic.get("run", {})
	var finished := bool(run.get("complete", false))
	var floor_number := int(forensic.get("floor", maxi(1, Progression.get_roguelike_floor())))
	$Panel/VBox/Kicker.text = "DESCENT COMPLETE" if finished else "FLOOR %d / %d" % [floor_number, RoguelikeRunSession.FLOOR_LIMIT]
	$Panel/VBox/Title.text = "GRADE %s // %d PTS" % [result.grade, int(result.score)]
	$Panel/VBox/Narrative.text = "YOU MADE IT THROUGH.\nSTART A NEW DESCENT FOR A NEW ROOM ORDER." if finished else "THE NEXT FLOOR KEEPS YOUR HEALTH,\nAMMUNITION AND BLOOD. MAKE THEM COUNT."
	$Panel/VBox/Stats.text = "%d ROOMS   %d KILLS   %.1f SEC" % [int(forensic.get("rooms_cleared", 0)), int(forensic.get("kills", 0)), float(result.elapsed)]
	$Panel/VBox/Forensics.text = "STYLE // %s\nBEST CHAIN // %d\nRUN // %d ROOMS   %d KILLS" % [str(forensic.get("blood_build", "balanced")).to_upper(), int(forensic.get("best_combo", 0)), int(run.get("rooms", forensic.get("rooms_cleared", 0))), int(run.get("kills", forensic.get("kills", 0)))]
	$Panel/VBox/Record.text = "NO RETRIES // CLEAN DESCENT" if finished and int(run.get("retries", 0)) == 0 else "THE DESCENT CONTINUES" if not finished else "DESCENT SURVIVED"
	$Panel/VBox/Actions/MenuButton.text = "MENU"
	# Retrying a credited clear would farm rewards and duplicate run totals.
	# Death retry remains available in the floor itself, at its entry checkpoint.
	$Panel/VBox/Actions/RetryButton.hide()
	$Panel/VBox/Actions/NextButton.text = "NEW RUN" if finished else "NEXT FLOOR"
	$Panel/VBox/Actions/NextButton.disabled = false
	$Panel/VBox/Actions/NextButton.grab_focus()
	for node_name in ["Kicker", "Stats", "Forensics", "Record"]:
		$Panel/VBox.get_node(node_name).add_theme_color_override("font_color", Color("dedede"))
	_play_report_reveal()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): _back_to_menu()

func _retry() -> void:
	if transition_requested or SceneTransition.busy: return
	if profile == null: return
	if not Progression.begin_mission(profile.mission_id): return
	_lock_actions()
	SceneTransition.transition_to(profile.scene_path)

func _continue_campaign() -> void:
	if transition_requested or SceneTransition.busy: return
	if roguelike_result:
		var floor_profile := Progression.begin_roguelike_run() if Progression.run_session.is_complete() else Progression.begin_next_roguelike_floor()
		if floor_profile != null:
			_lock_actions()
			SceneTransition.transition_to(floor_profile.scene_path)
		return
	if next_profile == null or not Progression.begin_mission(next_profile.mission_id): return
	_lock_actions()
	SceneTransition.transition_to("res://scenes/ui/briefing_screen.tscn")

func _back_to_menu() -> void:
	if transition_requested or SceneTransition.busy: return
	_lock_actions()
	SceneTransition.transition_to("res://scenes/ui/title_menu.tscn")

func _lock_actions() -> void:
	transition_requested = true
	for button in $Panel/VBox/Actions.get_children():
		if button is BaseButton: button.disabled = true
