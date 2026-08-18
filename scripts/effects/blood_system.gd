class_name BloodSystem
extends Node2D

const BLOOD_STAIN_SCENE := preload("res://scenes/blood_stain.tscn")
const BLOOD_MIST_SCENE := preload("res://scenes/effects/blood_mist.tscn")
const BLOOD_POOL_SCENE := preload("res://scenes/effects/blood_pool.tscn")
const GORE_CHUNK_SCENE := preload("res://scenes/effects/gore_chunk.tscn")
const BLOOD_DROP_SCENE := preload("res://scenes/effects/blood_drop.tscn")

func emit_hit(hit_position: Vector2, projectile_direction: Vector2, damage: int, weapon_id: String, travel_distance: float, lethal: bool) -> void:
	var direction := projectile_direction.normalized()
	var profile := AttackCatalog.get_blood_profile(weapon_id)
	var distance_ratio := clampf(travel_distance / float(profile.range), 0.0, 1.0)
	var distance_force := lerpf(1.18, 0.72, distance_ratio)
	var lethal_force := 1.28 if lethal else 0.78
	var intensity := clampf(float(damage) * float(profile.blood_power) * distance_force * lethal_force, 0.55, 2.8)
	var pattern: String = profile.pattern
	var cone: float = profile.cone
	_spawn_mist(hit_position, direction, intensity, cone)
	_spawn_ground_splatter(hit_position, direction, intensity, pattern, cone)
	_spawn_wall_splatter(hit_position, direction, intensity, float(profile.wall_reach), pattern, cone)
	if lethal: _spawn_gore_chunks(hit_position, direction, intensity, weapon_id)

func _spawn_mist(hit_position: Vector2, direction: Vector2, intensity: float, cone: float) -> void:
	var mist = BLOOD_MIST_SCENE.instantiate()
	mist.position = to_local(hit_position)
	mist.setup(direction, intensity, Color("b30325"), cone)
	mist.droplet_settled.connect(spawn_micro_drop)
	RuntimeBudget.try_add("transient_fx", mist, self)

func spawn_micro_drop(world_position: Vector2, strength := 0.5, direction := Vector2.RIGHT) -> void:
	var drop := BLOOD_DROP_SCENE.instantiate() as BloodDrop
	drop.position = to_local(world_position)
	var surface_profile := {}
	var world := get_tree().get_first_node_in_group("pathfinding_world")
	if is_instance_valid(world) and world.has_method("get_blood_surface_profile"): surface_profile = world.get_blood_surface_profile(world_position)
	drop.setup(strength, direction, surface_profile)
	RuntimeBudget.try_add("blood_stain", drop, self)

func _spawn_ground_splatter(hit_position: Vector2, direction: Vector2, intensity: float, pattern: String, cone: float) -> void:
	var stain = BLOOD_STAIN_SCENE.instantiate()
	stain.position = to_local(hit_position + direction * randf_range(1.5, 3.0))
	stain.setup(direction, intensity, false, true, pattern, cone)
	RuntimeBudget.try_add("blood_stain", stain, self)

func _spawn_wall_splatter(hit_position: Vector2, direction: Vector2, intensity: float, reach: float, pattern: String, cone: float) -> void:
	var query := PhysicsRayQueryParameters2D.create(hit_position, hit_position + direction * reach, 4)
	var result := get_world_2d().direct_space_state.intersect_ray(query)
	if result.is_empty(): return
	var stain = BLOOD_STAIN_SCENE.instantiate()
	stain.position = to_local(result.position - direction * 0.8)
	stain.setup(direction, intensity * 0.82, true, false, pattern, cone * 0.72)
	RuntimeBudget.try_add("blood_stain", stain, self)

func spawn_death_pool(world_position: Vector2, intensity := 1.0, wound_offset := Vector2.ZERO) -> void:
	var pool = BLOOD_POOL_SCENE.instantiate()
	pool.position = to_local(world_position + wound_offset.limit_length(6.0))
	pool.setup(clampf(intensity, 0.7, 2.2))
	RuntimeBudget.try_add("blood_pool", pool, self)

func _spawn_gore_chunks(hit_position: Vector2, direction: Vector2, intensity: float, attack_id: String) -> void:
	var violence_multiplier := 1.8 if attack_id in ["lmg", "bat", "execution", "execution_bat"] else 1.0
	var count := clampi(roundi(intensity * 2.6 * violence_multiplier), 2, 12)
	for index in range(count):
		var chunk = GORE_CHUNK_SCENE.instantiate()
		chunk.position = to_local(hit_position + Vector2(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0)))
		chunk.setup(direction.rotated(randf_range(-0.65, 0.65)), intensity, index, attack_id)
		RuntimeBudget.try_add("gore", chunk, self)
