extends Control

func _ready() -> void:
	UIDefaults.decorate_buttons(self)
	$Panel/Layout/Back.pressed.connect(_back)
	$Panel/Layout/Back.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): _back()
	elif event.is_action_pressed("ui_page_down"): $Panel/Layout/Scroll.scroll_vertical += 40
	elif event.is_action_pressed("ui_page_up"): $Panel/Layout/Scroll.scroll_vertical -= 40

func _back() -> void:
	SceneTransition.transition_to("res://scenes/ui/title_menu.tscn")
