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

@onready var actor := get_parent() as Node2D

func _ready() -> void:
	last_position = actor.global_position

func _physics_process(delta: float) -> void:
	if not is_instance_valid(actor): return
	source_scan_cooldown -= delta
	if source_scan_cooldown <= 0.0:
		source_scan_cooldown = source_scan_interval
		_scan_blood_sources()
	var current_position := actor.global_position
	var travelled := current_position.distance_to(last_position)
	if contamination_time > 0.0:
		contamination_time = maxf(0.0, contamination_time - delta)
		if travelled > 0.05:
			distance_since_print += travelled
			if distance_since_print >= footprint_spacing and prints_remaining > 0:
				_spawn_footprint(last_position.direction_to(current_position))
				distance_since_print = fmod(distance_since_print, footprint_spacing)
	last_position = current_position

func contaminate(strength := 1.0) -> void:
	var normalized_strength := clampf(strength, 0.35, 1.0)
	contamination_time = maxf(contamination_time, contamination_duration * normalized_strength)
	prints_remaining = maxi(prints_remaining, roundi(maximum_prints * normalized_strength))
	distance_since_print = maxf(distance_since_print, footprint_spacing * 0.55)

func _scan_blood_sources() -> void:
	var current_sources: Dictionary = {}
	for source in get_tree().get_nodes_in_group("corpse"):
		_register_contact(source, corpse_contact_radius, 1.0, current_sources)
	for source in get_tree().get_nodes_in_group("blood"):
		if source.is_in_group("footprint"): continue
		_register_contact(source, blood_contact_radius, 0.85, current_sources)
	touching_sources = current_sources

func _register_contact(source: Node, radius: float, strength: float, current_sources: Dictionary) -> void:
	if not source is Node2D or not is_instance_valid(source): return
	if actor.global_position.distance_squared_to(source.global_position) > radius * radius: return
	var source_id := source.get_instance_id()
	current_sources[source_id] = true
	if not touching_sources.has(source_id): contaminate(strength)

func _spawn_footprint(direction: Vector2) -> void:
	if direction.length_squared() < 0.01 or prints_remaining <= 0: return
	var footprint := FOOTPRINT_SCENE.instantiate() as BloodFootprint
	get_tree().current_scene.add_child(footprint)
	var lateral := direction.orthogonal() * (-1.7 if left_foot_next else 1.7)
	footprint.global_position = actor.global_position - direction * 2.5 + lateral
	footprint.global_rotation = direction.angle()
	var step_strength := clampf(float(prints_remaining) / float(maximum_prints), 0.18, 1.0)
	var time_strength := clampf(contamination_time / contamination_duration, 0.18, 1.0)
	footprint.setup(minf(step_strength, time_strength), left_foot_next)
	left_foot_next = not left_foot_next
	prints_remaining -= 1
	if prints_remaining <= 0: contamination_time = 0.0
