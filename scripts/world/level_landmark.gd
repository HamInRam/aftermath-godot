class_name LevelLandmark
extends StaticBody2D

const MATERIAL_BURST := preload("res://scripts/effects/material_burst.gd")
const PHYSICAL_DEBRIS := preload("res://scripts/props/physical_debris.gd")
const ENVIRONMENT_HAZARD := preload("res://scripts/effects/environment_hazard.gd")
const PIXELS := preload("res://utility/pixel_art_painter.gd")

signal solidity_changed(solid: bool)

var landmark_kind := ""
var accent := Color("ff3f79")
var hp := 3
var damaged := false
var destroyed := false
var _collision: CollisionShape2D
var impact_direction := Vector2.RIGHT
var active_hazard: EnvironmentHazard

func setup(kind: String, tint: Color) -> void:
	landmark_kind = kind
	accent = tint
	collision_layer = 4
	collision_mask = 0
	add_to_group("destructible_prop")
	_collision = CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(14, 8)
	_collision.shape = shape
	add_child(_collision)
	z_index = 2
	queue_redraw()

func receive_projectile_impact(projectile_velocity: Vector2, hit_position: Vector2) -> void:
	receive_projectile_impact_context(projectile_velocity, hit_position, "pistol", 1)

func receive_projectile_impact_context(projectile_velocity: Vector2, hit_position: Vector2, weapon_id: String, damage: int) -> void:
	impact_direction = projectile_velocity.normalized()
	var amount := 2 if weapon_id == "shotgun" or damage >= 2 else 1
	take_damage(amount, hit_position - impact_direction * 2.0)

func receive_melee_impact(direction: Vector2, melee_type: String) -> void:
	impact_direction = direction.normalized()
	take_damage(2 if melee_type == "bat" else 1, global_position - direction)

func receive_thrown_impact(direction: Vector2, energy := 1.0) -> void:
	impact_direction = direction.normalized()
	take_damage(2 if energy > 1.2 else 1, global_position - direction)

func receive_door_impact(direction: Vector2, energy := 1.0) -> void:
	impact_direction = direction.normalized()
	take_damage(2 if energy > 1.15 else 1, global_position - direction)

func receive_corpse_impact(direction: Vector2, energy := 1.0) -> void:
	impact_direction = direction.normalized()
	take_damage(2 if energy > 1.0 else 1, global_position - direction)

func take_damage(amount: int, _source_position := Vector2.ZERO) -> void:
	if destroyed: return
	hp -= maxi(1, amount)
	damaged = true
	_spawn_impact_burst(0.8)
	Events.prop_impacted.emit(global_position, _setpiece_material(), float(amount), 1 if hp > 0 else 2)
	if hp <= 0:
		destroyed = true
		_collision.set_deferred("disabled", true)
		add_to_group("resettable_furniture")
		Events.prop_destroyed.emit(global_position, landmark_kind)
		Events.publish_combat_noise(global_position, 125.0, "landmark_break")
		_spawn_chain_reaction()
		solidity_changed.emit(false)
	queue_redraw()

func interact() -> bool:
	if not destroyed: return false
	destroyed = false
	damaged = false
	hp = 3
	_collision.set_deferred("disabled", false)
	solidity_changed.emit(true)
	remove_from_group("resettable_furniture")
	if is_instance_valid(active_hazard): active_hazard.set_source_active(false)
	Events.prop_restored.emit(global_position, landmark_kind)
	queue_redraw()
	return true

func _setpiece_material() -> String:
	if landmark_kind in ["city_window"]: return "glass"
	if landmark_kind in ["diner_counter", "evidence_wall"]: return "wood"
	return "metal"

func _setpiece_hazard() -> String:
	return {
		"dj_booth": "electric", "diner_counter": "spill", "training_target": "smoke",
		"cargo_crane": "oil", "motel_sign": "electric", "city_window": "glass",
		"freezer_fans": "smoke", "roulette": "spill", "evidence_wall": "smoke",
		"conveyor": "oil", "broadcast_console": "electric", "broken_dj": "electric",
	}.get(landmark_kind, "smoke")

