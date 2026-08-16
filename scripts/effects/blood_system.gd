class_name BloodSystem
extends Node2D

const BLOOD_STAIN_SCENE := preload("res://scenes/blood_stain.tscn")
const BLOOD_MIST_SCENE := preload("res://scenes/effects/blood_mist.tscn")
const BLOOD_POOL_SCENE := preload("res://scenes/effects/blood_pool.tscn")
const GORE_CHUNK_SCENE := preload("res://scenes/effects/gore_chunk.tscn")

const WEAPON_PROFILES := {
	"pistol": {"blood_power": 1.0, "range": 150.0, "wall_reach": 48.0, "pattern": "line", "cone": 0.24},
	"smg": {"blood_power": 0.72, "range": 125.0, "wall_reach": 38.0, "pattern": "fan", "cone": 0.48},
	"lmg": {"blood_power": 1.65, "range": 175.0, "wall_reach": 58.0, "pattern": "fan", "cone": 0.68},
	"shotgun": {"blood_power": 1.85, "range": 92.0, "wall_reach": 64.0, "pattern": "radial", "cone": 1.05},
}

func emit_hit(hit_position: Vector2, projectile_direction: Vector2, damage: int, weapon_id: String, travel_distance: float, lethal: bool) -> void:
	var direction := projectile_direction.normalized()
	var profile: Dictionary = WEAPON_PROFILES.get(weapon_id, WEAPON_PROFILES.pistol)
	var distance_ratio := clampf(travel_distance / float(profile.range), 0.0, 1.0)
	var distance_force := lerpf(1.18, 0.72, distance_ratio)
	var lethal_force := 1.28 if lethal else 0.78
	var intensity := clampf(float(damage) * float(profile.blood_power) * distance_force * lethal_force, 0.55, 2.8)
	var pattern: String = profile.pattern
	var cone: float = profile.cone
	_spawn_mist(hit_position, direction, intensity, cone)
	_spawn_ground_splatter(hit_position, direction, intensity, pattern, cone)
	_spawn_wall_splatter(hit_position, direction, intensity, float(profile.wall_reach), pattern, cone)
	if lethal: _spawn_gore_chunks(hit_position, direction, intensity)

func _spawn_mist(hit_position: Vector2, direction: Vector2, intensity: float, cone: float) -> void:
	var mist = BLOOD_MIST_SCENE.instantiate()
	add_child(mist)
	mist.global_position = hit_position
	mist.setup(direction, intensity, Color("b30325"), cone)

func _spawn_ground_splatter(hit_position: Vector2, direction: Vector2, intensity: float, pattern: String, cone: float) -> void:
	var stain = BLOOD_STAIN_SCENE.instantiate()
	add_child(stain)
	stain.global_position = hit_position + direction * randf_range(1.5, 3.0)
	stain.setup(direction, intensity, false, true, pattern, cone)

func _spawn_wall_splatter(hit_position: Vector2, direction: Vector2, intensity: float, reach: float, pattern: String, cone: float) -> void:
	var query := PhysicsRayQueryParameters2D.create(hit_position, hit_position + direction * reach, 4)
	var result := get_world_2d().direct_space_state.intersect_ray(query)
	if result.is_empty(): return
	var stain = BLOOD_STAIN_SCENE.instantiate()
	add_child(stain)
	stain.global_position = result.position - direction * 0.8
	stain.setup(direction, intensity * 0.82, true, false, pattern, cone * 0.72)

func spawn_death_pool(world_position: Vector2, intensity := 1.0) -> void:
	var pool = BLOOD_POOL_SCENE.instantiate()
	add_child(pool)
	pool.global_position = world_position
	pool.setup(clampf(intensity, 0.7, 2.2))

func _spawn_gore_chunks(hit_position: Vector2, direction: Vector2, intensity: float) -> void:
	var count := clampi(roundi(intensity * 2.6), 2, 8)
	for index in range(count):
		var chunk = GORE_CHUNK_SCENE.instantiate()
		add_child(chunk)
		chunk.global_position = hit_position + Vector2(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0))
		chunk.setup(direction.rotated(randf_range(-0.65, 0.65)), intensity, index)
