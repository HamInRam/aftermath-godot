class_name DestructibleProp
extends StaticBody2D

const MATERIAL_BURST := preload("res://scripts/effects/material_burst.gd")
const PHYSICAL_DEBRIS := preload("res://scripts/props/physical_debris.gd")
const ENVIRONMENT_HAZARD := preload("res://scripts/effects/environment_hazard.gd")
const PIXELS := preload("res://utility/pixel_art_painter.gd")

signal solidity_changed(solid: bool)

enum PropState { INTACT, DAMAGED, DESTROYED, RESTORED }

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

func setup(kind: String, tint := Color("b25a38")) -> void:
	prop_kind = kind
	accent = tint
	material_profile = DestructionMaterial.for_kind(kind)
	hp = 2
	structural_stage = 0
	collision_layer = 4
	collision_mask = 0
	add_to_group("destructible_prop")
	_collision = CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = _get_size() - Vector2(2, 2)
	_collision.shape = shape
	add_child(_collision)
	z_index = 3
	queue_redraw()

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
	hp -= structural_damage
	structural_stage = mini(2, structural_stage + structural_damage)
	Events.prop_impacted.emit(global_position, str(material_profile.get("material", "wood")), effective_energy, structural_stage)
	_spawn_burst(effective_energy * 0.55)
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

func interact() -> bool:
	if state != PropState.DESTROYED: return false
	state = PropState.RESTORED
	hp = 2
	structural_stage = 0
	rotation = 0.0
	if is_instance_valid(_collision): _collision.set_deferred("disabled", false)
	solidity_changed.emit(true)
	remove_from_group("resettable_furniture")
	if is_instance_valid(active_hazard): active_hazard.set_source_active(false)
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
	# Ballistic rupture of volatile containers can turn a manageable spill into
	# a room-scale fire. Melee still lets careful players create only a spill.
	if prop_kind in ["fuel_drum", "alcohol_shelf"] and _attack_kind in ["projectile", "shotgun"] and intensity >= 1.0:
		call_deferred("_ignite_volatile_spill", clampf(intensity, 0.8, 1.5))

func _ignite_volatile_spill(intensity: float) -> void:
	var fire_hazard := ENVIRONMENT_HAZARD.new() as EnvironmentHazard
	var parent := get_tree().current_scene if get_tree().current_scene != null else get_parent()
	if not RuntimeBudget.try_add("hazard", fire_hazard, parent): return
	fire_hazard.global_position = global_position + last_impact_direction * 3.0
	fire_hazard.setup("fire", intensity)
	# The ruptured liquid is the fuel source; this controller only supplies the
	# initial ignition and must not create fire forever after the fuel is gone.
	fire_hazard.set_source_active(false)
	Events.hazard_spawned.emit(fire_hazard.global_position, "fire")

func get_interaction_prompt() -> String:
	return "[ E ] RESTORE %s" % prop_kind.to_upper().replace("_", " ") if state == PropState.DESTROYED else ""

func _get_size() -> Vector2:
	if prop_kind in ["sofa", "bed", "table", "shelf", "console", "conveyor", "bar", "counter", "freezer", "evidence_cabinet", "alcohol_shelf", "glass_rack", "paper_archive"]: return Vector2(14, 8)
	if prop_kind in ["grease_vat", "chemical_tank"]: return Vector2(10, 9)
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
	var base := accent.darkened(0.2 if state == PropState.INTACT else 0.42)
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
			PIXELS.material_rect(self, Rect2(-half + Vector2(2, 2), size - Vector2(4, 4)), Color("43cbd1") if state == PropState.INTACT else Color("312b35"), Color("b9ffff"), Color("226b78"), 4, &"glass")
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
		"fuel_drum", "grease_vat", "chemical_tank":
			var tank_color := Color("d98534") if prop_kind == "fuel_drum" else (Color("66552e") if prop_kind == "grease_vat" else Color("58b56b"))
			_prop_panel(Rect2(-half, size), tank_color, &"metal", 15)
			PIXELS.line(self, Vector2(-half.x + 1, -1), Vector2(half.x - 1, -1), outline)
			PIXELS.pixel(self, Vector2(0, -3), Color("fff08a") if prop_kind == "fuel_drum" else accent.lightened(0.3))
		"sprinkler", "coolant_pipe", "gas_line":
			var pipe_color := Color("68dceb") if prop_kind == "coolant_pipe" else (Color("ffb34b") if prop_kind == "gas_line" else Color("d7e2e5"))
			PIXELS.line(self, Vector2(-4, 0), Vector2(4, 0), outline, 4)
			PIXELS.line(self, Vector2(-4, 0), Vector2(4, 0), pipe_color, 2)
			PIXELS.material_circle(self, Vector2(0, 0), 2, outline, pipe_color.lightened(0.2), pipe_color.darkened(0.25), 16)
		"breaker", "extinguisher":
			_prop_panel(Rect2(-half, size), Color("4d5661") if prop_kind == "breaker" else Color("d7443f"), &"metal", 17)
			if prop_kind == "breaker":
				for point in [Vector2(-2,-2), Vector2(1,-2), Vector2(-2,1), Vector2(1,1)]: PIXELS.pixel(self, point, Color("ffe06b"))
			else:
				PIXELS.line(self, Vector2(0,-2), Vector2(0,2), Color("fff3df"), 2)
		"alcohol_shelf", "glass_rack":
			_prop_panel(Rect2(-half, size), Color("563249"), &"wood", 18)
			for x in range(-5, 6, 3):
				var bottle_color := Color("ff4e8a") if prop_kind == "alcohol_shelf" else Color("b9ffff")
				PIXELS.line(self, Vector2(x, -2), Vector2(x, 2), bottle_color, 2)
		"paper_archive":
			_prop_panel(Rect2(-half, size), Color("66503b"), &"wood", 19)
			for x in range(-5, 6, 3): PIXELS.material_rect(self, Rect2(x, -2, 2, 4), Color("d8c69f"), Color("fff0ca"), Color("9f8969"), x + 20, &"grain")
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
