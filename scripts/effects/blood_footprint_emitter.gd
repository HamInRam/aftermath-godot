class_name BloodFootprintEmitter
extends Node

const FOOTPRINT_SCENE := preload("res://scenes/effects/blood_footprint.tscn")

@export var contamination_duration := 4.5
@export var footprint_spacing := 7.0
@export var corpse_contact_radius := 12.0
@export var blood_contact_radius := 9.0
@export var maximum_prints := 12
@export_range(0.05, 0.5, 0.01) var source_scan_interval := 0.1

var contamination_time := 0.0
var prints_remaining := 0
var distance_since_print := 0.0
var last_position := Vector2.ZERO
var left_foot_next := true
var touching_sources: Dictionary = {}
var source_scan_cooldown := 0.0
var next_print_spacing := 7.0
var previous_direction := Vector2.RIGHT
var generation_enabled := true

@onready var actor := get_parent() as Node2D

func _ready() -> void:
	last_position = actor.global_position
	next_print_spacing = footprint_spacing * randf_range(0.88, 1.14)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(actor): return
	if not generation_enabled:
		last_position = actor.global_position
		return
	var current_position := actor.global_position
	source_scan_cooldown -= delta
	if source_scan_cooldown <= 0.0:
		source_scan_cooldown = source_scan_interval
		_scan_blood_sources(last_position, current_position)
	var travelled := current_position.distance_to(last_position)
	if contamination_time > 0.0:
		contamination_time = maxf(0.0, contamination_time - delta)
		if travelled > 0.05:
			distance_since_print += travelled
			if distance_since_print >= next_print_spacing and prints_remaining > 0:
				var travel_direction := last_position.direction_to(current_position)
				if _spawn_footprint(travel_direction):
					distance_since_print = fmod(distance_since_print, next_print_spacing)
					next_print_spacing = footprint_spacing * randf_range(0.86, 1.18)
				else:
					# Keep the shoes contaminated while the budget is temporarily full.
					# The next movement frame will retry as soon as a footprint slot opens.
					distance_since_print = footprint_spacing
	last_position = current_position

func contaminate(strength := 1.0) -> void:
	if not generation_enabled: return
	var normalized_strength := clampf(strength, 0.35, 1.0)
	contamination_time = maxf(contamination_time, contamination_duration * normalized_strength)
	prints_remaining = maxi(prints_remaining, roundi(maximum_prints * normalized_strength))
	distance_since_print = maxf(distance_since_print, footprint_spacing * 0.55)

func refresh_blood_contacts() -> void:
	if not generation_enabled: return
	# Combat-to-cleanup is a semantic phase boundary. A corpse already touching the
	# player during the transition must be allowed to contaminate their shoes again.
	touching_sources.clear()
	source_scan_cooldown = 0.0
	_scan_blood_sources(actor.global_position, actor.global_position)

func _scan_blood_sources(from_position := Vector2.INF, to_position := Vector2.INF) -> void:
	if from_position == Vector2.INF: from_position = actor.global_position
	if to_position == Vector2.INF: to_position = actor.global_position
	var current_sources: Dictionary = {}
	for source in get_tree().get_nodes_in_group("corpse"):
		_register_contact(source, corpse_contact_radius, 1.0, current_sources, from_position, to_position)
	var blood_system := get_tree().get_first_node_in_group("blood_system")
	if is_instance_valid(blood_system) and blood_system.has_method("has_pixel_blood_near"):
		var segment := to_position - from_position
		var samples := maxi(1, ceili(segment.length() / maxf(1.0, blood_contact_radius * 0.75)))
		for index in range(samples + 1):
			var sample := from_position.lerp(to_position, float(index) / float(samples))
			if blood_system.has_pixel_blood_near(sample, blood_contact_radius):
				var source_id := blood_system.get_instance_id()
				current_sources[source_id] = true
				var needs_refresh := contamination_time <= contamination_duration * 0.35 or prints_remaining <= 2
				if not touching_sources.has(source_id) or needs_refresh: contaminate(0.85)
				break
	# Permanent footprints can reach the mission-wide cap. They are evidence, not
	# fresh contamination sources, so keep them out of this hot-path scan entirely.
	for source in get_tree().get_nodes_in_group("blood_source"):
		if source.is_in_group("pixel_blood_chunk"): continue
		if source.has_method("get_cleanup_type") and str(source.get_cleanup_type()) == "blood_footprint": continue
		var contact_radius := 3.5 if source.is_in_group("micro_blood_drop") else blood_contact_radius
		_register_contact(source, contact_radius, 0.85, current_sources, from_position, to_position)
	touching_sources = current_sources

