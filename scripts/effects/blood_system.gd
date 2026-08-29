class_name BloodSystem
extends Node2D

const BLOOD_MIST_SCENE := preload("res://scenes/effects/blood_mist.tscn")
const GORE_CHUNK_SCENE := preload("res://scenes/effects/gore_chunk.tscn")
const DETACHED_LIMB := preload("res://scripts/effects/detached_limb.gd")
const PIXEL_BLOOD_CANVAS := preload("res://scripts/effects/pixel_blood_canvas.gd")
var violence_scale := 1.0
var ground_canvas: Node2D
var wall_canvas: Node2D

func _ready() -> void:
	ground_canvas = PIXEL_BLOOD_CANVAS.new() as Node2D
	ground_canvas.name = "GroundPixelBlood"
	ground_canvas.configure("ground", -2)
	add_child(ground_canvas)
	wall_canvas = PIXEL_BLOOD_CANVAS.new() as Node2D
	wall_canvas.name = "WallPixelBlood"
	wall_canvas.configure("wall", 2)
	add_child(wall_canvas)

func emit_hit(hit_position: Vector2, projectile_direction: Vector2, damage: int, weapon_id: String, travel_distance: float, lethal: bool) -> void:
	emit_context(DamageContext.create(hit_position, projectile_direction, damage, weapon_id, travel_distance, lethal, "torso"))

func emit_context(context: DamageContext) -> void:
	var hit_position := context.hit_position
	var projectile_direction := context.direction
	var damage := context.damage
	var weapon_id := context.weapon_id
	var travel_distance := context.travel_distance
	var lethal := context.lethal
	var direction := projectile_direction.normalized()
	var profile := AttackCatalog.get_blood_profile(weapon_id)
	var violence: Dictionary = context.violence_profile if not context.violence_profile.is_empty() else AttackCatalog.get_violence_profile(weapon_id)
	var distance_ratio := clampf(travel_distance / float(profile.range), 0.0, 1.0)
	var distance_force := lerpf(1.18, 0.72, distance_ratio)
	var lethal_force := 1.28 if lethal else 0.78
	var zone_force := 1.42 if context.hit_zone == "head" else (0.82 if context.hit_zone == "limb" else 1.0)
	var intensity := clampf(float(damage) * float(profile.blood_power) * distance_force * lethal_force * zone_force * maxf(0.75, context.energy) * violence_scale * Settings.blood_density, 0.55, 4.8)
	var pattern: String = profile.pattern
	var cone: float = profile.cone
	# A compact dark entry puff is followed by the brighter, faster exit cone.
	var entry_scale := float(violence.get("entry", 1.0))
	var exit_scale := float(violence.get("exit", 1.0))
	var mist_scale := float(violence.get("mist", 1.0))
	_spawn_mist(hit_position - direction * 0.8, -direction, intensity * 0.22 * entry_scale, cone * 0.35, maxi(2, int(violence.get("drops", 8)) / 3))
	_spawn_mist(hit_position, direction, intensity * mist_scale, cone, int(violence.get("drops", 8)))
	_spawn_ground_splatter(hit_position - direction, -direction, intensity * 0.22 * entry_scale, "line", cone * 0.22, str(violence.get("wound", "puncture")))
	_spawn_ground_splatter(hit_position, direction, intensity * exit_scale, pattern, cone, str(violence.get("wound", "puncture")))
	_spawn_wall_splatter(hit_position, direction, intensity, float(profile.wall_reach), pattern, cone)
	if lethal:
		_spawn_ground_splatter(hit_position + direction * 2.0, direction.rotated(randf_range(-0.18, 0.18)), intensity * 0.72 * float(violence.get("pool_bias", 1.0)), pattern, cone * 1.12, str(violence.get("wound", "puncture")))
		if Settings.gore_enabled:
			_spawn_gore_chunks(hit_position, direction, intensity, weapon_id, int(violence.get("gore", 3)))
			_spawn_detached_limbs(hit_position, direction, intensity, context.hit_zone, int(violence.get("limbs", 0)))

func _spawn_mist(hit_position: Vector2, direction: Vector2, intensity: float, cone: float, deposit_count := 10) -> void:
	var mist = BLOOD_MIST_SCENE.instantiate()
	mist.position = to_local(hit_position)
	mist.setup(direction, intensity, NeonPalette.BLOOD_FRESH, cone, deposit_count)
	mist.droplet_settled.connect(spawn_micro_drop)
	RuntimeBudget.try_add("transient_fx", mist, self)

func spawn_micro_drop(world_position: Vector2, strength := 0.5, direction := Vector2.RIGHT) -> void:
	var surface_profile := {}
	var world := get_tree().get_first_node_in_group("pathfinding_world")
	if is_instance_valid(world) and world.has_method("get_nearest_walkable_position"):
		world_position = world.get_nearest_walkable_position(world_position)
		if world_position == Vector2.INF: return
	if is_instance_valid(world) and world.has_method("get_blood_surface_profile"): surface_profile = world.get_blood_surface_profile(world_position)
	if is_instance_valid(ground_canvas): ground_canvas.deposit_drop(world_position, strength, direction, surface_profile)

