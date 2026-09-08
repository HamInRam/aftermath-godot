extends Control

const PIXEL_ICONS := preload("res://utility/pixel_icon_factory.gd")
const WEAPON_ICONS := preload("res://utility/weapon_ui_icon_factory.gd")
const GAMEPLAY_RULES := preload("res://utility/gameplay_design_rules.gd")
var index := 0

func _ready() -> void:
	UIDefaults.decorate_buttons(self)
	UIDefaults.animate_screen_intro($Panel)
	index = maxi(0, LoadoutCatalog.ORDER.find(Progression.get_current_kit_id()))
	$Panel/VBox/Actions/Back.pressed.connect(_back)
	$Panel/VBox/Actions/Previous.pressed.connect(_move.bind(-1))
	$Panel/VBox/Actions/Next.pressed.connect(_move.bind(1))
	$Panel/VBox/Actions/Confirm.pressed.connect(_confirm)
	$Panel/VBox/Actions/Armory.pressed.connect(_open_armory)
	$Panel/VBox/Actions/Modify.pressed.connect(_open_gunsmith)
	PIXEL_ICONS.assign($Panel/VBox/Actions/Back, "back", Color("bdaebe"))
	PIXEL_ICONS.assign($Panel/VBox/Actions/Confirm, "ammo", Color("73f7e4"))
	PIXEL_ICONS.assign($Panel/VBox/Actions/Armory, "case", Color("82d8ff"))
	_refresh()

func _move(direction: int) -> void:
	index = posmod(index + direction, LoadoutCatalog.ORDER.size())
	_refresh()

func _refresh() -> void:
	var kit := LoadoutCatalog.get_kit(LoadoutCatalog.ORDER[index])
	var weapon_lines := PackedStringArray()
	var weapon_ids := PackedStringArray()
	for weapon_id in kit.guns:
		var gun: GunData = AttackCatalog.get_gun_data(str(weapon_id), Progression.get_weapon_build(str(weapon_id)))
		weapon_ids.append(str(weapon_id))
		weapon_lines.append("%s  %d+%d" % [gun.display_name, gun.ammo_capacity, gun.ammo_capacity * int(kit.reserve_magazines)])
	$Panel/VBox/WeaponVisuals/Primary.texture = WEAPON_ICONS.weapon_icon(weapon_ids[0], Progression.get_weapon_build(weapon_ids[0])) if weapon_ids.size() > 0 else null
	$Panel/VBox/WeaponVisuals/Secondary.texture = WEAPON_ICONS.weapon_icon(weapon_ids[1], Progression.get_weapon_build(weapon_ids[1])) if weapon_ids.size() > 1 else null
	$Panel/VBox/WeaponVisuals/Divider.visible = weapon_ids.size() > 1
	$Panel/VBox/Title.text = str(kit.name)
	$Panel/VBox/Weapons.text = " // ".join(weapon_lines)
	$Panel/VBox/Description.text = str(kit.description)
	var average_damage := 0.0
	var average_penetration := 0.0
	for weapon_id in weapon_ids:
		var configured: GunData = AttackCatalog.get_gun_data(weapon_id, Progression.get_weapon_build(weapon_id))
		average_damage += configured.damage
		average_penetration += configured.penetration_power
	if not weapon_ids.is_empty():
		average_damage /= float(weapon_ids.size())
		average_penetration /= float(weapon_ids.size())
	$Panel/VBox/Stats.text = "MOVE %s %d%%  NOISE %s %d%%\nPOWER %02d  PEN %.1f" % [_stat_bar(float(kit.move)), roundi(float(kit.move) * 100.0), _stat_bar(float(kit.noise)), roundi(float(kit.noise) * 100.0), roundi(average_damage), average_penetration]
	$Panel/VBox/Index.text = "%02d / %02d%s" % [index + 1, LoadoutCatalog.ORDER.size(), " // EQUIPPED" if str(kit.id) == Progression.get_current_kit_id() else ""]
	UIDefaults.pulse_control($Panel/VBox/WeaponVisuals, Color("ffe5a8"))

func _stat_bar(value: float) -> String:
	var filled := clampi(roundi(value * 5.0), 0, 5)
	return "[" + "|".repeat(filled) + ".".repeat(5 - filled) + "]"

func _confirm() -> void:
	Progression.select_kit(LoadoutCatalog.ORDER[index])
	_back()

func _back() -> void:
	SceneTransition.transition_to("res://scenes/ui/briefing_screen.tscn")

func _open_armory() -> void:
	SceneTransition.transition_to("res://scenes/ui/armory_screen.tscn")

func _open_gunsmith() -> void:
	SceneTransition.transition_to("res://scenes/ui/gunsmith_screen.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): _back()
	elif event.is_action_pressed("ui_left"): _move(-1)
	elif event.is_action_pressed("ui_right"): _move(1)
