class_name EnvironmentHazard
extends Area2D

const LIQUID_SYSTEM_SCRIPT := preload("res://scripts/effects/pixel_liquid_system.gd")
const LIQUID_KINDS := [&"water", &"oil", &"spill", &"cleaner"]

var hazard_kind := "spill"
var radius := 3.0
var target_radius := 20.0
var cleanup_steps := 4
var source_active := true
var pulse := 0.0
var source_accumulator := 0.0
var peak_liquid_load := 1
var damage_cooldowns := {}
var liquid_system: Node2D
var flow_direction := Vector2.RIGHT

func setup(kind: String, strength := 1.0) -> void:
	hazard_kind = kind
	target_radius = clampf(14.0 + strength * 8.0, 14.0, 30.0)
	cleanup_steps = 3 if kind == "glass" else 5
	flow_direction = Vector2.RIGHT.rotated(randf_range(-PI, PI))
	collision_layer = 0
	collision_mask = 3
	monitoring = true
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = target_radius
	collision.shape = circle
	add_child(collision)
	add_to_group("environment_hazard")
	CleanupRegistry.register_target(self)
	if StringName(hazard_kind) in LIQUID_KINDS:
		liquid_system = LIQUID_SYSTEM_SCRIPT.get_or_create(get_tree()) as Node2D
		liquid_system.emit_burst(global_position, StringName(hazard_kind), flow_direction, strength)
		liquid_system.deposit_source(global_position, StringName(hazard_kind), 4.0, strength, flow_direction)
		peak_liquid_load = maxi(1, liquid_system.amount_near(global_position, target_radius * 1.45, StringName(hazard_kind)))
	z_index = 1
	queue_redraw()

func _physics_process(delta: float) -> void:
	pulse += delta
	radius = move_toward(radius, target_radius, delta * _spread_speed())
	for key in damage_cooldowns: damage_cooldowns[key] = maxf(0.0, float(damage_cooldowns[key]) - delta)
	if StringName(hazard_kind) in LIQUID_KINDS and is_instance_valid(liquid_system):
		source_accumulator += delta
		if source_accumulator >= 0.18:
			source_accumulator = 0.0
			# Plumbing keeps feeding the puddle until repaired. Containers and oil
			# complete one finite spill instead of creating liquid forever.
			if hazard_kind == "water" and source_active:
				liquid_system.deposit_source(global_position, &"water", radius, 1.0, flow_direction)
			elif radius < target_radius - 0.5:
				liquid_system.deposit_source(global_position, StringName(hazard_kind), radius, 0.8, flow_direction)
			peak_liquid_load = maxi(peak_liquid_load, liquid_system.amount_near(global_position, target_radius * 1.45, StringName(hazard_kind)))
	elif hazard_kind == "electric" and source_active:
		_apply_electric_damage()
	queue_redraw()

func _apply_electric_damage() -> void:
	if not is_instance_valid(liquid_system):
		liquid_system = get_tree().get_first_node_in_group("pixel_liquid_system") as Node2D
	for body in get_overlapping_bodies():
		if not body.has_method("take_damage"): continue
		var body_position := (body as Node2D).global_position
		var direct_contact := body_position.distance_to(global_position) <= 8.0
		var wet_connection: bool = is_instance_valid(liquid_system) and bool(liquid_system.has_conductive_connection(global_position, body_position, target_radius * 1.65))
		if not direct_contact and not wet_connection: continue
		var id := body.get_instance_id()
		if float(damage_cooldowns.get(id, 0.0)) > 0.0: continue
		damage_cooldowns[id] = 1.2
		body.take_damage(1, global_position)
		Events.publish_combat_noise(global_position, 72.0, "electrical_arc")

func set_source_active(active: bool) -> void:
	source_active = active
	queue_redraw()

func get_cleanup_type() -> String: return "debris" if hazard_kind == "glass" else "spill"
func get_cleanup_cost() -> int: return 3 if hazard_kind == "glass" else 5
func get_cleanup_progress() -> float:
	if StringName(hazard_kind) in LIQUID_KINDS and is_instance_valid(liquid_system):
		var remaining: int = int(liquid_system.amount_near(global_position, target_radius * 1.45, StringName(hazard_kind)))
		return clampf(1.0 - float(remaining) / float(maxi(1, peak_liquid_load)), 0.0, 1.0)
	return 1.0 - float(cleanup_steps) / float(get_cleanup_cost())
func is_cleanup_blocked() -> bool: return source_active and hazard_kind in ["water", "electric"]

func clean_step() -> void:
	if is_cleanup_blocked(): return
	if StringName(hazard_kind) in LIQUID_KINDS and is_instance_valid(liquid_system):
		var removal := 54 if hazard_kind in ["oil", "spill"] else 72
		liquid_system.remove_near(global_position, target_radius * 1.45, StringName(hazard_kind), removal)
		if liquid_system.amount_near(global_position, target_radius * 1.45, StringName(hazard_kind)) <= 0: _resolve()
		return
	cleanup_steps = maxi(0, cleanup_steps - 1)
	if cleanup_steps <= 0: _resolve()
	queue_redraw()

func _resolve() -> void:
	CleanupRegistry.unregister_target(self)
	queue_free()

func _spread_speed() -> float:
	return {"water": 8.5, "cleaner": 7.0, "spill": 5.0, "oil": 3.4}.get(hazard_kind, 9.0)

func _draw() -> void:
	# Liquids are exclusively rendered by PixelLiquidSystem; no smooth circles.
	if StringName(hazard_kind) in LIQUID_KINDS: return
	if hazard_kind == "glass":
		for index in range(11):
			var angle := float(index) * 2.399
			var point := Vector2(roundi(cos(angle) * radius * (0.35 + float(index % 3) * 0.16)), roundi(sin(angle) * radius * (0.35 + float(index % 3) * 0.16)))
			draw_rect(Rect2(point, Vector2(2 if index % 2 == 0 else 1, 1)), Color("d9ffff"))
	elif hazard_kind == "smoke":
		for index in range(10):
			var angle := float(index) * 1.71 + floorf(pulse * 2.0) * 0.12
			var point := Vector2(roundi(cos(angle) * radius * 0.7), roundi(sin(angle) * radius * 0.7))
			draw_rect(Rect2(point - Vector2.ONE * 2.0, Vector2(4, 4)), Color(0.72, 0.72, 0.8, 0.10 + float(index % 3) * 0.04))
	elif hazard_kind == "electric" and source_active:
		for index in range(4):
			var angle := float(index) * TAU / 4.0 + floorf(pulse * 10.0) * 0.16
			var reach := radius * (0.55 + float((index + int(pulse * 7.0)) % 3) * 0.2)
			var end := Vector2(roundi(cos(angle) * reach), roundi(sin(angle) * reach))
			var midpoint := Vector2(roundi(end.x * 0.5), roundi(end.y * 0.5 + (2.0 if index % 2 == 0 else -2.0)))
			draw_polyline(PackedVector2Array([Vector2.ZERO, Vector2(midpoint.x, 0), midpoint, Vector2(end.x, midpoint.y), end]), Color("d9ffff"), 1.0)
