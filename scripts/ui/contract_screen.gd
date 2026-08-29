extends Control

const PIXEL_ICONS := preload("res://utility/pixel_icon_factory.gd")
var contracts: Array[Dictionary] = []
var index := 0

func _ready() -> void:
	UIDefaults.decorate_buttons(self)
	UIDefaults.animate_screen_intro($Panel)
	var profile := MissionCatalog.get_mission(Progression.current_mission_id)
	contracts = ContractCatalog.get_available_contracts(profile)
	for candidate_index in range(contracts.size()):
		if str(contracts[candidate_index].id) == Progression.get_current_contract_id(): index = candidate_index
	$Panel/VBox/Actions/Back.pressed.connect(_back)
	$Panel/VBox/Actions/Previous.pressed.connect(_move.bind(-1))
	$Panel/VBox/Actions/Next.pressed.connect(_move.bind(1))
	$Panel/VBox/Actions/Confirm.pressed.connect(_confirm)
	PIXEL_ICONS.assign($Panel/VBox/Actions/Back, "back", Color("bdaebe"))
	PIXEL_ICONS.assign($Panel/VBox/Actions/Confirm, "check", Color("73f7e4"))
	_refresh()

func _move(direction: int) -> void:
	if contracts.is_empty(): return
	index = posmod(index + direction, contracts.size())
	_refresh()

func _refresh() -> void:
	if contracts.is_empty(): return
	var contract := contracts[index]
	$Panel/VBox/Title.text = str(contract.name)
	$Panel/VBox/Payout.text = "PAYOUT x%.2f" % float(contract.payout)
	$Panel/VBox/Description.text = str(contract.description)
	$Panel/VBox/Index.text = "%02d / %02d%s" % [index + 1, contracts.size(), " // ACTIVE" if str(contract.id) == Progression.get_current_contract_id() else ""]
	var profile := MissionCatalog.get_mission(Progression.current_mission_id)
	if profile != null and str(contract.id) == ContractCatalog.get_recommended_contract(profile): $Panel/VBox/Index.text += " // RECOMMENDED"
	UIDefaults.pulse_control($Panel/VBox/Title, Color("c77dff"))

func _confirm() -> void:
	if not contracts.is_empty(): Progression.select_contract(str(contracts[index].id))
	_back()

func _back() -> void:
	SceneTransition.transition_to("res://scenes/ui/briefing_screen.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): _back()
	elif event.is_action_pressed("ui_left"): _move(-1)
	elif event.is_action_pressed("ui_right"): _move(1)
