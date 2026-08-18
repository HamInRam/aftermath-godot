extends Node

const FOOTPRINT_SCENE := preload("res://scenes/effects/blood_footprint.tscn")

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
