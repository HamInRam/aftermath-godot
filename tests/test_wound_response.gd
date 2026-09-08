extends Node2D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const BLOOD_SYSTEM := preload("res://scripts/effects/blood_system.gd")
const RESOLVER := preload("res://scripts/combat/ballistic_damage_resolver.gd")

var failures := 0

func _ready() -> void:
	var matched := RESOLVER.resolve(43.0, 0.82, "torso", 24.0, 65.0, 170.0, 0.62, 75, 75, 0.0, 0.0, 0.0, false, false, "handgun")
	var extreme := RESOLVER.resolve(43.0, 2.6, "torso", 24.0, 65.0, 170.0, 0.62, 75, 75, 0.0, 0.0, 0.0, false, false, "handgun")
	var stopped := RESOLVER.resolve(43.0, 0.62, "torso", 24.0, 65.0, 170.0, 0.62, 95, 95, 1.45, 0.38, 60.0, false, false, "handgun")
	_expect(bool(matched.projectile_exited) and float(matched.exit_wound_scale) > 0.0, "a tissue-matched pistol round should produce an exit wound")
	_expect(float(matched.energy_transfer) > float(extreme.energy_transfer), "extreme over-penetration must retain more energy instead of multiplying tissue trauma")
	_expect(not bool(stopped.projectile_exited) and is_zero_approx(float(stopped.exit_wound_scale)), "armour-stopped rounds must not emit impossible exit blood")
	_expect(float(stopped.external_blood_scale) < float(matched.external_blood_scale), "an armour-stopped round should create less immediate external blood")

	var blood = BLOOD_SYSTEM.new()
	blood.add_to_group("blood_system")
	add_child(blood)
	var player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.global_position = Vector2(180, 80)
	player.set_physics_process(false)
	var enemy = ENEMY_SCENE.instantiate()
	add_child(enemy)
	enemy.global_position = Vector2(24, 80)
	enemy.tile_world = self
	enemy.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var hp_before: int = enemy.hp
	enemy.apply_ballistic_hit(matched, player.global_position)
	_expect(enemy.hp < hp_before and not enemy.is_dead, "a non-lethal wound should reduce vitality without deleting the actor")
	_expect(enemy.lifecycle_rig.hit_feedback_time > 0.0 and enemy.lifecycle_rig.hit_feedback_kind == "flesh", "a surviving flesh hit should trigger a readable two-stage body flash")
	_expect(enemy.tactical_move_mode.is_empty(), "a wound must not inject a forced-cover order that fights the existing combat state machine")
	_expect(enemy.active_bleed_rate > 0.0 and enemy.active_bleed_time > 0.0, "the ballistic wound must retain a timed bleeding state")
	enemy.global_position += Vector2(12, 0)
	enemy._update_active_wound(0.9)
	_expect(blood.ground_canvas.has_blood_near(enemy.global_position, 8.0), "a moving wounded enemy should leave a sparse persistent pixel trail")

	if failures == 0: print("wound response regression: PASS")
	get_tree().quit(failures)

func get_navigation_path(_from: Vector2, to: Vector2) -> PackedVector2Array:
	return PackedVector2Array([to])

func is_navigation_position_walkable(_position: Vector2) -> bool:
	return true

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
