extends Node2D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const THROWN_SCENE := preload("res://scenes/props/thrown_weapon.tscn")

var failures := 0
var emitted_weapon_id := ""
var emitted_rounds := -1
var emitted_build := PackedStringArray()

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.set_physics_process(false)
	player.acquire_gun("hk_mp5a5", 7, PackedStringArray(["aimpoint_micro_t2"]))
	player.weapon_throw_requested.connect(_on_weapon_throw_requested)
	_expect(player.throw_equipped_gun(Vector2.RIGHT), "equipped gun should be throwable")
	_expect(emitted_weapon_id == "hk_mp5a5" and emitted_rounds == 7 and emitted_build == PackedStringArray(["aimpoint_micro_t2"]), "throw signal should preserve weapon, magazine and fitted parts")
	_expect(player.gun.weapon_id == "glock_17_gen5_mos", "throwing MP5 should fall back to owned Glock")
	_expect(player.gun.get_weapon_ammo("hk_mp5a5") == 0, "a thrown gun magazine must not remain cached in inventory")
	player.acquire_gun(emitted_weapon_id, emitted_rounds, emitted_build)
	_expect(player.gun.ammo == 7, "re-picking a thrown gun must not duplicate its ammunition")
	player.gun.set_reserve_ammo("hk_mp5a5", 11)
	player.gun.reload()
	_expect(player.gun.is_reloading, "partly loaded gun should start reloading before throw")
	_expect(player.throw_equipped_gun(Vector2.RIGHT), "reloading gun can be thrown immediately")
	var fallback_rounds: int = player.gun.ammo
	player.gun._on_reload_timer_timeout()
	_expect(player.gun.ammo == fallback_rounds and not player.gun.is_reloading, "a cancelled reload must not fill the fallback gun")
	_expect(player.gun.get_reserve_ammo("hk_mp5a5") == 11, "reserve cartridges remain with the player when their gun is thrown")
	_expect(player.throw_equipped_gun(Vector2.RIGHT), "last owned gun should also be throwable")
	_expect(player.owned_gun_indices.is_empty() and player.equipped_mode == "melee", "throwing the last gun should force melee mode")
	_expect(player.gun.gun_data == null and player.gun.weapon_id.is_empty(), "last thrown gun must clear stale gun state")
	player._equip_weapon("gun")
	_expect(player.equipped_mode == "melee", "an empty inventory must not re-equip a thrown gun")
	var enemy = ENEMY_SCENE.instantiate()
	add_child(enemy)
	enemy.set_physics_process(false)
	var thrown = THROWN_SCENE.instantiate()
	add_child(thrown)
	thrown.setup(Vector2.RIGHT, "hk_mp5a5", 7, PackedStringArray(["aimpoint_micro_t2"]))
	thrown._resolve_impact(enemy)
	_expect(enemy.state == enemy.State.KNOCKED_DOWN, "thrown gun should knock down a normal enemy")
	var knockdown_velocity: Vector2 = enemy.velocity
	thrown._resolve_impact(enemy)
	_expect(enemy.velocity == knockdown_velocity, "one thrown gun must resolve only one enemy impact")
	await get_tree().process_frame
	var pickups := get_tree().get_nodes_in_group("weapon_pickup")
	_expect(not pickups.is_empty(), "thrown gun should settle as a recoverable pickup")
	if not pickups.is_empty():
		_expect(pickups[0].weapon_id == "hk_mp5a5" and pickups[0].rounds == 7 and pickups[0].attachment_ids == PackedStringArray(["aimpoint_micro_t2"]), "recovered pickup should retain rounds and fitted parts")
		_expect(pickups[0].has_visible_weapon_art(), "a settled weapon must render a gun silhouette even when its optional texture resource is empty")
	# Exercise actual swept movement through a two-pixel wall, including a frame
	# hitch. The launch starts at the actor, so no pre-offset can jump the wall.
	var wall := StaticBody2D.new()
	wall.collision_layer = 4
	wall.position = Vector2(130, 140)
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(2, 80)
	shape.shape = rectangle
	wall.add_child(shape)
	add_child(wall)
	var wall_throw = THROWN_SCENE.instantiate()
	add_child(wall_throw)
	wall_throw.position = Vector2(100, 140)
	wall_throw.setup(Vector2.RIGHT, "hk_mp5a5", 3)
	wall_throw.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	wall_throw._physics_process(0.2)
	_expect(wall_throw.global_position.x < 130.0 and wall_throw.velocity.x < 0.0, "a fast throw must bounce on the near side of a thin wall")
	wall_throw.queue_free()
	wall.queue_free()
	if failures == 0: print("weapon throw regression: PASS")
	for actor in [enemy, player]:
		for audio_node in actor.find_children("*", "AudioStreamPlayer", true, false):
			var audio := audio_node as AudioStreamPlayer
			audio.stop()
			audio.stream = null
		actor.queue_free()
	for pickup in pickups: pickup.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(failures)

func _on_weapon_throw_requested(_origin: Vector2, _direction: Vector2, weapon_id: String, rounds: int, attachment_ids: PackedStringArray) -> void:
	emitted_weapon_id = weapon_id
	emitted_rounds = rounds
	emitted_build = attachment_ids

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
