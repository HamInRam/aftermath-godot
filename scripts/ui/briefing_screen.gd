extends Control

const PIXEL_ICONS := preload("res://utility/pixel_icon_factory.gd")

var profile: MissionProfile
func _ready() -> void:
	UIDefaults.decorate_buttons(self)
	UIDefaults.animate_screen_intro($Panel)
	PIXEL_ICONS.assign($Panel/VBox/Actions/BackButton, "back", Color("bdaebe"))
	PIXEL_ICONS.assign($Panel/VBox/Actions/IntelButton, "target", Color("82d8ff"))
	PIXEL_ICONS.assign($Panel/VBox/Actions/ContractButton, "case", Color("c77dff"))
	PIXEL_ICONS.assign($Panel/VBox/Actions/LoadoutButton, "ammo", Color("ffe5a8"))
	PIXEL_ICONS.assign($Panel/VBox/Actions/DeployButton, "play", Color("73f7e4"))
	profile = MissionCatalog.get_mission(Progression.current_mission_id)
	$Panel/VBox/Actions/BackButton.pressed.connect(_back_to_menu)
	$Panel/VBox/Actions/IntelButton.pressed.connect(_open_intel)
	$Panel/VBox/Actions/ContractButton.pressed.connect(_open_contracts)
	$Panel/VBox/Actions/LoadoutButton.pressed.connect(_open_loadout)
	$Panel/VBox/Actions/DeployButton.pressed.connect(_deploy)
	if profile == null:
		$Panel/VBox/Title.text = "NO MISSION SELECTED"
		$Panel/VBox/Briefing.text = "RETURN TO THE CASE FILES."
		$Panel/VBox/Actions/DeployButton.disabled = true
		return
	$Panel/VBox/Kicker.text = "CASE %02d // INCOMING CALL" % profile.campaign_order if profile.is_campaign_mission else "CONTROLLED EXERCISE"
	$Panel/VBox/Title.text = profile.display_name
	$Panel/VBox/Briefing.text = profile.briefing
	var objectives := "[TARGET] ELIMINATE HOSTILES"
	if profile.required_security_shutdowns > 0:
		objectives += "\n[CAMERA] DISABLE %d NODES" % profile.required_security_shutdowns
	objectives += "\n[RULE] %s" % profile.signature_rule
	$Panel/VBox/Objectives.text = objectives
	_refresh_selection_summary()
	var best := Progression.get_best_result(profile.mission_id)
	var mastery := Progression.get_mastery(profile.mission_id)
	var medal_count := 0
	for achieved in mastery.values():
		if bool(achieved): medal_count += 1
	$Panel/VBox/Record.text = ("NO PRIOR RECORD" if best.is_empty() else "BEST // %s // %04d PTS" % [best.grade, int(best.score)]) + " // MASTERY %d/5" % medal_count
	$Panel/VBox/Actions/DeployButton.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): _back_to_menu()

func _refresh_selection_summary() -> void:
	var contracts := ContractCatalog.get_available_contracts(profile)
	var contract := contracts[0] if not contracts.is_empty() else {"name": "STANDARD", "payout": 1.0}
	for candidate in contracts:
		if str(candidate.id) == Progression.get_current_contract_id(): contract = candidate
	var modifier := RunModifierCatalog.get_modifier(Progression.get_current_modifier_id())
	var kit := LoadoutCatalog.get_kit(Progression.get_current_kit_id())
	$Panel/VBox/Contract.text = "%s  x%.2f  |  %s\nKIT  %s" % [str(contract.name), float(contract.payout), str(modifier.name), str(kit.name)]

func _open_contracts() -> void:
	SceneTransition.transition_to("res://scenes/ui/contract_screen.tscn")

func _open_intel() -> void:
	SceneTransition.transition_to("res://scenes/ui/intel_screen.tscn")

func _open_loadout() -> void:
	SceneTransition.transition_to("res://scenes/ui/loadout_screen.tscn")

func _deploy() -> void:
	if profile != null: SceneTransition.transition_to(profile.scene_path)

func _back_to_menu() -> void:
	SceneTransition.transition_to("res://scenes/ui/title_menu.tscn")
