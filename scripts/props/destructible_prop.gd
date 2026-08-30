class_name DestructibleProp
extends CharacterBody2D

const MATERIAL_BURST := preload("res://scripts/effects/material_burst.gd")
const PHYSICAL_DEBRIS := preload("res://scripts/props/physical_debris.gd")
const ENVIRONMENT_HAZARD := preload("res://scripts/effects/environment_hazard.gd")
const RESTORATION_ANCHOR := preload("res://scripts/props/prop_restoration_anchor.gd")
const PIXELS := preload("res://utility/pixel_art_painter.gd")

signal solidity_changed(solid: bool)

enum PropState { INTACT, DAMAGED, DESTROYED, RESTORED }

const MOVABLE_KINDS := ["plant", "tv", "speaker", "crate", "vending", "slot_machine", "table"]

var prop_kind := "table"
var state := PropState.INTACT
var hp := 2
var last_impact_direction := Vector2.RIGHT
var accent := Color("b25a38")
var _collision: CollisionShape2D
var material_profile: Dictionary = {}
var structural_stage := 0
var impact_point := Vector2.ZERO
var active_hazard: EnvironmentHazard
var home_global_position := Vector2.ZERO
var home_rotation := 0.0
var simulated_rotation := 0.0
var spin_velocity := 0.0
var displaced := false
var displacement_reported := false
var cleanup_ready := false
var dragging_actor: Node2D
var restoration_anchor: Node2D
var snap_radius := 11.0
var physics_active := false

func setup(kind: String, tint := Color("b25a38")) -> void:
	prop_kind = kind
	accent = tint
	material_profile = DestructionMaterial.for_kind(kind)
	hp = 2
	structural_stage = 0
	collision_layer = 4
	# Props block actors as before, while movable props also collide with walls,
	# enemies and the player during their short controlled launch window.
	collision_mask = 7
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("destructible_prop")
	_collision = CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = _get_size() - Vector2(2, 2)
	_collision.shape = shape
	add_child(_collision)
	z_index = 3
	queue_redraw()

func _ready() -> void:
	home_global_position = global_position
	home_rotation = rotation
	simulated_rotation = rotation
	if is_movable(): call_deferred("_create_restoration_anchor")
	set_physics_process(false)

func _create_restoration_anchor() -> void:
	if not is_inside_tree() or is_instance_valid(restoration_anchor) or not is_movable(): return
	restoration_anchor = RESTORATION_ANCHOR.new() as Node2D
	var parent := get_parent()
	if not is_instance_valid(parent): return
	parent.add_child(restoration_anchor)
	restoration_anchor.global_position = home_global_position
	restoration_anchor.global_rotation = home_rotation
	restoration_anchor.setup(_get_size(), prop_kind, accent)
	if displaced: restoration_anchor.mark_needed()
	if cleanup_ready: restoration_anchor.set_cleanup_active(true)

func take_damage(amount: int, source_position := Vector2.ZERO) -> void:
	if state in [PropState.DESTROYED, PropState.RESTORED]: return
	var direction := source_position.direction_to(global_position) if source_position != Vector2.ZERO else Vector2.RIGHT
	_apply_impact(float(maxi(1, amount)), direction, global_position, "generic")

func receive_projectile_impact(projectile_velocity: Vector2, hit_position: Vector2) -> void:
	receive_projectile_impact_context(projectile_velocity, hit_position, "pistol", 1)

func receive_projectile_impact_context(projectile_velocity: Vector2, hit_position: Vector2, weapon_id: String, damage: int) -> void:
	var speed_energy := clampf(projectile_velocity.length() / 650.0, 0.45, 1.8) * maxi(1, damage)
	var attack_kind := "shotgun" if weapon_id == "shotgun" else "projectile"
	_apply_impact(DestructionMaterial.energy_for_attack(attack_kind, speed_energy), projectile_velocity.normalized(), hit_position, attack_kind)

func receive_melee_impact(direction: Vector2, melee_type: String) -> void:
	_apply_impact(DestructionMaterial.energy_for_attack(melee_type, 1.0), direction, global_position - direction * 3.0, melee_type)

func receive_thrown_impact(direction: Vector2, energy := 1.0) -> void:
	_apply_impact(DestructionMaterial.energy_for_attack("thrown", energy), direction, global_position - direction * 2.0, "thrown")

func receive_door_impact(direction: Vector2, energy := 1.0) -> void:
	_apply_impact(DestructionMaterial.energy_for_attack("door", energy), direction, global_position, "door")