func _spawn_ground_splatter(hit_position: Vector2, direction: Vector2, intensity: float, pattern: String, cone: float, wound_kind := "") -> void:
	var stain_position := hit_position + direction * randf_range(1.5, 3.0)
	var world := get_tree().get_first_node_in_group("pathfinding_world")
	if is_instance_valid(world) and world.has_method("get_nearest_walkable_position"):
		stain_position = world.get_nearest_walkable_position(stain_position)
		if stain_position == Vector2.INF: return
	if is_instance_valid(ground_canvas): ground_canvas.stamp_splatter(stain_position, direction, intensity, pattern, cone, wound_kind)

func _spawn_wall_splatter(hit_position: Vector2, direction: Vector2, intensity: float, reach: float, pattern: String, cone: float) -> void:
	var query := PhysicsRayQueryParameters2D.create(hit_position, hit_position + direction * reach, 4)
	var result := get_world_2d().direct_space_state.intersect_ray(query)
	if result.is_empty(): return
	if is_instance_valid(wall_canvas): wall_canvas.stamp_splatter(result.position - direction * 0.8, -direction, intensity * 0.82, pattern, cone * 0.72, "wall")

func spawn_death_pool(world_position: Vector2, intensity := 1.0, wound_offset := Vector2.ZERO, direction := Vector2.RIGHT, attack_id := "pistol") -> void:
	var world := get_tree().get_first_node_in_group("pathfinding_world")
	var surface_profile: Dictionary = world.get_blood_surface_profile(world_position) if is_instance_valid(world) and world.has_method("get_blood_surface_profile") else {}
	if is_instance_valid(ground_canvas): ground_canvas.start_pool(world_position + wound_offset.limit_length(6.0), clampf(intensity, 0.7, 2.2), direction, surface_profile, AttackCatalog.get_violence_profile(attack_id))

func spawn_drag_smear(world_position: Vector2, direction: Vector2, strength := 0.65) -> void:
	if is_instance_valid(ground_canvas): ground_canvas.stamp_drag_smear(world_position, direction, strength)

func stamp_footprint(world_position: Vector2, direction: Vector2, left_foot: bool, strength: float, surface_profile := {}, smudged := false) -> void:
	if is_instance_valid(ground_canvas): ground_canvas.stamp_footprint(world_position, direction, left_foot, strength, surface_profile, smudged)

func clean_pixel_stroke(world_start: Vector2, world_end: Vector2, brush_radius: float, power: int, tool_name: String) -> bool:
	var cleaned := false
	if is_instance_valid(ground_canvas): cleaned = ground_canvas.clean_stroke(world_start, world_end, brush_radius, power, tool_name) or cleaned
	if is_instance_valid(wall_canvas): cleaned = wall_canvas.clean_stroke(world_start, world_end, brush_radius, power, tool_name) or cleaned
	return cleaned

func has_pixel_blood_near(world_position: Vector2, radius: float) -> bool:
	return is_instance_valid(ground_canvas) and ground_canvas.has_blood_near(world_position, radius)

func apply_pixel_water(world_position: Vector2, amount: int, flow_direction := Vector2.ZERO) -> void:
	if is_instance_valid(ground_canvas): ground_canvas.apply_external_water(world_position, amount, flow_direction)

func settle_pixel_blood_for_cleanup() -> void:
	if is_instance_valid(ground_canvas): ground_canvas.settle_all_pools()

func _spawn_gore_chunks(hit_position: Vector2, direction: Vector2, intensity: float, attack_id: String, profile_count := 3) -> void:
	var count := clampi(roundi(profile_count * clampf(intensity / 1.5, 0.7, 1.5)), 2, 20)
	for index in range(count):
		var chunk = GORE_CHUNK_SCENE.instantiate()
		chunk.position = to_local(hit_position + Vector2(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0)))
		chunk.setup(direction.rotated(randf_range(-0.65, 0.65)), intensity, index, attack_id)
		RuntimeBudget.try_add("gore", chunk, self)

func _spawn_detached_limbs(hit_position: Vector2, direction: Vector2, intensity: float, hit_zone: String, count: int) -> void:
	for index in clampi(count, 0, 3):
		var limb: CharacterBody2D = DETACHED_LIMB.new()
		limb.position = to_local(hit_position + direction.orthogonal() * randf_range(-2.0, 2.0))
		var kind := "head" if hit_zone == "head" and index == 0 else ("leg" if index % 2 == 1 else "arm")
		limb.setup(kind, direction, intensity)
		RuntimeBudget.try_add("gore", limb, self)
