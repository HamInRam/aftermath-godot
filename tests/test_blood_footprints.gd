extends Node

const FOOTPRINT_SCENE := preload("res://scenes/effects/blood_footprint.tscn")
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const CORPSE_SCENE := preload("res://scenes/corpse.tscn")

var failures := 0

func _ready() -> void:
	CleanupRegistry.reset()
	var footprint := FOOTPRINT_SCENE.instantiate() as BloodFootprint
	add_child(footprint)
	footprint.setup(0.18, true)
	_expect(footprint.is_in_group("footprint"), "footprints should be discoverable as evidence")
	_expect(footprint.get_cleanup_type() == "blood_footprint", "footprints should expose a dedicated cleanup type")
	_expect(footprint.get_cleanup_cost() == 2, "footprints should require two cleanup strokes")
	_expect(CleanupRegistry.get_remaining_count() == 1, "footprints should increase the evidence count")
	footprint.clean_step()
	_expect(is_instance_valid(footprint) and not footprint.is_queued_for_deletion(), "even the faintest footprint should survive one cleanup stroke")
	footprint.clean_step()
	await get_tree().process_frame
	_expect(CleanupRegistry.get_remaining_count() == 0, "fully cleaned footprints should leave the registry")
	var player := PLAYER_SCENE.instantiate()
	var corpse := CORPSE_SCENE.instantiate()
	add_child(player)
	add_child(corpse)
	player.global_position = Vector2(40, 40)
	corpse.global_position = player.global_position
	var emitter := player.get_node("BloodFootprintEmitter") as BloodFootprintEmitter
	emitter._scan_blood_sources()
	emitter.contamination_time = 0.0
	emitter.prints_remaining = 0
	player.set_cleanup_mode(true)
	_expect(emitter.prints_remaining > 0, "entering cleanup while touching a corpse should refresh shoe contamination")
	player.global_position += Vector2(9, 0)
	emitter._physics_process(0.08)
	await get_tree().process_frame
	_expect(get_tree().get_nodes_in_group("footprint").size() >= 1, "walking away from a corpse during cleanup should leave a footprint")
	player.queue_free()
	corpse.queue_free()
	for node in get_tree().get_nodes_in_group("footprint"): node.queue_free()
	await get_tree().process_frame
	CleanupRegistry.reset()
	if failures == 0:
		print("blood footprint regression: PASS")
		get_tree().quit(0)
	else:
		get_tree().quit(1)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