func receive_corpse_impact(direction: Vector2, energy := 1.0) -> void:
	_apply_impact(DestructionMaterial.energy_for_attack("corpse", energy), direction, global_position, "corpse")

func _apply_impact(energy: float, direction: Vector2, world_hit_point: Vector2, attack_kind: String) -> void:
	if state in [PropState.DESTROYED, PropState.RESTORED]: return
	last_impact_direction = direction.normalized() if direction.length_squared() > 0.01 else Vector2.RIGHT
	impact_point = to_local(world_hit_point)
	var effective_energy := energy / maxf(0.25, float(material_profile.get("resistance", 1.0)))
	var structural_damage := 2 if effective_energy >= 1.75 else 1
	var previous_structural_stage := structural_stage
	hp -= structural_damage
	structural_stage = mini(2, structural_stage + structural_damage)
	Events.prop_impacted.emit(global_position, str(material_profile.get("material", "wood")), effective_energy, structural_stage)
	_spawn_burst(effective_energy * 0.55)
	if is_movable():
		# Small decor keeps a recognizable core. Impacts chip it and throw it across
		# the room instead of replacing the whole object with an anonymous debris pile.
		state = PropState.DAMAGED
		hp = maxi(1, hp)
		_launch_movable(last_impact_direction, effective_energy, attack_kind)
		if structural_stage >= 2 and previous_structural_stage < 2: _spawn_physical_chunks(effective_energy * 0.45)
		queue_redraw()
		return
	if hp <= 0:
		_destroy(effective_energy, attack_kind)
	else:
		state = PropState.DAMAGED
		var lean := clampf(effective_energy * 0.09, 0.04, 0.2)
		rotation += randf_range(-lean, lean)
		if is_instance_valid(_collision) and _collision.shape is RectangleShape2D:
			var shape := (_collision.shape as RectangleShape2D).duplicate() as RectangleShape2D
			shape.size.y = maxf(3.0, shape.size.y * 0.72)
			_collision.shape = shape
		Events.publish_combat_noise(global_position, float(material_profile.get("noise", 80.0)) * 0.65, "%s_impact" % material_profile.material)
		queue_redraw()

func _destroy(energy := 1.0, attack_kind := "generic") -> void:
	state = PropState.DESTROYED
	if is_instance_valid(_collision): _collision.set_deferred("disabled", true)
	add_to_group("resettable_furniture")
	Events.prop_destroyed.emit(global_position, prop_kind)
	Events.publish_combat_noise(global_position, float(material_profile.get("noise", 86.0)), "%s_break" % material_profile.material)
	_spawn_physical_chunks(energy)
	_spawn_hazard(energy, attack_kind)
	solidity_changed.emit(false)
	queue_redraw()

func is_movable() -> bool:
	return prop_kind in MOVABLE_KINDS

func is_displaced() -> bool:
	return displaced

func _launch_movable(direction: Vector2, energy: float, attack_kind: String) -> void:
	var impulse_scale := float({"projectile": 1.0, "shotgun": 1.35, "bat": 1.18, "door": 1.12, "thrown": 0.9, "corpse": 0.82, "generic": 0.75}.get(attack_kind, 0.88))
	var mass_scale := float({"table": 0.48, "vending": 0.35, "slot_machine": 0.42, "crate": 0.78, "plant": 1.0, "tv": 0.94, "speaker": 0.88}.get(prop_kind, 0.75))
	var launch_speed := clampf((24.0 + energy * 38.0) * impulse_scale * mass_scale, 14.0, 118.0)
	velocity = (velocity + direction.normalized() * launch_speed).limit_length(125.0)
	spin_velocity = clampf(spin_velocity + randf_range(-4.5, 4.5) + direction.y * 2.0, -9.0, 9.0)
	physics_active = true
	set_physics_process(true)
	_mark_displaced()

func receive_actor_push(intended_velocity: Vector2, _contact_position: Vector2) -> void:
	if not is_movable() or is_instance_valid(dragging_actor) or intended_velocity.length() < 24.0: return
	velocity = (velocity + intended_velocity * 0.20).limit_length(34.0)
	spin_velocity = clampf(spin_velocity + intended_velocity.y * 0.012, -2.5, 2.5)
	physics_active = true
	set_physics_process(true)

func _mark_displaced() -> void:
	if displaced: return
	displaced = true
	add_to_group("displaced_prop")
	add_to_group("resettable_furniture")
	CleanupRegistry.register_target(self)
	if is_instance_valid(restoration_anchor): restoration_anchor.mark_needed()
	else: call_deferred("_mark_anchor_needed")
	solidity_changed.emit(false)
	if not displacement_reported:
		displacement_reported = true
		Events.prop_destroyed.emit(global_position, prop_kind)

