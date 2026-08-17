extends Sprite2D

@export var world_offset := Vector2(3, 3)
var target: Node2D

func _ready() -> void:
	target = get_parent() as Node2D
	top_level = true
	_update_transform()

func _process(_delta: float) -> void:
	if is_instance_valid(target): _update_transform()

func _update_transform() -> void:
	global_position = target.global_position + world_offset
	global_rotation = target.global_rotation
	global_scale = target.global_scale