func _spawn_impact_burst(intensity: float) -> void:
	var profile: Dictionary = DestructionMaterial.PROFILES.get(_setpiece_material(), DestructionMaterial.PROFILES.metal).duplicate(true)
	var burst := MATERIAL_BURST.new() as MaterialBurst
	var parent := get_tree().current_scene if get_tree().current_scene != null else get_parent()
	if not RuntimeBudget.try_add("transient_fx", burst, parent): return
	burst.global_position = global_position
	burst.setup(impact_direction, profile, intensity)

func _spawn_chain_reaction() -> void:
	var material := _setpiece_material()
	var profile: Dictionary = DestructionMaterial.PROFILES.get(material, DestructionMaterial.PROFILES.metal).duplicate(true)
	var parent := get_tree().current_scene if get_tree().current_scene != null else get_parent()
	_spawn_impact_burst(1.6)
	for index in 4:
		var chunk := PHYSICAL_DEBRIS.new() as PhysicalDebris
		if not RuntimeBudget.try_add("debris", chunk, parent): continue
		chunk.global_position = global_position + impact_direction.orthogonal() * float(index - 2) * 3.0
		chunk.setup(material, profile, impact_direction, 1.5, index)
	var hazard_kind := _setpiece_hazard()
	active_hazard = ENVIRONMENT_HAZARD.new() as EnvironmentHazard
	if RuntimeBudget.try_add("hazard", active_hazard, parent):
		active_hazard.global_position = global_position + impact_direction * 8.0
		active_hazard.setup(hazard_kind, 1.55)
	else:
		active_hazard = null
	Events.setpiece_triggered.emit(global_position, landmark_kind, hazard_kind)

func get_interaction_prompt() -> String:
	return "[ E ] REASSEMBLE %s" % landmark_kind.to_upper().replace("_", " ") if destroyed else ""

