extends Control

const PIXEL_ICONS := preload("res://utility/pixel_icon_factory.gd")

var profile: MissionProfile

func _ready() -> void:
	UIDefaults.decorate_buttons(self)
	UIDefaults.animate_screen_intro($Panel)
	profile = MissionCatalog.get_mission(Progression.current_mission_id)
	$Panel/Layout/Footer/Back.pressed.connect(_back)
	$Panel/Layout/Footer/Deploy.pressed.connect(_deploy)
	PIXEL_ICONS.assign($Panel/Layout/Footer/Back, "back", Color("bdaebe"))
	PIXEL_ICONS.assign($Panel/Layout/Footer/Deploy, "play", Color("73f7e4"))
	if profile == null:
		$Panel/Layout/Title.text = "INTEL UNAVAILABLE"
		$Panel/Layout/Scroll/Body.text = "RETURN TO CASE FILES AND SELECT AN OPERATION."
		$Panel/Layout/Footer/Deploy.disabled = true
		return
	$Panel/Layout/Title.text = profile.display_name
	$Panel/Layout/Summary.text = "%s // %s RESISTANCE // %d ACCESS ROUTES" % [profile.location_archetype, profile.expected_resistance, maxi(1, profile.access_routes)]
	$Panel/Layout/Scroll/Body.text = ContractCatalog.get_operational_forecast(profile, Progression.get_current_kit_id(), Progression.get_current_contract_id()) + "\n\nPRIMARY OBJECTIVE\nELIMINATE REQUIRED HOSTILES" + (" // DISABLE %d SECURITY NODES" % profile.required_security_shutdowns if profile.required_security_shutdowns > 0 else "") + "\n\nFIELD NOTE\nCOMBAT CHOICES CREATE THE EVIDENCE YOU MUST REMOVE. CONTROLLED FORCE REDUCES CLEANUP TIME AND RESTORATION COST."
	$Panel/Layout/Footer/Deploy.grab_focus()

func _back() -> void:
	SceneTransition.transition_to("res://scenes/ui/briefing_screen.tscn")

func _deploy() -> void:
	if profile != null: SceneTransition.transition_to(profile.scene_path)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): _back()
	elif event.is_action_pressed("ui_page_down"):
		$Panel/Layout/Scroll.scroll_vertical += 36
	elif event.is_action_pressed("ui_page_up"):
		$Panel/Layout/Scroll.scroll_vertical -= 36
