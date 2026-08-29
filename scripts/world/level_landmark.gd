class_name LevelLandmark
extends StaticBody2D

const MATERIAL_BURST := preload("res://scripts/effects/material_burst.gd")
const PHYSICAL_DEBRIS := preload("res://scripts/props/physical_debris.gd")
const ENVIRONMENT_HAZARD := preload("res://scripts/effects/environment_hazard.gd")

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
		for part: Rect2 in [Rect2(-18,-4,10,6), Rect2(-5,3,8,5), Rect2(7,-6,12,7), Rect2(14,5,5,4)]:
			draw_rect(part, ink); draw_rect(Rect2(part.position + Vector2.ONE, part.size - Vector2.ONE), accent.darkened(0.5))
		return
	match landmark_kind:
		"dj_booth":
			draw_rect(Rect2(-22, -9, 44, 18), ink)
			draw_circle(Vector2(-11, 0), 6, Color("4b4057")); draw_circle(Vector2(11, 0), 6, Color("4b4057"))
			draw_rect(Rect2(-4, -4, 8, 8), accent.darkened(0.35)); draw_line(Vector2(-18, 7), Vector2(18, 7), accent, 2)
		"diner_counter":
			draw_rect(Rect2(-24, -6, 48, 12), ink); draw_rect(Rect2(-22, -4, 44, 8), Color("a94f31"))
			draw_line(Vector2(-20, -2), Vector2(20, -2), Color("ead3a5"), 2)
			for x in range(-16, 17, 8): draw_circle(Vector2(x, 8), 3, accent)
		"training_target":
			draw_rect(Rect2(-4, -18, 8, 36), ink); draw_circle(Vector2(0, -5), 9, Color("d5d1bf"))
			draw_circle(Vector2(0, -5), 5, accent); draw_circle(Vector2(0, -5), 2, ink)
		"cargo_crane":
			draw_rect(Rect2(-18, -5, 36, 10), ink); draw_rect(Rect2(-15, -3, 26, 5), Color("b7652b"))
			draw_line(Vector2(10, -2), Vector2(18, 12), metal, 3); draw_line(Vector2(18, 12), Vector2(18, 20), accent, 1)
		"motel_sign":
			draw_rect(Rect2(-19, -8, 38, 16), ink); draw_rect(Rect2(-17, -6, 34, 12), accent.darkened(0.45))
			for x in range(-14, 15, 6): draw_circle(Vector2(x, 0), 1.5, accent)
			draw_string(ThemeDB.fallback_font, Vector2(-13, 4), "MOTEL", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)
		"city_window":
			draw_rect(Rect2(-22, -10, 44, 20), ink)
			for x in range(-19, 20, 8):
				for y in range(-7, 8, 6): draw_rect(Rect2(x, y, 3, 3), accent if (x + y) % 3 else Color("52d9ff"))
		"freezer_fans":
			for x in [-12.0, 12.0]:
				draw_circle(Vector2(x, 0), 9, ink); draw_circle(Vector2(x, 0), 6, Color("9ccbd0"))
				for angle in [0.0, PI * 0.5, PI, PI * 1.5]: draw_line(Vector2(x, 0), Vector2(x, 0) + Vector2.RIGHT.rotated(angle) * 6, metal, 2)
		"roulette":
			draw_circle(Vector2.ZERO, 17, ink); draw_circle(Vector2.ZERO, 14, Color("b51d39"))
			for angle in range(0, 360, 30): draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(deg_to_rad(angle)) * 14, Color("f5d27a"), 1)
			draw_circle(Vector2.ZERO, 4, accent)
		"evidence_wall":
			draw_rect(Rect2(-22, -12, 44, 24), Color("493629"))
			var points := PackedVector2Array([Vector2(-14,-6), Vector2(2,-8), Vector2(13,-2), Vector2(-6,6), Vector2(10,7)])
			for p: Vector2 in points: draw_rect(Rect2(p - Vector2(3, 3), Vector2(7, 6)), Color("ddd3b7"))
			draw_polyline(points, accent, 1)
		"conveyor":
			draw_rect(Rect2(-24, -7, 48, 14), ink); draw_rect(Rect2(-21, -4, 42, 8), Color("75272b"))
			for x in range(-18, 19, 7): draw_circle(Vector2(x, 0), 2, metal)
		"broadcast_console":
			draw_rect(Rect2(-24, -11, 48, 22), ink)
			for x in range(-19, 20, 10):
				draw_rect(Rect2(x, -7, 7, 6), accent.darkened(0.45)); draw_circle(Vector2(x + 3, 5), 1.5, accent)
		"broken_dj":
			draw_rect(Rect2(-22, -10, 44, 20), ink)
			draw_circle(Vector2(-11, 0), 7, Color("4b4057")); draw_circle(Vector2(11, 0), 7, Color("4b4057"))
			draw_line(Vector2(-4,-8), Vector2(4,8), accent, 2); draw_line(Vector2(4,-8), Vector2(-4,8), accent, 2)
	if damaged:
		draw_line(Vector2(-14, -7), Vector2(-5, 1), Color("f1d2bc"), 1)
		draw_line(Vector2(-5, 1), Vector2(3, -3), ink, 1)
		draw_line(Vector2(3, -3), Vector2(13, 7), Color("f1d2bc"), 1)
