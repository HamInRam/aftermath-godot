extends Node

const LEVEL := preload("res://scenes/main.tscn")
var failures := 0

func _ready() -> void:
	var level = LEVEL.instantiate()
	level.record_progress = false
	add_child(level)
	await get_tree().process_frame
	var props := level.get_tree().get_nodes_in_group("destructible_prop")
	_expect(props.size() >= 10, "rebuilt levels should contain a meaningful density of destructible low-pixel props")
	var prop: DestructibleProp
	for candidate in props:
		if candidate is DestructibleProp and not candidate.is_movable():
			prop = candidate
			break
	_expect(is_instance_valid(prop), "campaign maps should retain heavy fixtures that partially break before collapsing")
	if not is_instance_valid(prop):
		get_tree().quit(failures)
		return
	var original_cell := (level.get_node("TileMap") as TileWorld).floor_layer.local_to_map(prop.position)
	prop.take_damage(1, prop.global_position - Vector2.RIGHT)
	_expect(prop.state == DestructibleProp.PropState.DAMAGED, "first impact should expose a readable damaged state")
	prop.take_damage(1, prop.global_position - Vector2.RIGHT)
	await get_tree().process_frame
	_expect(prop.state == DestructibleProp.PropState.DESTROYED, "second impact should collapse the prop into low-pixel debris")
	_expect((level.get_node("TileMap") as TileWorld).path_grid.is_point_solid(original_cell) == false, "destroyed furniture should open its navigation cell")
	_expect(level.mission_tracker.property_damage >= 1, "destroyed props should count as forensic property damage")
	_expect(prop.get_interaction_prompt().contains("RESTORE"), "destroyed props should become cleanup interactions")
	_expect(prop.interact(), "cleanup should restore destroyed furniture")
	await get_tree().process_frame
	_expect(prop.state == DestructibleProp.PropState.RESTORED, "restoration should return the prop to a stable state")
	_expect((level.get_node("TileMap") as TileWorld).path_grid.is_point_solid(original_cell), "restored furniture should close its navigation cell")
	level.queue_free()
	await get_tree().process_frame
	if failures == 0: print("destructible environment regression: PASS")
	get_tree().quit(failures)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
