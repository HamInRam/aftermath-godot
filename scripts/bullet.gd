extends CharacterBody2D

const WALL_SPARKS_SCENE := preload("res://scenes/effects/wall_sparks.tscn")
const PIXEL_PAINTER := preload("res://utility/pixel_art_painter.gd")

const PLAYER_LAYER := 1
const ENEMY_LAYER := 2
const SOLID_LAYER := 4
const GLASS_LAYER := 8
const CORPSE_LAYER := 32
const PLAYER_PROJECTILE_MASK := ENEMY_LAYER | SOLID_LAYER | GLASS_LAYER | CORPSE_LAYER
const ENEMY_PROJECTILE_MASK := PLAYER_LAYER | SOLID_LAYER | GLASS_LAYER
const DEBRIS_PENETRATION_SPEED_RETENTION := 0.9
const DEBRIS_CLEARANCE := 5.0

signal blood_impact(hit_position: Vector2, direction: Vector2, damage: int, weapon_id: String, travel_distance: float, lethal: bool, hit_zone: String)
signal damage_impact(context: DamageContext)
signal shot_resolved(shot_id: int, outcome: String, lethal: bool, weapon_id: String)

@export var speed := 650.0
var direction := Vector2.RIGHT
var enemy_owned := false
var damage := 1
var lifetime := 1.2
var weapon_id := "pistol"
var spawn_position := Vector2.ZERO
var travel_distance := 0.0
var shot_id := -1
var resolution_emitted := false
var passed_overkill_target := false
var source_actor: CollisionObject2D

func setup(dir: Vector2, is_enemy_bullet: bool, hit_damage := 1, source_weapon := "pistol", origin := Vector2.ZERO, projectile_speed := 650.0, shooter: CollisionObject2D = null) -> void:
	direction = dir.normalized()
	enemy_owned = is_enemy_bullet
	damage = hit_damage
	weapon_id = source_weapon
	spawn_position = origin
	speed = projectile_speed
	source_actor = shooter
	# Only query the opposing actor layer. This prevents allied bodies from
	# silently consuming rounds and does not rely on the muzzle sitting outside
	# the shooter's collision shape on every animation frame.
	collision_mask = ENEMY_PROJECTILE_MASK if enemy_owned else PLAYER_PROJECTILE_MASK
	rotation = direction.angle()
	velocity = direction * speed
	if is_inside_tree(): _install_source_exception()

func _ready() -> void:
	_install_source_exception()

func _install_source_exception() -> void:
	if is_instance_valid(source_actor): add_collision_exception_with(source_actor)

func _physics_process(delta: float) -> void:
	travel_distance += velocity.length() * delta
	var collision := move_and_collide(velocity * delta)
	if collision != null:
		var collider := collision.get_collider()
		# Prop fragments share the evidence/occluder layer with corpses, but are
		# not ballistic blockers. Kick the tiny fragment aside and continue the
		# round instead of making it appear to vanish in open floor space.
		if collider is Node and collider.is_in_group("environment_debris"):
			if collider.has_method("receive_projectile_glance"):
				collider.receive_projectile_glance(velocity, collision.get_position(), weapon_id, damage)
			if collider is CollisionObject2D: add_collision_exception_with(collider)
			global_position = collision.get_position() + direction * DEBRIS_CLEARANCE
			velocity *= DEBRIS_PENETRATION_SPEED_RETENTION
			speed = velocity.length()
			return
		if not enemy_owned and collider is Node and collider.is_in_group("corpse") and collider.has_method("can_receive_overkill") and collider.can_receive_overkill():
			var overkill_context := DamageContext.create(collision.get_position(), direction, damage, weapon_id, travel_distance, false, "torso", spawn_position, collider)
			damage_impact.emit(overkill_context)
			collider.receive_projectile_overkill(direction, collision.get_position(), weapon_id, velocity.length())
			passed_overkill_target = true
			if collider is CollisionObject2D: add_collision_exception_with(collider)
			global_position = collision.get_position() + direction * 3.0
			velocity *= 0.68
			speed = velocity.length()
			return
		var tile_world = collider.get_parent() if collider is TileMapLayer else null
		if tile_world != null and tile_world.has_method("shatter_glass_at") and tile_world.shatter_glass_at(collision.get_position(), direction):
			global_position = collision.get_position() + direction * 9.0
			return
		var hit_solid_surface: bool = collider is TileMapLayer or (collider is CollisionObject2D and collider.get_collision_layer_value(3))
		if hit_solid_surface:
			var sparks = WALL_SPARKS_SCENE.instantiate()
			var effect_parent := get_tree().current_scene if get_tree().current_scene != null else get_parent()
			if RuntimeBudget.try_add("transient_fx", sparks, effect_parent):
				sparks.global_position = collision.get_position()
				sparks.setup(direction)
		if collider is Node and collider.has_method("receive_projectile_impact_context"):
			collider.receive_projectile_impact_context(velocity, collision.get_position(), weapon_id, damage)
		elif collider is Node and collider.has_method("receive_projectile_impact"):
			collider.receive_projectile_impact(velocity, collision.get_position())
		if collider is Node and collider.has_method("take_damage"):
			var valid_target: bool = (enemy_owned and collider.is_in_group("player")) or ((not enemy_owned) and collider.is_in_group("enemy"))
			if valid_target:
				var current_hp: int = int(collider.get("hp"))
				var hit_zone := str(collider.classify_hit_zone(global_position)) if collider.has_method("classify_hit_zone") else "torso"
				var context := DamageContext.create(global_position, direction, damage, weapon_id, travel_distance, current_hp <= damage, hit_zone, spawn_position, collider)
				damage_impact.emit(context)
				collider.take_damage(damage, global_position - direction * 2.0)
				_resolve_shot("enemy", context.lethal)
		if not resolution_emitted: _resolve_shot("overkill" if passed_overkill_target else "miss", false)
		queue_free()
		return
	lifetime -= delta
	if lifetime <= 0.0:
		_resolve_shot("overkill" if passed_overkill_target else "miss", false)
		queue_free()

func _resolve_shot(outcome: String, lethal: bool) -> void:
	if resolution_emitted or enemy_owned or shot_id < 0: return
	resolution_emitted = true
	shot_resolved.emit(shot_id, outcome, lethal, weapon_id)

func _draw() -> void:
	var color := Color("ffe48a") if not enemy_owned else Color("ff3868")
	PIXEL_PAINTER.line(self, Vector2(-5, 0), Vector2(-1, 0), Color(color, 0.3))
	PIXEL_PAINTER.pixel(self, Vector2.ZERO, color)