func _mark_anchor_needed() -> void:
	if is_instance_valid(restoration_anchor): restoration_anchor.mark_needed()

func _physics_process(delta: float) -> void:
	if is_instance_valid(dragging_actor):
		var drag_direction := Vector2.RIGHT.rotated(dragging_actor.rotation)
		var target := dragging_actor.global_position - drag_direction * 13.0
		velocity = ((target - global_position) * 9.0).limit_length(84.0)
		move_and_slide()
		simulated_rotation = lerp_angle(simulated_rotation, drag_direction.angle(), 1.0 - exp(-6.0 * delta))
		rotation = snappedf(simulated_rotation, PI / 8.0)
		var object_at_slot := global_position.distance_to(home_global_position) <= snap_radius
		var actor_guiding_slot := dragging_actor.global_position.distance_to(home_global_position) <= 8.0 and global_position.distance_to(home_global_position) <= 24.0
		if cleanup_ready and (object_at_slot or actor_guiding_slot): _snap_home()
		return
	if not physics_active:
		set_physics_process(false)
		return
	var impact_speed := velocity.length()
	var collision := move_and_collide(velocity * delta)
	if collision != null:
		var collider := collision.get_collider()
		var normal := collision.get_normal()
		if impact_speed >= 42.0 and collider is Node:
			if collider.is_in_group("enemy") and collider.has_method("take_door_hit"):
				collider.take_door_hit(velocity.normalized(), "knockdown")
			elif collider.is_in_group("destructible_prop") and collider != self and collider.has_method("receive_thrown_impact"):
				collider.receive_thrown_impact(velocity.normalized(), clampf(impact_speed / 75.0, 0.45, 1.35))
			Events.publish_combat_noise(global_position, clampf(impact_speed * 1.1, 34.0, 92.0), "%s_prop_slide" % prop_kind)
		velocity = velocity.bounce(normal) * float(material_profile.get("bounce", 0.18))
		spin_velocity *= -0.42
	velocity = velocity.move_toward(Vector2.ZERO, 78.0 * delta)
	simulated_rotation += spin_velocity * delta
	rotation = snappedf(simulated_rotation, PI / 8.0)
	spin_velocity = move_toward(spin_velocity, 0.0, 5.5 * delta)
	if global_position.distance_to(home_global_position) > 4.0: _mark_displaced()
	if velocity.length() <= 1.5 and absf(spin_velocity) <= 0.25:
		velocity = Vector2.ZERO
		spin_velocity = 0.0
		physics_active = false
		if not displaced:
			global_position = home_global_position
			rotation = home_rotation
			simulated_rotation = home_rotation
		set_physics_process(false)

func enter_cleanup_restore_state() -> void:
	cleanup_ready = true
	velocity = Vector2.ZERO
	spin_velocity = 0.0
	physics_active = false
	if is_instance_valid(restoration_anchor): restoration_anchor.set_cleanup_active(true)
	if is_instance_valid(dragging_actor): set_physics_process(true)

func begin_drag(actor: Node2D) -> bool:
	if not cleanup_ready or not displaced or not is_instance_valid(actor): return false
	if is_instance_valid(dragging_actor) and dragging_actor != actor: return false
	dragging_actor = actor
	velocity = Vector2.ZERO
	set_physics_process(true)
	return true

func end_drag(actor: Node2D) -> void:
	if dragging_actor != actor: return
	dragging_actor = null
	velocity = Vector2.ZERO
	set_physics_process(physics_active)

func is_being_dragged() -> bool:
	return is_instance_valid(dragging_actor)

func get_home_position() -> Vector2:
	return home_global_position

func get_restoration_anchor() -> Node2D:
	return restoration_anchor

func _snap_home() -> void:
	var actor := dragging_actor
	dragging_actor = null
	global_position = home_global_position
	rotation = home_rotation
	simulated_rotation = home_rotation
	velocity = Vector2.ZERO
	spin_velocity = 0.0
	physics_active = false
	displaced = false
	state = PropState.RESTORED
	hp = 2
	structural_stage = 0
	impact_point = Vector2.ZERO
	_restore_collision_shape()
	remove_from_group("displaced_prop")
	remove_from_group("resettable_furniture")
	CleanupRegistry.unregister_target(self)
	if is_instance_valid(restoration_anchor): restoration_anchor.mark_restored()
	solidity_changed.emit(true)
	if is_instance_valid(active_hazard): active_hazard.set_source_active(false)
	if is_instance_valid(actor) and actor.has_method("clear_dragged_restoration_prop"):
		actor.clear_dragged_restoration_prop(self)
	Events.prop_restored.emit(global_position, prop_kind)
	queue_redraw()
	set_physics_process(false)

