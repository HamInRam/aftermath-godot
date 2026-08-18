class_name HudController
extends CanvasLayer

const UI_DEFAULTS := preload("res://utility/scripts/ui_defaults.gd")

var status_label: Label
var detail_label: Label
var ammo_label: Label
var combo_label: Label
var interaction_label: Label
var objective_label: Label
var performance_label: Label

func _init() -> void:
	layer = 30

func _ready() -> void:
	status_label = _make_label(Vector2(10, 7), 9, Color("fff1f7"))
	detail_label = _make_label(Vector2(10, 20), 7, Color("e2cedd"))
	objective_label = _make_label(Vector2(10, 30), 7, Color("73f7e4"))
	objective_label.size = Vector2(300, 12)
	performance_label = _make_label(Vector2(10, 42), 6, Color("82d8ff"))
	performance_label.size = Vector2(300, 10)
	ammo_label = _make_label(Vector2(270, 158), 8, Color("ffe5a8"))
	combo_label = _make_label(Vector2(266, 11), 10, Color("ff3d78"))
	interaction_label = _make_label(Vector2(10, 145), 9, Color("fff0a8"))
	interaction_label.size = Vector2(300, 14)
	interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var controls := _make_label(Vector2(10, 165), 7, Color("bdaebe"))
	controls.text = "WASD // 1 GUN  2 FIST  3 KNIFE  4 BAT // E USE // Q THROW"

func set_combo(combo: int) -> void:
	combo_label.text = ("x%d" % combo) if combo > 1 else ""

func set_interaction(text: String) -> void:
	interaction_label.text = text

func set_objective(text: String) -> void:
	objective_label.text = text

func set_performance(text: String) -> void:
	performance_label.text = text

func _make_label(pos: Vector2, size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	UI_DEFAULTS.apply_label(label, size, color)
	add_child(label)
	return label
