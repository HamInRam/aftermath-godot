extends Control

const PIXEL_ICONS := preload("res://utility/pixel_icon_factory.gd")
const WEAPON_ICONS := preload("res://utility/weapon_ui_icon_factory.gd")

var class_index := 0
var weapon_index := 0
var visible_classes: Array[String] = []

func _ready() -> void:
	UIDefaults.decorate_buttons(self)
	UIDefaults.animate_screen_intro($Panel)
	_bind($Panel/Layout/Nav/Back, _back)
	_bind($Panel/Layout/ClassNav/PreviousClass, _move_class.bind(-1))
	_bind($Panel/Layout/ClassNav/NextClass, _move_class.bind(1))
	_bind($Panel/Layout/WeaponNav/PreviousWeapon, _move_weapon.bind(-1))
	_bind($Panel/Layout/WeaponNav/NextWeapon, _move_weapon.bind(1))
	_bind($Panel/Layout/Nav/Slot, _toggle_slot)
	_bind($Panel/Layout/Nav/Equip, _equip)
	_bind($Panel/Layout/Nav/Modify, _modify)
	PIXEL_ICONS.assign($Panel/Layout/Nav/Back, "back", Color("bdaebe"))
	PIXEL_ICONS.assign($Panel/Layout/Nav/Equip, "ammo", Color("73f7e4"))
	_rebuild_classes()
	_focus_current_weapon()
	_refresh()

func _bind(button: Button, callback: Callable) -> void:
	button.pressed.connect(callback)

func _rebuild_classes() -> void:
	visible_classes.clear()
	for weapon_class in WeaponPlatformCatalog.CLASS_ORDER:
		if Progression.editing_loadout_slot == "secondary" and weapon_class not in ["handgun", "pdw"]: continue
		if Progression.editing_loadout_slot == "primary" and weapon_class == "handgun": continue
		visible_classes.append(weapon_class)
	class_index = clampi(class_index, 0, visible_classes.size() - 1)

func _focus_current_weapon() -> void:
	var current_id := str(Progression.get_weapon_loadout().get(Progression.editing_loadout_slot, "glock_17_gen5_mos"))
	var current_class := str(WeaponPlatformCatalog.get_platform(current_id).get("class", "handgun"))
	if current_class in visible_classes: class_index = visible_classes.find(current_class)
	var ids := _weapon_ids()
	weapon_index = maxi(0, ids.find(current_id))

func _weapon_ids() -> PackedStringArray:
	return WeaponPlatformCatalog.get_class_weapon_ids(visible_classes[class_index]) if not visible_classes.is_empty() else PackedStringArray()

func _move_class(direction: int) -> void:
	class_index = posmod(class_index + direction, visible_classes.size())
	weapon_index = 0
	_refresh()

func _move_weapon(direction: int) -> void:
	var ids := _weapon_ids()
	weapon_index = posmod(weapon_index + direction, ids.size())
	_refresh()

func _selected_id() -> String:
	var ids := _weapon_ids()
	return str(ids[clampi(weapon_index, 0, ids.size() - 1)]) if not ids.is_empty() else "glock_17_gen5_mos"

func _refresh() -> void:
	var weapon_id := _selected_id()
	var platform := WeaponPlatformCatalog.get_platform(weapon_id)
	var data := AttackCatalog.get_gun_data(weapon_id, Progression.get_weapon_build(weapon_id))
	var unlocked := Progression.is_weapon_unlocked(weapon_id)
	$Panel/Layout/ClassNav/Class.text = "%s  %02d/%02d" % [WeaponPlatformCatalog.CLASS_NAMES[data.weapon_class], weapon_index + 1, _weapon_ids().size()]
	$Panel/Layout/WeaponNav/Weapon.text = data.display_name
	$Panel/Layout/Preview.texture = WEAPON_ICONS.weapon_icon(weapon_id, Progression.get_weapon_build(weapon_id))
	$Panel/Layout/Specs.text = "%s  //  %d RDS  //  %.1f KG  //  %d MM" % [data.caliber, data.ammo_capacity, data.empty_weight_grams / 1000.0, roundi(data.overall_length_mm)]
	$Panel/Layout/Trait.text = str(platform.get("trait", ""))
	$Panel/Layout/Stats.text = "ACC %s  CTL %s  MOB %s  SIG %s" % [_bar(5.2 - data.spread_degrees), _bar(3.0 - data.recoil_strength), _bar(data.aim_follow_speed / 3.4), _bar(5.0 - data.hearing_radius / 65.0)]
	$Panel/Layout/Status.text = "AVAILABLE // %d PARTS FIT" % _compatible_count(platform) if unlocked else "LOCKED // COMPLETE MORE CASES"
	$Panel/Layout/Nav/Slot.text = Progression.editing_loadout_slot.to_upper()
	$Panel/Layout/Nav/Equip.disabled = not unlocked
	$Panel/Layout/Nav/Modify.disabled = not unlocked

func _compatible_count(platform: Dictionary) -> int:
	var count := 0
	for slot in AttachmentCatalog.SLOT_ORDER: count += AttachmentCatalog.get_attachment_ids_for_slot(slot, platform).size()
	return count

func _bar(value: float) -> String:
	var count := clampi(roundi(value), 1, 5)
	return "|".repeat(count) + ".".repeat(5 - count)

func _toggle_slot() -> void:
	Progression.editing_loadout_slot = "secondary" if Progression.editing_loadout_slot == "primary" else "primary"
	_rebuild_classes()
	_focus_current_weapon()
	_refresh()

func _equip() -> void:
	if Progression.select_loadout_weapon(Progression.editing_loadout_slot, _selected_id()):
		$Panel/Layout/Status.text = "EQUIPPED TO %s" % Progression.editing_loadout_slot.to_upper()

func _modify() -> void:
	Progression.editing_weapon_id = _selected_id()
	SceneTransition.transition_to("res://scenes/ui/gunsmith_screen.tscn")

func _back() -> void:
	SceneTransition.transition_to("res://scenes/ui/loadout_screen.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): _back()
