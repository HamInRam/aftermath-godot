class_name BloodSystem
extends Node2D

const BLOOD_STAIN_SCENE := preload("res://scenes/blood_stain.tscn")
const BLOOD_MIST_SCENE := preload("res://scenes/effects/blood_mist.tscn")

const WEAPON_PROFILES := {
	"pistol": {"blood_power": 1.0, "range": 150.0, "wall_reach": 42.0},
	"smg": {"blood_power": 0.72, "range": 125.0, "wall_reach": 34.0},
	"shotgun": {"blood_power": 1.85, "range": 92.0, "wall_reach": 54.0},
}

func emit_hit(hit_position: Vector2, projectile_direction: Vector2, damage: int, weapon_id: String, travel_distance: float, lethal: bool) -> void:
	var direction := projectile_direction.normalized()
	var profile: Dictionary = WEAPON_PROFILES.get(weapon_id, WEAPON_PROFILES.pistol)
	var distance_ratio := clampf(travel_distance / float(profile.range), 0.0, 1.0)
	var distance_force := lerpf(1.18, 0.72, distance_ratio)
	var lethal_force := 1.28 if lethal else 0.78
	var intensity := clampf(float(damage) * float(profile.blood_power) * distance_force * lethal_force, 0.55, 2.8)
	_spawn_mist(hit_position, direction, intensity)
	_spawn_ground_splatter(hit_position, direction, intensity)
	_spawn_wall_splatter(hit_position, direction, intensity, float(profile.wall_reach))

func _spawn_mist(hit_position: Vector2, direction: Vector2, intensity: float) -> void:
	var mist = BLOOD_MIST_SCENE.instantiate()
	add_child(mist)
	mist.global_position = hit_position
	mist.setup(direction, intensity)

func _spawn_ground_splatter(hit_position: Vector2, direction: Vector2, intensity: float) -> void:
	var stain = BLOOD_STAIN_SCENE.instantiate()
	add_child(stain)
	stain.global_position = hit_position + direction * randf_range(1.5, 3.0)
	stain.setup(direction, intensity, false, true)

func _spawn_wall_splatter(hit_position: Vector2, direction: Vector2, intensity: float, reach: float) -> void:
	var query := PhysicsRayQueryParameters2D.create(hit_position, hit_position + direction * reach, 2)
	var result := get_world_2d().direct_space_state.intersect_ray(query)
	if result.is_empty(): return
	var stain = BLOOD_STAIN_SCENE.instantiate()
	add_child(stain)
	stain.global_position = result.position - direction * 0.8
	stain.setup(direction, intensity * 0.82, true, false)