func _restore_collision_shape() -> void:
	if not is_instance_valid(_collision): return
	var shape := RectangleShape2D.new()
	shape.size = _get_size() - Vector2(2, 2)
	_collision.shape = shape
	_collision.set_deferred("disabled", false)

func interact() -> bool:
	if displaced: return false
	if state != PropState.DESTROYED: return false
	state = PropState.RESTORED
	hp = 2
	structural_stage = 0
	rotation = 0.0
	if is_instance_valid(_collision): _collision.set_deferred("disabled", false)
	solidity_changed.emit(true)
	remove_from_group("resettable_furniture")
	if is_instance_valid(active_hazard): active_hazard.set_source_active(false)
	Events.prop_restored.emit(global_position, prop_kind)
	queue_redraw()
	return true

func _spawn_burst(intensity: float) -> void:
	var burst := MATERIAL_BURST.new() as MaterialBurst
	var parent := get_tree().current_scene if get_tree().current_scene != null else get_parent()
	if not RuntimeBudget.try_add("transient_fx", burst, parent): return
	burst.global_position = global_position + impact_point.rotated(global_rotation)
	burst.setup(last_impact_direction, material_profile, clampf(intensity, 0.55, 1.5))

func _spawn_physical_chunks(intensity: float) -> void:
	var parent := get_tree().current_scene if get_tree().current_scene != null else get_parent()
	var chunk_count := clampi(int(material_profile.get("chunks", 2)), 2, 4)
	for index in chunk_count:
		var chunk := PHYSICAL_DEBRIS.new() as PhysicalDebris
		if not RuntimeBudget.try_add("debris", chunk, parent): continue
		chunk.global_position = global_position + last_impact_direction * float(index)
		chunk.setup(str(material_profile.material), material_profile, last_impact_direction, clampf(intensity, 0.65, 1.8), index)

func _spawn_hazard(intensity: float, _attack_kind: String) -> void:
	var hazard_kind := str(material_profile.get("hazard", "none"))
	if hazard_kind == "none": return
	active_hazard = ENVIRONMENT_HAZARD.new() as EnvironmentHazard
	var parent := get_tree().current_scene if get_tree().current_scene != null else get_parent()
	if not RuntimeBudget.try_add("hazard", active_hazard, parent):
		active_hazard = null
		return
	active_hazard.global_position = global_position
	active_hazard.setup(hazard_kind, clampf(intensity, 0.7, 1.6))
	Events.hazard_spawned.emit(global_position, hazard_kind)

func get_interaction_prompt() -> String:
	if displaced: return "[ E ] DRAG %s TO OUTLINE" % prop_kind.to_upper().replace("_", " ")
	return "[ E ] RESTORE %s" % prop_kind.to_upper().replace("_", " ") if state == PropState.DESTROYED else ""

func get_cleanup_type() -> String: return "furniture"
func get_cleanup_cost() -> int: return 8
func get_cleanup_progress() -> float: return 0.0 if displaced else 1.0
func clean_step() -> void: return

func _get_size() -> Vector2:
	if prop_kind in ["sofa", "bed", "table", "shelf", "console", "conveyor", "bar", "counter", "freezer", "evidence_cabinet"]: return Vector2(14, 8)
	return Vector2(8, 8)

