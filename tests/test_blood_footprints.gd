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
	_expect(not footprint.is_in_group("blood_source"), "old footprints must not be rescanned as fresh shoe-contamination sources")
	_expect(footprint.get_cleanup_type() == "blood_footprint", "footprints should expose a dedicated cleanup type")
	_expect(footprint.get_cleanup_cost() == 2, "footprints should require two cleanup strokes")
	var textured_footprint := FOOTPRINT_SCENE.instantiate() as BloodFootprint
	add_child(textured_footprint)
	textured_footprint.setup(0.8, false, {"spread": 1.35, "darken": 0.28}, true)
	_expect(textured_footprint.surface_spread > 1.0 and textured_footprint.smudged, "footprints should inherit floor absorption and turning smears")
	CleanupRegistry.unregister_target(textured_footprint)
	textured_footprint.queue_free()
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
	corpse.global_position = Vector2(200, 200)
	var emitter := player.get_node("BloodFootprintEmitter") as BloodFootprintEmitter
	# Simulate the exact reported case rather than only checking group metadata:
	# an old footprint under clean shoes must never create a new contamination charge.
	var old_footprint := FOOTPRINT_SCENE.instantiate() as BloodFootprint
	add_child(old_footprint)
	old_footprint.global_position = player.global_position
	old_footprint.setup(1.0, true)
	emitter.contamination_time = 0.0
	emitter.prints_remaining = 0
	emitter.touching_sources.clear()
	emitter._scan_blood_sources(player.global_position, player.global_position)
	_expect(is_zero_approx(emitter.contamination_time) and emitter.prints_remaining == 0, "stepping on an old footprint must not contaminate clean shoes")
	CleanupRegistry.unregister_target(old_footprint)
	old_footprint.queue_free()
	await get_tree().process_frame
	corpse.global_position = player.global_position
	emitter._scan_blood_sources()
	emitter.contamination_time = 0.0
	emitter.prints_remaining = 0
	player.set_cleanup_mode(true)
	_expect(emitter.prints_remaining == 0 and not emitter.generation_enabled, "cleanup mode must suppress all new bloody footprints")
	player.global_position += Vector2(9, 0)
	emitter._physics_process(0.08)
	await get_tree().process_frame
	_expect(get_tree().get_nodes_in_group("footprint").is_empty(), "walking across a corpse during cleanup must not create new evidence")
	player.set_cleanup_mode(false)
	player.global_position = corpse.global_position
	emitter.last_position = player.global_position
	emitter._scan_blood_sources()
	player.global_position += Vector2(9, 0)
	emitter._physics_process(0.08)
	await get_tree().process_frame
	_expect(get_tree().get_nodes_in_group("footprint").size() >= 1, "combat traversal should retain bloody-footprint gameplay")
	for node in get_tree().get_nodes_in_group("footprint"): node.queue_free()
	await get_tree().process_frame
	# A frame-to-frame sweep must detect a corpse even when neither endpoint is
	# inside the old 12px point-sampling radius.
	emitter.touching_sources.clear()
	emitter.contamination_time = 0.0
	emitter.prints_remaining = 0
	emitter.last_position = corpse.global_position - Vector2(24, 0)
	player.global_position = corpse.global_position + Vector2(24, 0)
	emitter.source_scan_cooldown = 0.0
	emitter._physics_process(0.2)
	_expect(emitter.prints_remaining > 0, "fast traversal across a corpse must contaminate shoes via swept contact")
	# Remaining on the same corpse must refresh a nearly exhausted contamination
	# charge instead of requiring the player to leave and re-enter.
	player.global_position = corpse.global_position
	emitter.last_position = player.global_position
	emitter.touching_sources = {corpse.get_instance_id(): true}
	emitter.contamination_time = 0.1
	emitter.prints_remaining = 1
	emitter.source_scan_cooldown = 0.0
	emitter._physics_process(0.11)
	_expect(emitter.contamination_time > 1.0 and emitter.prints_remaining > 2, "continued corpse contact must replenish shoe contamination")
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
