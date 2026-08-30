extends Sprite2D

@export var world_offset := Vector2(3, 3)
var target: Node2D
var _last_position := Vector2(INF, INF)
var _last_rotation := INF
var _last_scale := Vector2(INF, INF)

func _ready() -> void:
	target = get_parent() as Node2D
	top_level = true
	_update_transform()

func _process(_delta: float) -> void:
	if is_instance_valid(target): _update_transform()

func _update_transform() -> void:
	var next_position := target.global_position + world_offset
	var next_rotation := target.global_rotation
	var next_scale := target.global_scale
	if next_position != _last_position:
		global_position = next_position
		_last_position = next_position
	if not is_equal_approx(next_rotation, _last_rotation):
		global_rotation = next_rotation
		_last_rotation = next_rotation
	if next_scale != _last_scale:
		global_scale = next_scale
		_last_scale = next_scale
