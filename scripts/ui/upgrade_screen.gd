class_name UpgradeScreen
extends Control

const PIXEL_ICONS := preload("res://utility/pixel_icon_factory.gd")

var buttons: Array[Button] = []

func _ready() -> void:
	UIDefaults.decorate_buttons(self)
	UIDefaults.animate_screen_intro($Panel)
	PIXEL_ICONS.assign($Panel/VBox/Header/BackButton, "back", Color("bdaebe"))
	$Panel/VBox/Header/BackButton.pressed.connect(_back)
	for upgrade_id in Progression.UPGRADE_ORDER:
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 18)
		button.add_theme_font_size_override("font_size", 7)
		UIDefaults.apply_button(button)
		PIXEL_ICONS.assign(button, "upgrade", Color("73f7e4"))
		button.pressed.connect(_attempt_purchase.bind(upgrade_id))
		button.focus_entered.connect(_show_details.bind(upgrade_id))
		$Panel/VBox/UpgradeList.add_child(button)
		button.set_meta("upgrade_id", upgrade_id)
		buttons.append(button)
	_refresh()
	if not buttons.is_empty(): buttons[0].grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_U): _back()

func _refresh() -> void:
	$Panel/VBox/Header/Credits.text = "BALANCE  $%d" % Progression.get_credits()
	for button in buttons:
		var offer := Progression.get_upgrade_offer(str(button.get_meta("upgrade_id")))
		var nodes := "[" + "#".repeat(int(offer.level)) + "-".repeat(3 - int(offer.level)) + "]"
		button.text = "%s  %s  %s" % [str(offer.name), nodes, ("MAX" if bool(offer.maxed) else "$%d" % int(offer.cost))]
		button.disabled = bool(offer.maxed)
	var focused := get_viewport().gui_get_focus_owner()
	if focused is Button and focused.has_meta("upgrade_id"): _show_details(str(focused.get_meta("upgrade_id")))

func _show_details(upgrade_id: String) -> void:
	var offer := Progression.get_upgrade_offer(upgrade_id)
	$Panel/VBox/Description.text = "%s\nCURRENT LEVEL %d/3" % [str(offer.description).to_upper(), int(offer.level)]

func _attempt_purchase(upgrade_id: String) -> void:
	var result := Progression.buy_upgrade(upgrade_id)
	if bool(result.get("success", false)):
		$Panel/VBox/Status.text = "INSTALLED // %s L%d" % [upgrade_id.to_upper().replace("_", " "), int(result.level)]
	else:
		$Panel/VBox/Status.text = str(result.get("reason", "PURCHASE FAILED"))
		if result.has("shortfall"): $Panel/VBox/Status.text += " // NEED $%d" % int(result.shortfall)
	_refresh()
	UIDefaults.pulse_control($Panel/VBox/Status, Color("73f7e4") if bool(result.get("success", false)) else Color("ff536e"))

func _back() -> void:
	SceneTransition.transition_to("res://scenes/ui/title_menu.tscn")
