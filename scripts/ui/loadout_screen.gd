extends Control

const PIXEL_ICONS := preload("res://utility/pixel_icon_factory.gd")
const GAMEPLAY_RULES := preload("res://utility/gameplay_design_rules.gd")
const GUNS := [
	preload("res://resources/weapons/pistol.tres"),
	preload("res://resources/weapons/smg.tres"),
	preload("res://resources/weapons/lmg.tres"),
	preload("res://resources/weapons/shotgun.tres"),
]
var index := 0

func _ready() -> void:
	UIDefaults.decorate_buttons(self)
	UIDefaults.animate_screen_intro($Panel)
	index = maxi(0, LoadoutCatalog.ORDER.find(Progression.get_current_kit_id()))
	$Panel/VBox/Actions/Back.pressed.connect(_back)
	$Panel/VBox/Actions/Previous.pressed.connect(_move.bind(-1))
	$Panel/VBox/Actions/Next.pressed.connect(_move.bind(1))
	$Panel/VBox/Actions/Confirm.pressed.connect(_confirm)
	PIXEL_ICONS.assign($Panel/VBox/Actions/Back, "back", Color("bdaebe"))
	PIXEL_ICONS.assign($Panel/VBox/Actions/Confirm, "ammo", Color("73f7e4"))
	_refresh()

func _move(direction: int) -> void:
	index = posmod(index + direction, LoadoutCatalog.ORDER.size())
	_refresh()

func _refresh() -> void:
	var kit := LoadoutCatalog.get_kit(LoadoutCatalog.ORDER[index])
	var weapon_lines := PackedStringArray()
	for slot in kit.guns:
		var gun: GunData = GUNS[int(slot)]
		weapon_lines.append("%s %d+%d" % [gun.display_name, gun.ammo_capacity, gun.ammo_capacity * int(kit.reserve_magazines)])
	$Panel/VBox/Title.text = str(kit.name)
	$Panel/VBox/Weapons.text = " // ".join(weapon_lines)
	$Panel/VBox/Description.text = str(kit.description)
	var aftermath: Dictionary = GAMEPLAY_RULES.get_kit_aftermath(kit.guns)
	$Panel/VBox/Stats.text = "MOVE %s %d%%  NOISE %s %d%%\nAFTERMATH %s  CLEAN +%d" % [_stat_bar(float(kit.move)), roundi(float(kit.move) * 100.0), _stat_bar(float(kit.noise)), roundi(float(kit.noise) * 100.0), str(aftermath.label), int(kit.cleaner_bonus)]
	$Panel/VBox/Index.text = "%02d / %02d%s" % [index + 1, LoadoutCatalog.ORDER.size(), " // EQUIPPED" if str(kit.id) == Progression.get_current_kit_id() else ""]
	UIDefaults.pulse_control($Panel/VBox/Weapons, Color("ffe5a8"))

func _stat_bar(value: float) -> String:
	var filled := clampi(roundi(value * 5.0), 0, 5)
	return "[" + "|".repeat(filled) + ".".repeat(5 - filled) + "]"

func _confirm() -> void:
	Progression.select_kit(LoadoutCatalog.ORDER[index])
	_back()

func _back() -> void:
	SceneTransition.transition_to("res://scenes/ui/briefing_screen.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): _back()
	elif event.is_action_pressed("ui_left"): _move(-1)
	elif event.is_action_pressed("ui_right"): _move(1)
