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
var accent := Color("777777")
var _collision: CollisionShape2D
var material_profile: Dictionary = {}
var structural_stage := 0
var impact_point := Vector2.ZERO
var active_hazard: EnvironmentHazard
var home_global_position := Vector2.ZERO
var home_rotation := 0.0
var simulated_rotation := 0.0
var spin_velocity := 0.0
# `displaced` is intentionally reserved for destructive/weapon launch. Ordinary
# actor contact is tracked separately because it must not create restoration work.
var displaced := false
var contact_shifted := false
var home_navigation_released := false
var displacement_reported := false
var cleanup_ready := false
var dragging_actor: Node2D
var restoration_anchor: Node2D
var snap_radius := 11.0
var physics_active := false
var restoration_locked := false
var erosion: PixelErosionMask
var erosion_shapes: Array[CollisionShape2D] = []
var erosion_pending := false

func setup(kind: String, tint := Color("777777")) -> void:
	prop_kind = kind
	accent = Color(tint.v, tint.v, tint.v)
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
	if state in [PropState.DESTROYED, PropState.RESTORED]: return
	if erosion == null:
		erosion = PixelErosionMask.new()
		erosion.configure(Rect2i(Vector2i(-_get_size() * 0.5), Vector2i(_get_size())))
		set_meta("erosion_mask", erosion)
	last_impact_direction = projectile_velocity.normalized()
	impact_point = to_local(hit_position)
	var radius := clampf(1.7 + sqrt(float(maxi(1, damage))) * 0.25 / maxf(0.5, float(material_profile.resistance)), 2.2, 4.4)
	var removed := erosion.chip(impact_point, last_impact_direction.rotated(-global_rotation), radius)
	if removed == 0: return
	state = PropState.DAMAGED
	_spawn_burst(clampf(float(removed) / 12.0, 0.8, 1.6))
	MicroDebrisField.for_scene(self).play_erosion_tick(hit_position)
	if is_movable(): _launch_movable(last_impact_direction, 0.65, "projectile")
	if not erosion_pending:
		erosion_pending = true
		call_deferred("_rebuild_eroded_collision")
	queue_redraw()

func _rebuild_eroded_collision() -> void:
	erosion_pending = false
	if erosion == null or state in [PropState.DESTROYED, PropState.RESTORED]: return
	_collision.disabled = true
	erosion.rebuild_collision(self, erosion_shapes)
	if erosion.remaining() == 0:
		velocity = Vector2.ZERO
		physics_active = false
		set_physics_process(false)
		_destroy(1.0, "projectile")

func _legacy_projectile_impact(projectile_velocity: Vector2, hit_position: Vector2, weapon_id: String, damage: int) -> void:
	# HP damage uses a 100-point character-health scale, not physical joules.
	# Multiplying by 30-100 damage made every pistol pellet act like an explosive.
	# Normalize the wound value and retain weapon speed/material differences.
	var damage_energy := clampf(sqrt(float(maxi(1, damage)) / 35.0), 0.65, 1.6)
	var speed_energy := clampf(projectile_velocity.length() / 650.0, 0.45, 1.8) * damage_energy
	var attack_kind := "shotgun" if AttackCatalog.get_gun_data(weapon_id).weapon_class == "shotgun" else "projectile"
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
	for shape in erosion_shapes: shape.set_deferred("disabled", true)
	if is_instance_valid(_collision): _collision.set_deferred("disabled", true)
	if cleanup_ready: add_to_group("resettable_furniture")
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
	# Combat contact may shove loose dressing. Cleanup is a strict physics
	# boundary: untouched scenery and anything already restored are kinematic
	# fixtures, not objects the player can accidentally disturb again.
	if cleanup_ready or restoration_locked or state == PropState.RESTORED: return
	if not is_movable() or is_instance_valid(dragging_actor) or intended_velocity.length() < 24.0: return
	velocity = (velocity + intended_velocity * 0.20).limit_length(34.0)
	spin_velocity = clampf(spin_velocity + intended_velocity.y * 0.012, -2.5, 2.5)
	physics_active = true
	set_physics_process(true)

func _mark_displaced() -> void:
	if displaced: return
	displaced = true
	add_to_group("displaced_prop")
	if cleanup_ready:
		add_to_group("resettable_furniture")
		CleanupRegistry.register_target(self)
		if is_instance_valid(restoration_anchor): restoration_anchor.mark_needed()
	_release_home_navigation()
	if not displacement_reported:
		displacement_reported = true
		Events.prop_destroyed.emit(global_position, prop_kind)

func _mark_contact_shifted() -> void:
	if contact_shifted or displaced: return
	contact_shifted = true
	_release_home_navigation()

func _release_home_navigation() -> void:
	if home_navigation_released: return
	home_navigation_released = true
	solidity_changed.emit(false)

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
	if not displaced and global_position.distance_to(home_global_position) > 1.0: _mark_contact_shifted()
	if velocity.length() <= 1.5 and absf(spin_velocity) <= 0.25:
		velocity = Vector2.ZERO
		spin_velocity = 0.0
		physics_active = false
		if not displaced and not contact_shifted:
			global_position = home_global_position
			rotation = home_rotation
			simulated_rotation = home_rotation
		set_physics_process(false)

