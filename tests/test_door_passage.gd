extends Node

const MISSIONS := {
	"nightclub": "res://scenes/main.tscn",
	"sandwich_shop": "res://scenes/levels/sandwich_shop.tscn",
	"tactical_lab": "res://scenes/levels/after_hours.tscn",
	"harbor_exchange": "res://scenes/levels/harbor_exchange.tscn",
	"motel_witness": "res://scenes/levels/motel_witness.tscn",
	"penthouse": "res://scenes/levels/penthouse.tscn",
	"cold_storage": "res://scenes/levels/cold_storage.tscn",
	"casino_floor": "res://scenes/levels/casino_floor.tscn",
	"police_archive": "res://scenes/levels/police_archive.tscn",
	"slaughterhouse": "res://scenes/levels/slaughterhouse.tscn",
	"broadcast_tower": "res://scenes/levels/broadcast_tower.tscn",
	"last_call": "res://scenes/levels/last_call.tscn",
}

var failures := 0

func _ready() -> void:
	for mission_id: String in MISSIONS:
		await _verify_mission_doors(mission_id, MISSIONS[mission_id])
	if failures == 0: print("door passage regression: PASS")
	get_tree().quit(failures)

func _verify_mission_doors(mission_id: String, scene_path: String) -> void:
	var level = (load(scene_path) as PackedScene).instantiate()
	level.record_progress = false
	add_child(level)
	await get_tree().process_frame
	await get_tree().physics_frame
	var player := level.player as CharacterBody2D
	player.set_physics_process(false)
	for enemy in level.get_node("Enemies").get_children():
		enemy.set_physics_process(false)
		enemy.collision_layer = 0
		enemy.collision_mask = 0
	var specs: Array[Dictionary] = level.get_node("TileMap").get_door_specs()
	var doors := level.get_node("Doors").get_children().filter(func(door: Node) -> bool: return is_instance_valid(door) and not door.is_queued_for_deletion())
	_expect(doors.size() == specs.size(), "%s must instantiate every authored door" % mission_id)
	for index in range(mini(doors.size(), specs.size())):
		var root := doors[index] as Node2D
		var panel := root.get_node("Door") as SwingDoor
		panel.set_physics_process(false)
		var spec: Dictionary = specs[index]
		var normal := Vector2.RIGHT.rotated(float(spec.rotation))
		var passage_center: Vector2 = spec.passage_center
		player.global_position = passage_center - normal * 14.0
		panel.push_door_open(player, normal * 115.0)
		for frame in 40: panel._physics_process(1.0 / 60.0)
		await get_tree().process_frame
		_expect(panel.current_state == SwingDoor.DoorState.OPEN, "%s door %d must finish opening" % [mission_id, index])
		player.global_position = passage_center - normal * 14.0
		var last_blocker := "none"
		for frame in 30:
			var collision := player.move_and_collide(normal * (80.0 / 60.0))
			if collision != null:
				var collider = collision.get_collider()
				last_blocker = "%s:%s" % [collider.name, collider.get_class()]
		var crossed := (player.global_position - passage_center).dot(normal)
		_expect(crossed > 7.0, "%s door %d must allow the real player collider through after opening (%.1fpx, blocker %s)" % [mission_id, index, crossed, last_blocker])
	level.queue_free()
	await get_tree().process_frame

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
