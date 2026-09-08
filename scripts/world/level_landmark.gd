class_name LevelLandmark
extends StaticBody2D

const MATERIAL_BURST := preload("res://scripts/effects/material_burst.gd")
const PHYSICAL_DEBRIS := preload("res://scripts/props/physical_debris.gd")
const ENVIRONMENT_HAZARD := preload("res://scripts/effects/environment_hazard.gd")
const PIXELS := preload("res://utility/pixel_art_painter.gd")

signal solidity_changed(solid: bool)

var landmark_kind := ""
var accent := Color("bdbdbd")
var hp := 3
var damaged := false
var destroyed := false
var _collision: CollisionShape2D
var impact_direction := Vector2.RIGHT
var active_hazard: EnvironmentHazard

func setup(kind: String, tint: Color) -> void:
	landmark_kind = kind
	accent = Color(tint.v, tint.v, tint.v)
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
	var amount := 2 if AttackCatalog.get_gun_data(weapon_id).weapon_class == "shotgun" or damage >= 2 else 1
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
	var ink := Color("111111")
	var steel := Color("737373")
	var chalk := Color("e4e4e4")
	if destroyed:
		var profile: Dictionary = DestructionMaterial.PROFILES[_setpiece_material()]
		var part_index := 0
		for part: Rect2 in [Rect2(-18,-4,10,6), Rect2(-5,3,8,5), Rect2(7,-6,12,7), Rect2(14,5,5,4)]:
			_landmark_panel(part, profile.primary, &"metal", 40 + part_index)
			part_index += 1
		return
	match landmark_kind:
		"dj_booth", "broken_dj":
			# A heavy console cabinet, pale side cheeks and dark record platters.
			_landmark_panel(Rect2(-22,-9,44,18), steel, &"metal", 41)
			PIXELS.rect(self, Rect2(-21,-7,3,14), chalk)
			PIXELS.rect(self, Rect2(18,-7,3,14), chalk)
			_landmark_disc(Vector2(-11,0),6,Color("bdbdbd"),42)
			_landmark_disc(Vector2(11,0),6,Color("bdbdbd"),43)
			for x in [-11,11]: PIXELS.circle(self, Vector2(x,0),3,ink)
			for x in [-3,0,3]:
				PIXELS.line(self,Vector2(x,-5),Vector2(x,4),ink)
				PIXELS.rect(self,Rect2(x-1,-2+posmod(x,3),3,1),chalk)
			if landmark_kind == "broken_dj": PIXELS.line(self, Vector2(-5,-7), Vector2(5,7), chalk)
		"diner_counter":
			_landmark_panel(Rect2(-24,-6,48,12),Color("777777"),&"wood",45)
			PIXELS.rect(self,Rect2(-23,-5,46,4),chalk)
			for x in [-16,0,16]: _landmark_disc(Vector2(x,8),3,Color("737373"),x+46)
			for x in [-15,7]: PIXELS.rect(self,Rect2(x,-4,7,2),Color("b8b8b8"))
		"training_target":
			_landmark_panel(Rect2(-4,-18,8,36),Color("777777"),&"wood",47)
			_landmark_disc(Vector2(0,-5),9,chalk,48)
			PIXELS.circle(self,Vector2(0,-5),6,Color("4a4a4a"),true)
			PIXELS.circle(self,Vector2(0,-5),3,ink)
		"cargo_crane":
			_landmark_panel(Rect2(-18,-5,36,10),steel,&"metal",51)
			for x in range(-14,15,7): PIXELS.line(self,Vector2(x,-3),Vector2(x+3,3),ink)
			PIXELS.line(self,Vector2(10,-2),Vector2(18,12),chalk)
			PIXELS.line(self,Vector2(18,12),Vector2(18,20),steel)
			PIXELS.line(self,Vector2(18,20),Vector2(14,20),steel)
		"motel_sign":
			_landmark_panel(Rect2(-19,-8,38,16),Color("393939"),&"metal",52)
			PIXELS.rect(self,Rect2(-18,-7,36,1),chalk)
			PIXELS.text(self,"MOTEL",Vector2(-10,-3),chalk)
			PIXELS.line(self,Vector2(-14,5),Vector2(14,5),Color("969696"))
		"city_window":
			_landmark_panel(Rect2(-22,-10,44,20),Color("bcbcbc"),&"glass",53)
			PIXELS.rect(self,Rect2(-20,-8,40,16),Color("3d3d3d"))
			for x in [-10,0,10]: PIXELS.line(self,Vector2(x,-8),Vector2(x,7),chalk)
			PIXELS.line(self,Vector2(-20,0),Vector2(19,0),chalk)
			PIXELS.line(self,Vector2(-17,-6),Vector2(-13,-3),Color("909090"))
		"freezer_fans":
			_landmark_panel(Rect2(-24,-11,48,22),steel,&"metal",54)
			for x in [-12,12]:
				_landmark_disc(Vector2(x,0),9,Color("c2c2c2"),54+x)
				PIXELS.circle(self,Vector2(x,0),7,ink)
				for direction in [Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT]:
					PIXELS.line(self,Vector2(x,0)+direction*2,Vector2(x,0)+direction*6+direction.orthogonal()*2,Color("a8a8a8"),2)
				PIXELS.circle(self,Vector2(x,0),2,chalk)
		"roulette":
			_landmark_disc(Vector2.ZERO,17,steel,55)
			PIXELS.circle(self,Vector2.ZERO,14,ink)
			for angle in range(0,360,30):
				var radial := Vector2.RIGHT.rotated(deg_to_rad(angle))
				PIXELS.line(self,radial*7,radial*13,chalk)
			_landmark_disc(Vector2.ZERO,5,Color("9e9e9e"),56)
			PIXELS.circle(self,Vector2.ZERO,2,chalk)
		"evidence_wall":
			_landmark_panel(Rect2(-22,-12,44,24),Color("777777"),&"wood",57)
			var points := PackedVector2Array([Vector2(-14,-6),Vector2(2,-8),Vector2(13,-2),Vector2(-6,6),Vector2(10,7)])
			PIXELS.polyline(self,points,Color("303030"))
			for point: Vector2 in points:
				PIXELS.rect(self,Rect2(point-Vector2(3,3),Vector2(7,6)),chalk)
				PIXELS.line(self,point-Vector2(1,1),point+Vector2(2,-1),Color("8e8e8e"))
				PIXELS.pixel(self,point+Vector2(0,-3),ink)
		"conveyor":
			_landmark_panel(Rect2(-24,-7,48,14),steel,&"metal",58)
			PIXELS.rect(self,Rect2(-21,-4,42,8),Color("373737"))
			for x in range(-18,19,6): PIXELS.line(self,Vector2(x,-3),Vector2(x,3),Color("a3a3a3"))
		"broadcast_console":
			_landmark_panel(Rect2(-24,-11,48,22),steel,&"metal",60)
			for x in [-19,-9,1,11]:
				PIXELS.rect(self,Rect2(x,-7,8,7),ink)
				PIXELS.rect(self,Rect2(x+1,-6,6,4),Color("c1c1c1"))
				PIXELS.line(self,Vector2(x+2,3),Vector2(x+2,7),ink)
				PIXELS.rect(self,Rect2(x+1,5,3,1),chalk)
	if damaged:
		PIXELS.polyline(self,PackedVector2Array([Vector2(-14,-7),Vector2(-5,1),Vector2(3,-3),Vector2(13,7)]),ink)
		PIXELS.line(self,Vector2(-14,-6),Vector2(-6,1),chalk)

func _landmark_panel(area: Rect2, color: Color, pattern: StringName, _seed: int) -> void:
	PIXELS.rect(self,Rect2(area.position+Vector2(1,2),area.size),Color(0.02,0.02,0.02,0.4))
	PIXELS.rect(self,area,Color("111111"))
	PIXELS.rect(self,Rect2(area.position+Vector2.ONE,area.size-Vector2(2,2)),color)
	PIXELS.line(self,area.position+Vector2.ONE,Vector2(area.end.x-2,area.position.y+1),Color("e2e2e2"))
	if pattern == &"wood":
		PIXELS.line(self,area.position+Vector2(3,area.size.y-3),area.position+Vector2(area.size.x-4,area.size.y-3),Color("515151"))

func _landmark_disc(center: Vector2, radius: int, color: Color, _seed: int) -> void:
	PIXELS.circle(self,center,radius,Color("111111"))
	if radius > 1: PIXELS.circle(self,center,radius-1,color)
	PIXELS.arc(self,center,radius-1,PI*1.1,PI*1.8,color.lightened(0.3),12)