func _draw() -> void:
	var ink := Color("17141d")
	var metal := Color("6f7781")
	if destroyed:
		var part_index := 0
		for part: Rect2 in [Rect2(-18,-4,10,6), Rect2(-5,3,8,5), Rect2(7,-6,12,7), Rect2(14,5,5,4)]:
			_landmark_panel(part, accent.darkened(0.5), &"metal", 40 + part_index)
			part_index += 1
		return
	match landmark_kind:
		"dj_booth":
			_landmark_panel(Rect2(-22, -9, 44, 18), Color("292431"), &"metal", 41)
			_landmark_disc(Vector2(-11, 0), 6, Color("4b4057"), 42); _landmark_disc(Vector2(11, 0), 6, Color("4b4057"), 43)
			_landmark_panel(Rect2(-4, -4, 8, 8), accent.darkened(0.35), &"metal", 44); PIXELS.line(self, Vector2(-18, 7), Vector2(18, 7), accent)
		"diner_counter":
			_landmark_panel(Rect2(-24, -6, 48, 12), Color("a94f31"), &"wood", 45)
			PIXELS.line(self, Vector2(-20, -2), Vector2(20, -2), Color("ead3a5"))
			for x in range(-16, 17, 8): _landmark_disc(Vector2(x, 8), 2, accent, x + 46)
		"training_target":
			_landmark_panel(Rect2(-4, -18, 8, 36), Color("52484a"), &"wood", 47); _landmark_disc(Vector2(0, -5), 9, Color("d5d1bf"), 48)
			_landmark_disc(Vector2(0, -5), 5, accent, 49); PIXELS.material_circle(self, Vector2(0, -5), 2, ink, ink.lightened(0.08), ink.darkened(0.08), 50)
		"cargo_crane":
			_landmark_panel(Rect2(-18, -5, 36, 10), Color("b7652b"), &"metal", 51)
			PIXELS.line(self, Vector2(10, -2), Vector2(18, 12), metal); PIXELS.line(self, Vector2(18, 12), Vector2(18, 20), accent)
		"motel_sign":
			_landmark_panel(Rect2(-19, -8, 38, 16), accent.darkened(0.45), &"metal", 52)
			for x in range(-14, 15, 6): PIXELS.pixel(self, Vector2(x, 5), accent)
			PIXELS.text(self, "MOTEL", Vector2(-10, -3), Color.WHITE)
		"city_window":
			_landmark_panel(Rect2(-22, -10, 44, 20), Color("253a46"), &"glass", 53)
			for x in range(-19, 20, 8):
				for y in range(-7, 8, 6): PIXELS.material_rect(self, Rect2(x, y, 3, 3), accent, Color("b9ffff"), Color("277899"), x + y, &"glass")
		"freezer_fans":
			for x in [-12.0, 12.0]:
				_landmark_disc(Vector2(x, 0), 9, Color("9ccbd0"), 54 + int(x))
				for angle in [0.0, PI * 0.5, PI, PI * 1.5]: PIXELS.line(self, Vector2(x, 0), Vector2(x, 0) + Vector2.RIGHT.rotated(angle) * 6, metal)
		"roulette":
			_landmark_disc(Vector2.ZERO, 17, Color("b51d39"), 55)
			for angle in range(0, 360, 30): PIXELS.line(self, Vector2.ZERO, Vector2.RIGHT.rotated(deg_to_rad(angle)) * 14, Color("f5d27a"))
			_landmark_disc(Vector2.ZERO, 4, accent, 56)
		"evidence_wall":
			_landmark_panel(Rect2(-22, -12, 44, 24), Color("493629"), &"wood", 57)
			var points := PackedVector2Array([Vector2(-14,-6), Vector2(2,-8), Vector2(13,-2), Vector2(-6,6), Vector2(10,7)])
			for p: Vector2 in points: PIXELS.material_panel(self, Rect2(p - Vector2(3, 3), Vector2(7, 6)), ink, Color("ddd3b7"), Color("fff4dc"), Color("aa9d87"), int(p.x + p.y), &"grain")
			PIXELS.polyline(self, points, accent)
		"conveyor":
			_landmark_panel(Rect2(-24, -7, 48, 14), Color("75272b"), &"metal", 58)
			for x in range(-18, 19, 7): _landmark_disc(Vector2(x, 0), 2, metal, x + 59)
		"broadcast_console":
			_landmark_panel(Rect2(-24, -11, 48, 22), Color("24252e"), &"metal", 60)
			for x in range(-19, 20, 10):
				PIXELS.material_panel(self, Rect2(x, -7, 7, 6), ink, accent.darkened(0.45), accent, accent.darkened(0.7), x + 61, &"metal"); PIXELS.pixel(self, Vector2(x + 3, 5), accent)
		"broken_dj":
			_landmark_panel(Rect2(-22, -10, 44, 20), Color("292431"), &"metal", 62)
			_landmark_disc(Vector2(-11, 0), 7, Color("4b4057"), 63); _landmark_disc(Vector2(11, 0), 7, Color("4b4057"), 64)
			PIXELS.line(self, Vector2(-4,-8), Vector2(4,8), accent); PIXELS.line(self, Vector2(4,-8), Vector2(-4,8), accent)
	if damaged:
		PIXELS.line(self, Vector2(-14, -7), Vector2(-5, 1), Color("f1d2bc"))
		PIXELS.line(self, Vector2(-5, 1), Vector2(3, -3), ink)
		PIXELS.line(self, Vector2(3, -3), Vector2(13, 7), Color("f1d2bc"))

func _landmark_panel(area: Rect2, color: Color, pattern: StringName, seed: int) -> void:
	PIXELS.material_panel(self, area, Color("17141d"), color, color.lightened(0.16), color.darkened(0.22), seed, pattern)

func _landmark_disc(center: Vector2, radius: int, color: Color, seed: int) -> void:
	PIXELS.material_circle(self, center, radius, Color("17141d"), Color("17141d"), Color("0b0910"), seed)
	if radius > 1: PIXELS.material_circle(self, center, radius - 1, color, color.lightened(0.18), color.darkened(0.24), seed + 1)