func enter_cleanup_restore_state() -> void:
	cleanup_ready = true
	# Compatibility for archived cleanup scenes. Rogue combat never creates the
	# old restoration ghosts, drag targets, or registry entries in the first place.
	if is_movable(): _create_restoration_anchor()
	if displaced: CleanupRegistry.register_target(self)
	velocity = Vector2.ZERO
	spin_velocity = 0.0
	physics_active = false
	# Untouched props lock to their exact authored transform. Contact-shifted props
	# freeze exactly where combat left them and never become restoration tasks.
	if not displaced:
		restoration_locked = true
		if not contact_shifted:
			global_position = home_global_position
			rotation = home_rotation
			simulated_rotation = home_rotation
	if is_instance_valid(restoration_anchor): restoration_anchor.set_cleanup_active(true)
	set_physics_process(is_instance_valid(dragging_actor))

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
	restoration_locked = true
	displaced = false
	contact_shifted = false
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
	home_navigation_released = false
	if is_instance_valid(active_hazard): active_hazard.set_source_active(false)
	if is_instance_valid(actor) and actor.has_method("clear_dragged_restoration_prop"):
		actor.clear_dragged_restoration_prop(self)
	Events.prop_restored.emit(global_position, prop_kind)
	queue_redraw()
	set_physics_process(false)

func _restore_collision_shape() -> void:
	if erosion != null:
		erosion = null
		remove_meta("erosion_mask")
		for old_shape in erosion_shapes: old_shape.queue_free()
		erosion_shapes.clear()
	if not is_instance_valid(_collision): return
	var shape := RectangleShape2D.new()
	shape.size = _get_size() - Vector2(2, 2)
	_collision.shape = shape
	_collision.set_deferred("disabled", false)

func interact() -> bool:
	if displaced: return false
	if state != PropState.DESTROYED: return false
	state = PropState.RESTORED
	restoration_locked = true
	hp = 2
	structural_stage = 0
	rotation = 0.0
	_restore_collision_shape()
	solidity_changed.emit(true)
	remove_from_group("resettable_furniture")
	if is_instance_valid(active_hazard): active_hazard.set_source_active(false)
	Events.prop_restored.emit(global_position, prop_kind)
	queue_redraw()
	return true