func _register_contact(source: Node, radius: float, strength: float, current_sources: Dictionary, from_position: Vector2, to_position: Vector2) -> void:
	if not source is Node2D or not is_instance_valid(source): return
	if source.has_method("is_bagged") and source.is_bagged(): return
	if _distance_squared_to_segment(source.global_position, from_position, to_position) > radius * radius: return
	var source_id := source.get_instance_id()
	current_sources[source_id] = true
	var needs_refresh := contamination_time <= contamination_duration * 0.35 or prints_remaining <= 2
	if not touching_sources.has(source_id) or needs_refresh: contaminate(strength)

func _distance_squared_to_segment(point: Vector2, segment_start: Vector2, segment_end: Vector2) -> float:
	var segment := segment_end - segment_start
	if segment.length_squared() <= 0.0001: return point.distance_squared_to(segment_start)
	var weight := clampf((point - segment_start).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return point.distance_squared_to(segment_start + segment * weight)

func _spawn_footprint(direction: Vector2) -> bool:
	if direction.length_squared() < 0.01 or prints_remaining <= 0: return false
	var lateral := direction.orthogonal() * (-1.7 if left_foot_next else 1.7)
	lateral *= randf_range(0.86, 1.15)
	var footprint_position := actor.global_position - direction * randf_range(2.0, 3.0) + lateral
	var footprint_direction := Vector2.RIGHT.rotated(lerp_angle(previous_direction.angle(), direction.angle(), 0.82) + randf_range(-0.045, 0.045))
	var step_strength := clampf(float(prints_remaining) / float(maximum_prints), 0.18, 1.0)
	var time_strength := clampf(contamination_time / contamination_duration, 0.18, 1.0)
	var world := get_tree().get_first_node_in_group("pathfinding_world")
	var surface_profile: Dictionary = world.get_blood_surface_profile(footprint_position) if is_instance_valid(world) and world.has_method("get_blood_surface_profile") else {}
	var turning_sharply := absf(previous_direction.angle_to(direction)) > 0.48
	var blood_system := get_tree().get_first_node_in_group("blood_system")
	if is_instance_valid(blood_system) and blood_system.has_method("stamp_footprint"):
		blood_system.stamp_footprint(footprint_position, footprint_direction, left_foot_next, minf(step_strength, time_strength), surface_profile, turning_sharply)
	else:
		var footprint := FOOTPRINT_SCENE.instantiate() as BloodFootprint
		if not RuntimeBudget.try_add("footprint", footprint, get_tree().current_scene): return false
		footprint.global_position = footprint_position
		footprint.global_rotation = footprint_direction.angle()
		footprint.setup(minf(step_strength, time_strength), left_foot_next, surface_profile, turning_sharply)
	previous_direction = direction
	left_foot_next = not left_foot_next
	prints_remaining -= 1
	if prints_remaining <= 0: contamination_time = 0.0
	return true

func get_contamination_ratio() -> float:
	if contamination_time <= 0.0 or prints_remaining <= 0: return 0.0
	return minf(float(prints_remaining) / maxf(1.0, float(maximum_prints)), contamination_time / contamination_duration)

func set_generation_enabled(enabled: bool) -> void:
	generation_enabled = enabled
	last_position = actor.global_position if is_instance_valid(actor) else Vector2.ZERO
	if enabled: return
	contamination_time = 0.0
	prints_remaining = 0
	distance_since_print = 0.0
	touching_sources.clear()
