extends Node2D
class World:
	extends Node2D
	func get_tactical_room_id(p: Vector2) -> String:
		return "exterior_approach" if p.x < 0 else str(int(p.x / 80))
class Hostile:
	extends Node2D
	var is_dead := false
	var enemy_type := "melee"
	var heard := Vector2.INF
	func set_room_combat_active(_active: bool) -> void: pass
	func react_to_room_attack(p: Vector2) -> void: heard = p
var failures := 0
func check(value: bool, message: String) -> void:
	if not value: failures += 1; push_error(message)
func _ready() -> void:
	var world := World.new()
	var actors := Node2D.new()
	var controller := RoomRunController.new()
	add_child(world); add_child(actors); add_child(controller)
	controller.set_physics_process(false)
	for room in range(4):
		for i in range(12):
			var enemy := Hostile.new()
			enemy.position = Vector2(room * 80 + 20,i * 2)
			enemy.enemy_type = "gunner" if i == 0 else "melee"
			actors.add_child(enemy)
	controller._on_swarm_noise(Vector2(20,0),200,"gunshot_pistol")
	check(controller.swarm_queue.is_empty(), "no pre-deployment alarm")
	controller.configure(world,actors)
	controller._on_swarm_noise(Vector2(20,0),200,"gunshot_pistol")
	check(controller.swarm_queue.is_empty(), "room-paced default disables cross-room recruitment")
	controller.swarm_recruitment_enabled = true
	controller._on_swarm_noise(Vector2(-10,0),200,"gunshot_pistol")
	check(controller.swarm_queue.is_empty(), "exterior is safe")
	controller._on_swarm_noise(Vector2(20,0),200,"enemy_gunshot_pistol")
	check(controller.swarm_queue.is_empty(), "enemy fire cannot recursively alert floor")
	controller._on_swarm_noise(Vector2(20,0),200,"gunshot_pistol")
	check(controller.swarm_queue.size() == 18, "reinforcement cap")
	for entry in controller.swarm_queue:
		check(entry.enemy.enemy_type == "melee" and entry.enemy.global_position.x < 240, "only two nearby rooms and melee roles")
	controller._on_swarm_noise(Vector2(20,0),200,"door")
	check(controller.swarm_queue.size() == 18, "noise cooldown prevents duplicate queue")
	controller._physics_process(0.01)
	check(controller.get_active_enemy_count() == 1, "staggered wake counted by HUD")
	controller._physics_process(0.01)
	check(controller.get_active_enemy_count() == 1, "not whole queue in one frame")
	for i in range(20): controller._physics_process(0.2)
	check(controller.get_active_enemy_count() == 18, "bounded wave completes")
	for enemy in actors.get_children():
		if enemy.get_meta("rogue_room_active", false): check(enemy.heard == Vector2(20,0), "investigate sound snapshot")
	controller.configure(world,actors)
	check(controller.swarm_queue.is_empty() and controller.get_active_enemy_count() == 0, "restart resets queue")
	print("SWARM_ALARM_OK" if failures == 0 else "SWARM_ALARM_FAILED")
	get_tree().quit(0 if failures == 0 else 1)
