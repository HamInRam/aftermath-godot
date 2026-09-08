extends Control

const PIXEL_ICONS := preload("res://utility/pixel_icon_factory.gd")
const WEAPON_ICONS := preload("res://utility/weapon_ui_icon_factory.gd")

var weapon_id := "colt_m4a1"
var slot_index := 0
var option_index := 0
var options := PackedStringArray()

func _ready() -> void:
	UIDefaults.decorate_buttons(self)
	UIDefaults.animate_screen_intro($Panel)
	weapon_id = Progression.editing_weapon_id if WeaponPlatformCatalog.has_weapon(Progression.editing_weapon_id) else str(Progression.get_weapon_loadout().primary)
	$Panel/Layout/SlotNav/PreviousSlot.pressed.connect(_move_slot.bind(-1))
	$Panel/Layout/SlotNav/NextSlot.pressed.connect(_move_slot.bind(1))
	$Panel/Layout/PartNav/PreviousPart.pressed.connect(_move_option.bind(-1))
	$Panel/Layout/PartNav/NextPart.pressed.connect(_move_option.bind(1))
	$Panel/Layout/Actions/Back.pressed.connect(_back)
	$Panel/Layout/Actions/Apply.pressed.connect(_apply)
	$Panel/Layout/Actions/Armory.pressed.connect(_armory)
	$Panel/Layout/Actions/Range.pressed.connect(_range)
	PIXEL_ICONS.assign($Panel/Layout/Actions/Back, "back", Color("bdaebe"))
	PIXEL_ICONS.assign($Panel/Layout/Actions/Apply, "ammo", Color("73f7e4"))
	_rebuild_options()
	_refresh()

func _slot() -> String:
	return AttachmentCatalog.SLOT_ORDER[slot_index]

func _rebuild_options() -> void:
	options = PackedStringArray([""])
	options.append_array(AttachmentCatalog.get_attachment_ids_for_slot(_slot(), WeaponPlatformCatalog.get_platform(weapon_id)))
	var equipped := _equipped_for_slot(_slot())
	option_index = maxi(0, options.find(equipped))

func _equipped_for_slot(slot: String) -> String:
	for attachment_id in Progression.get_weapon_build(weapon_id):
		if str(AttachmentCatalog.get_attachment(attachment_id).get("slot", "")) == slot: return attachment_id
	return ""

func _move_slot(direction: int) -> void:
	slot_index = posmod(slot_index + direction, AttachmentCatalog.SLOT_ORDER.size())
	_rebuild_options()
	_refresh()

func _move_option(direction: int) -> void:
	option_index = posmod(option_index + direction, options.size())
	_refresh()

func _refresh() -> void:
	var selected := options[option_index]
	var attachment := AttachmentCatalog.get_attachment(selected)
	var preview_build := Progression.get_weapon_build(weapon_id)
	for existing in preview_build.duplicate():
		if str(AttachmentCatalog.get_attachment(existing).get("slot", "")) == _slot(): preview_build.remove_at(preview_build.find(existing))
	if not selected.is_empty(): preview_build.append(selected)
	var base := AttackCatalog.get_gun_data(weapon_id)
	var preview := AttackCatalog.get_gun_data(weapon_id, preview_build)
	var comparison := WeaponStatResolver.compare(base, preview)
	$Panel/Layout/Kicker.text = "GUNSMITH // %d/%d PARTS" % [preview_build.size(), Progression.get_attachment_limit()]
	$Panel/Layout/Weapon.text = preview.display_name
	$Panel/Layout/VisualDeck/WeaponPreview.texture = WEAPON_ICONS.weapon_icon(weapon_id, preview_build)
	$Panel/Layout/VisualDeck/PartPreview.texture = WEAPON_ICONS.attachment_icon(selected, _slot())
	$Panel/Layout/SlotNav/Slot.text = AttachmentCatalog.SLOT_NAMES[_slot()]
	$Panel/Layout/PartNav/Part.text = "NO ATTACHMENT" if selected.is_empty() else str(attachment.name)
	$Panel/Layout/Summary.text = "FACTORY CONFIGURATION" if selected.is_empty() else str(attachment.summary)
	$Panel/Layout/Stats.text = "ACC %+d  CTL %+d  MOB %+d  CAP %+d  SIG %+d" % [comparison.accuracy, comparison.control, comparison.mobility, comparison.capacity, comparison.noise]
	$Panel/Layout/Build.text = "BUILD // " + ("FACTORY" if preview_build.is_empty() else " + ".join(_short_names(preview_build)))
	$Panel/Layout/Actions/Apply.text = "REMOVE" if selected.is_empty() else "FIT"

func _short_names(build: PackedStringArray) -> PackedStringArray:
	var names := PackedStringArray()
	for attachment_id in build: names.append(str(AttachmentCatalog.get_attachment(attachment_id).name).get_slice(" ", 0))
	return names

func _apply() -> void:
	var result := Progression.set_weapon_attachment(weapon_id, _slot(), options[option_index])
	$Panel/Layout/Summary.text = str(result.get("reason", "PART FITTED" if bool(result.get("success", false)) else "FIT FAILED"))
	_rebuild_options()
	_refresh()

func _armory() -> void:
	SceneTransition.transition_to("res://scenes/ui/armory_screen.tscn")

func _range() -> void:
	Progression.select_loadout_weapon("primary", weapon_id) if str(WeaponPlatformCatalog.get_platform(weapon_id).get("class", "")) != "handgun" else Progression.select_loadout_weapon("secondary", weapon_id)
	Progression.current_mission_id = "tactical_lab"
	var profile := MissionCatalog.get_mission("tactical_lab")
	if profile != null: SceneTransition.transition_to(profile.scene_path)

func _back() -> void:
	SceneTransition.transition_to("res://scenes/ui/loadout_screen.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): _back()