func _draw() -> void:
	var size := _get_size()
	var half := size * 0.5
	var outline := Color("17131b")
	if state != PropState.DESTROYED:
		PIXELS.stipple_rect(self, Rect2(-half + Vector2(2, 2), size), Color(0.03, 0.02, 0.04, 0.46), 2, 3)
	if state == PropState.DESTROYED:
		_draw_debris(outline)
		return
	var base := accent.darkened(0.2 if state in [PropState.INTACT, PropState.RESTORED] else 0.42)
	match prop_kind:
		"sofa":
			_prop_panel(Rect2(-half, size), base, &"fabric", 1)
			PIXELS.line(self, Vector2(0, -3), Vector2(0, 3), outline)
		"bed":
			_prop_panel(Rect2(-half, size), Color("c98782"), &"fabric", 2)
			PIXELS.material_rect(self, Rect2(-half + Vector2(1, 1), Vector2(4, 6)), Color("ead8c5"), Color("fff2db"), Color("b99b88"), 2, &"fabric")
		"table":
			_prop_panel(Rect2(-half, size), base, &"wood", 3)
			PIXELS.line(self, Vector2(-4, -2), Vector2(4, -2), accent.lightened(0.2))
		"tv":
			_prop_panel(Rect2(-half, size), Color("29313b"), &"metal", 4)
			PIXELS.material_rect(self, Rect2(-half + Vector2(2, 2), size - Vector2(4, 4)), Color("43cbd1") if state in [PropState.INTACT, PropState.RESTORED] else Color("312b35"), Color("b9ffff"), Color("226b78"), 4, &"glass")
		"vending":
			_prop_panel(Rect2(-half, size), base, &"metal", 5)
			for point in [Vector2(-2,-2), Vector2(0,-2), Vector2(1,-1)]: PIXELS.pixel(self, point, Color("ff3d99"))
		"speaker":
			_prop_panel(Rect2(-half, size), Color("302a38"), &"fabric", 6)
			PIXELS.material_circle(self, Vector2(0, 1), 2, accent.darkened(0.15), accent.lightened(0.25), outline, 6)
			PIXELS.pixel(self, Vector2(0, -2), Color("8ae8eb"))
		"bar", "counter":
			_prop_panel(Rect2(-half, size), base, &"wood", 7)
			PIXELS.line(self, Vector2(-5,-2), Vector2(5,-2), accent.lightened(0.25))
		"crate":
			_prop_panel(Rect2(-half, size), Color("8f572f"), &"wood", 8)
			PIXELS.line(self, Vector2(-3,-3), Vector2(3,3), Color("4a2b21")); PIXELS.line(self, Vector2(3,-3), Vector2(-3,3), Color("4a2b21"))
		"shelf", "evidence_cabinet", "freezer":
			_prop_panel(Rect2(-half, size), base, &"metal", 9)
			PIXELS.line(self, Vector2(-5,0), Vector2(5,0), outline)
			for x in [-4.0, 0.0, 4.0]: PIXELS.pixel(self, Vector2(x,-2), accent.lightened(0.2))
		"slot_machine":
			_prop_panel(Rect2(-half, size), Color("5d234e"), &"metal", 10)
			for x in range(-2, 2): PIXELS.pixel(self, Vector2(x,-2 + posmod(x,2)), Color("ffd34e"))
			PIXELS.pixel(self, Vector2(2,2), accent)
		"conveyor", "console":
			_prop_panel(Rect2(-half, size), Color("4e5860"), &"metal", 11)
			for x in range(-5, 6, 3): PIXELS.pixel(self, Vector2(x,-1), accent)
		"sink", "toilet":
			_prop_panel(Rect2(-half, size), Color("d6e3dc"), &"glass", 12)
			PIXELS.material_rect(self, Rect2(-2, -2, 4, 3), Color("548b94"), Color("b9ffff"), Color("315c69"), 12, &"glass")
		"plant":
			_prop_panel(Rect2(-3, 1, 6, 4), Color("553126"), &"wood", 13)
			PIXELS.line(self, Vector2(0, 1), Vector2(0, -4), Color("39784d"))
			for point in [Vector2(-3,-4),Vector2(-2,-3),Vector2(-1,-4),Vector2(1,-3),Vector2(2,-2),Vector2(3,-3),Vector2(0,-5)]: PIXELS.pixel(self, point, Color("54a85f") if int(point.x + point.y) % 2 == 0 else Color("39784d"))
		_:
			_prop_panel(Rect2(-half, size), base, &"grain", 14)
	if state == PropState.DAMAGED:
		var crack_color: Color = material_profile.get("secondary", Color("f1d4be"))
		PIXELS.damage_crack(self, impact_point, crack_color, outline)

func _prop_panel(area: Rect2, color: Color, pattern: StringName, seed: int) -> void:
	PIXELS.material_panel(self, area, Color("17131b"), color, color.lightened(0.18), color.darkened(0.22), seed, pattern)

func _draw_debris(outline: Color) -> void:
	var direction := last_impact_direction.normalized()
	for index in range(5):
		var side := -1.0 if index % 2 == 0 else 1.0
		var offset := (direction * float(index - 1) * 2.2 + direction.orthogonal() * side * float(1 + index % 3)).round()
		var debris_color: Color = material_profile.get("primary", accent)
		PIXELS.pixel(self, offset, outline)
		PIXELS.pixel(self, offset + direction.round(), debris_color.darkened(0.2))
		if index < 2: PIXELS.pixel(self, offset + direction.orthogonal().round(), debris_color.lightened(0.12))
