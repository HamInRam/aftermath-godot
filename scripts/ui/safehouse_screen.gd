extends Control

const PIXEL_ICONS := preload("res://utility/pixel_icon_factory.gd")

const BRANCHES := {
	"executioner": {"name": "EXECUTIONER", "description": "+3% COMBAT MOBILITY PER RANK"},
	"ghost": {"name": "GHOST", "description": "-8% PLAYER GUNSHOT NOISE PER RANK"},
	"cleaner": {"name": "CLEANER", "description": "+1 BIOLOGICAL CLEANING STEP PER RANK"},
}

func _ready() -> void:
	UIDefaults.decorate_buttons(self)
	UIDefaults.animate_screen_intro($Panel)
	PIXEL_ICONS.assign($Panel/VBox/Actions/BackButton, "case", Color("82d8ff"))
	PIXEL_ICONS.assign($Panel/VBox/Actions/WorkshopButton, "upgrade", Color("73f7e4"))
	$Panel/VBox/Actions/BackButton.pressed.connect(_back)
	$Panel/VBox/Actions/WorkshopButton.pressed.connect(_workshop)
	for branch in BRANCHES:
		var button := get_node("Panel/VBox/Specializations/%s" % branch.capitalize()) as Button
		PIXEL_ICONS.assign(button, "target" if branch != "cleaner" else "clean", Color("ff658c") if branch == "executioner" else (Color("82d8ff") if branch == "ghost" else Color("73f7e4")))
		button.pressed.connect(_buy_specialization.bind(branch))
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): _back()

func _refresh() -> void:
	$Panel/VBox/Status.text = "SPECIALIZATION POINTS %d // HEAT %d%%" % [Progression.get_specialization_points(), Progression.get_heat()]
	var stats := Progression.get_career_stats()
	$Panel/VBox/Feedback.text = "CAREER // %d CASES  %d SHOTS  %d PERFECT" % [int(stats.get("cases", 0)), int(stats.get("shots", 0)), int(stats.get("perfect_cleans", 0))]
	for branch in BRANCHES:
		var definition: Dictionary = BRANCHES[branch]
		var level := Progression.get_specialization_level(branch)
		var button := get_node("Panel/VBox/Specializations/%s" % branch.capitalize()) as Button
		var nodes := "[" + "#".repeat(level) + "-".repeat(3 - level) + "]"
		button.text = "%s  %s\n%s" % [str(definition.name), nodes, str(definition.description)]
		button.disabled = level >= 3 or Progression.get_specialization_points() <= 0
	$Panel/VBox/Heat.text = _get_heat_description()

func _get_heat_description() -> String:
	var heat := Progression.get_heat()
	if heat >= 75: return "HEAT CRITICAL // RESPONSE WINDOWS WILL TIGHTEN"
	if heat >= 40: return "HEAT ELEVATED // CLEANER WORK IS DRAWING ATTENTION"
	return "HEAT LOW // OPERATIONS REMAIN DISCREET"

func _buy_specialization(branch: String) -> void:
	var result := Progression.buy_specialization(branch)
	$Panel/VBox/Feedback.text = "SPECIALIZATION INSTALLED" if bool(result.get("success", false)) else str(result.get("reason", "UNAVAILABLE"))
	_refresh()

func _workshop() -> void:
	SceneTransition.transition_to("res://scenes/ui/upgrade_screen.tscn")

func _back() -> void:
	SceneTransition.transition_to("res://scenes/ui/title_menu.tscn")