func _spawn_burst(intensity: float) -> void:
	var micro_material := "paper" if prop_kind in ["desk", "office_desk", "paper_stack"] else str(material_profile.get("material", "wood"))
	MicroDebrisField.for_scene(self).emit_impact(global_position + impact_point.rotated(global_rotation), last_impact_direction, micro_material, intensity)
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
	var ink := Color("151515")
	if state == PropState.DESTROYED:
		_draw_debris(ink)
		return
	# One crisp contact shadow, never a dither halo around the silhouette.
	PIXELS.rect(self, Rect2(-half + Vector2(1, 2), size), Color(0.02, 0.02, 0.02, 0.38))
	var base := _prop_body_color()
	match prop_kind:
		"glass_partition":
			PIXELS.rect(self, Rect2(-4,-4,8,8), Color("777777"))
			PIXELS.rect(self, Rect2(-4,-4,8,1), Color("eeeeee"))
			PIXELS.rect(self, Rect2(-4,3,8,1), Color("eeeeee"))
			PIXELS.rect(self, Rect2(-2,-2,1,4), Color("bcbcbc"))
		"paper_stack":
			PIXELS.rect(self, Rect2(-4,-4,8,8), Color("777777"))
			PIXELS.rect(self, Rect2(-3,-4,6,6), Color("eeeeee"))
			PIXELS.rect(self, Rect2(-2,-2,4,1), Color("aaaaaa"))
		"sofa":
			_prop_panel(Rect2(-half, size), base, &"fabric", 1)
			PIXELS.rect(self, Rect2(-6,-3,12,2), Color("a9a9a9"))
			PIXELS.rect(self, Rect2(-6,-1,1,4), Color("bdbdbd"))
			PIXELS.rect(self, Rect2(5,-1,1,4), Color("bdbdbd"))
			PIXELS.line(self, Vector2(0,-1), Vector2(0,2), ink)
		"bed":
			_prop_panel(Rect2(-half, size), base, &"fabric", 2)
			PIXELS.rect(self, Rect2(-6,-3,4,6), Color("e4e4e4"))
			PIXELS.rect(self, Rect2(-1,-3,7,2), Color("a3a3a3"))
			PIXELS.line(self, Vector2(-1,2), Vector2(5,2), Color("888888"))
		"table":
			_prop_panel(Rect2(-half, size), base, &"wood", 3)
			PIXELS.rect(self, Rect2(-5,-2,3,2), Color("d8d8d8"))
			PIXELS.pixel(self, Vector2(3,1), Color("c6c6c6"))
		"tv":
			_prop_panel(Rect2(-half, size), Color("555555"), &"metal", 4)
			PIXELS.rect(self, Rect2(-2,-2,4,3), Color("c5c5c5") if state != PropState.DAMAGED else Color("343434"))
			PIXELS.rect(self, Rect2(-1,-1,2,1), Color("e7e7e7"))
			PIXELS.rect(self, Rect2(-2,3,4,1), ink)
		"vending", "slot_machine":
			_prop_panel(Rect2(-half, size), base, &"metal", 5)
			PIXELS.rect(self, Rect2(-2,-2,3,3), Color("d7d7d7"))
			PIXELS.line(self, Vector2(-2,-1), Vector2(0,-1), Color("5b5b5b"))
			PIXELS.pixel(self, Vector2(2,-2), Color("f0f0f0"))
			PIXELS.rect(self, Rect2(-1,2,3,1), ink)
		"speaker":
			_prop_panel(Rect2(-half, size), Color("393939"), &"metal", 6)
			PIXELS.circle(self, Vector2(0,1), 2, Color("a3a3a3"))
			PIXELS.circle(self, Vector2(0,1), 1, ink)
			PIXELS.pixel(self, Vector2(0,-2), Color("dddddd"))
		"bar", "counter":
			_prop_panel(Rect2(-half, size), base, &"wood", 7)
			PIXELS.rect(self, Rect2(-6,-3,12,2), Color("d6d6d6"))
			PIXELS.line(self, Vector2(-5,1), Vector2(5,1), Color("515151"))
		"crate":
			_prop_panel(Rect2(-half, size), base, &"wood", 8)
			PIXELS.line(self, Vector2(-2,-2), Vector2(2,2), Color("c1c1c1"))
			PIXELS.pixel(self, Vector2(2,-2), Color("333333"))
			PIXELS.pixel(self, Vector2(-2,2), Color("333333"))
		"shelf", "evidence_cabinet", "freezer":
			_prop_panel(Rect2(-half, size), base, &"metal", 9)
			PIXELS.line(self, Vector2(-5,0), Vector2(5,0), ink)
			PIXELS.rect(self, Rect2(-2,-2,4,1), Color("dddddd"))
			PIXELS.rect(self, Rect2(-2,2,4,1), Color("b6b6b6"))
		"conveyor", "console":
			_prop_panel(Rect2(-half, size), base, &"metal", 11)
			if prop_kind == "console":
				PIXELS.rect(self, Rect2(-5,-2,5,3), Color("cacaca"))
				for x in [2,4]: PIXELS.pixel(self, Vector2(x,1), Color("eeeeee"))
			else:
				for x in [-4,0,4]: PIXELS.line(self, Vector2(x,-2), Vector2(x,2), Color("333333"))
		"sink", "toilet":
			_prop_panel(Rect2(-half, size), base, &"ceramic", 12)
			PIXELS.rect(self, Rect2(-2,-1,4,3), Color("737373"))
			PIXELS.rect(self, Rect2(-1,0,2,1), Color("333333"))
			PIXELS.rect(self, Rect2(-1,-3,2,2), Color("f5f5f5"))
		"plant":
			_prop_panel(Rect2(-3,1,6,3), base, &"ceramic", 13)
			PIXELS.line(self, Vector2(0,1), Vector2(0,-4), Color("333333"))
			PIXELS.rect(self, Rect2(-3,-3,3,2), Color("545454"))
			PIXELS.rect(self, Rect2(1,-4,3,3), Color("515151"))
			PIXELS.line(self, Vector2(1,-3), Vector2(3,-3), Color("9d9d9d"))
		_:
			_prop_panel(Rect2(-half, size), base, &"metal", 14)
	if state == PropState.DAMAGED:
		PIXELS.damage_crack(self, impact_point, Color("d3d3d3"), ink)

func _prop_body_color() -> Color:
	var body: Color = material_profile.get("primary", Color("777777"))
	# State changes expose the same material instead of tinting the whole prop.
	return body

func _prop_panel(area: Rect2, color: Color, pattern: StringName, _seed: int) -> void:
	PIXELS.rect(self, area, Color("151515"))
	PIXELS.rect(self, Rect2(area.position + Vector2.ONE, area.size - Vector2(2,2)), color)
	PIXELS.line(self, area.position + Vector2.ONE, Vector2(area.end.x - 2, area.position.y + 1), color.lightened(0.3))
	# Quiet top face, dark underside and one lit edge establish object height
	# without patterned noise or changing its physical footprint.
	PIXELS.line(self, Vector2(area.position.x + 1, area.end.y - 2), area.end - Vector2(2, 2), color.darkened(0.28))
	if pattern == &"wood" and area.size.x > 9:
		PIXELS.line(self, area.position + Vector2(2,4), area.position + Vector2(6,4), color.darkened(0.18))

func _draw_debris(outline: Color) -> void:
	var direction := last_impact_direction.normalized()
	var debris_color := _prop_body_color()
	for index in range(5):
		var side := -1.0 if index % 2 == 0 else 1.0
		var offset := (direction * float(index - 1) * 2.2 + direction.orthogonal() * side * float(1 + index % 3)).round()
		PIXELS.pixel(self, offset, outline)
		PIXELS.pixel(self, offset + direction.round(), debris_color)
		if index < 2: PIXELS.pixel(self, offset + direction.orthogonal().round(), debris_color.lightened(0.3))
