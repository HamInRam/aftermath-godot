extends Control

func _ready() -> void:
	$Panel/VBox/NightclubButton.pressed.connect(_open_level.bind("res://scenes/main.tscn"))
	$Panel/VBox/SandwichButton.pressed.connect(_open_level.bind("res://scenes/levels/sandwich_shop.tscn"))
	$Panel/VBox/TacticalLabButton.pressed.connect(_open_level.bind("res://scenes/levels/tactical_lab.tscn"))
	$Panel/VBox/AfterHoursButton.pressed.connect(_open_level.bind("res://scenes/levels/after_hours.tscn"))
	$Panel/VBox/QuitButton.pressed.connect(get_tree().quit)
	$Panel/VBox/AfterHoursButton.grab_focus()

func _open_level(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)
