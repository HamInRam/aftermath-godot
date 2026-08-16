extends Node2D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const BULLET_SCENE := preload("res://scenes/bullet.tscn")
const CORPSE_SCENE := preload("res://scenes/corpse.tscn")
const SHELL_CASING_SCENE := preload("res://scenes/effects/shell_casing.tscn")
const MUZZLE_FLASH_SCENE := preload("res://scenes/effects/muzzle_flash.tscn")
const UI_DEFAULTS := preload("res://utility/scripts/ui_defaults.gd")
const WEAPON_DATA := {
	"pistol": preload("res://resources/weapons/pistol.tres"),
	"smg": preload("res://resources/weapons/smg.tres"),
	"lmg": preload("res://resources/weapons/lmg.tres")
}

@export var level_title := "FLOOR 01"
@export var player_spawn := Vector2(44, 142)
@export var enemy_spawns := PackedVector2Array([Vector2(45, 47), Vector2(130, 28), Vector2(170, 64), Vector2(230, 38), Vector2(280, 62), Vector2(125, 108), Vector2(180, 147), Vector2(230, 113), Vector2(280, 147)])
@export var enemy_patrol_offsets := PackedVector2Array([Vector2(24, 0), Vector2(24, 0), Vector2(20, 0), Vector2(20, 0), Vector2(24, 0), Vector2(20, 0), Vector2(0, 20), Vector2(0, 20), Vector2(24, 0)])
@export var doors_enabled := true

var phase := "combat"
var player: CharacterBody2D
var status_label: Label
var detail_label: Label
var ammo_label: Label
var combo_label: Label
var enemies_killed := 0
var started_enemy_count := 0
var run_over := false
var elapsed := 0.0
var combo := 0
var combo_timer := 0.0
var pending_death_direction := Vector2.RIGHT
var pending_death_knockback := 20.0
var pending_death_blood_power := 1.0
var hit_stop_generation := 0
var transitioning_cleanup := false
@onready var blood_system = $BloodSystem
@onready var enemies_container: Node2D = $Enemies
@onready var trauma_camera = $TraumaCamera

func _ready() -> void:
	randomize()
	RenderingServer.set_default_clear_color(Color("0e0c10"))
	_create_ui()
	_connect_events()
	_start_run()
	call_deferred("_sync_ammo_ui")

func _process(delta: float) -> void:
	elapsed += delta
	combo_timer -= delta
	if combo_timer <= 0.0: combo = 0
	combo_label.text = ("x%d" % combo) if combo > 1 else ""
	if run_over: return
	if phase == "combat" and not transitioning_cleanup and get_tree().get_nodes_in_group("enemy").is_empty():
		_begin_cleanup_transition()
	elif phase == "cleanup":
		var stains := get_tree().get_nodes_in_group("blood")
		if stains.is_empty():
			run_over = true
			status_label.text = "SCENE CLEAN"
			detail_label.text = "%.1fs  //  R RESTART" % elapsed
		else: status_label.text = "CLEAN // %02d" % stains.size()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/ui/title_menu.tscn")
		return
	if run_over and event.is_action_pressed("reload"):
		get_tree().reload_current_scene()

func _make_label(canvas: CanvasLayer, pos: Vector2, size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	UI_DEFAULTS.apply_label(label, size, color)
	canvas.add_child(label)
	return label

func _create_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	status_label = _make_label(canvas, Vector2(10, 8), 8, Color("fff1f7"))
	detail_label = _make_label(canvas, Vector2(10, 19), 5, Color("c4aabd"))
	ammo_label = _make_label(canvas, Vector2(275, 160), 7, Color("ffe5a8"))
	combo_label = _make_label(canvas, Vector2(270, 12), 9, Color("ff3d78"))
	var controls := _make_label(canvas, Vector2(10, 166), 5, Color("86788b"))
	controls.text = "WASD MOVE // SHIFT LOOK // LMB FIRE // R RELOAD // ESC MENU"

func _connect_events() -> void:
	Events.ammo_updated.connect(_on_ammo_updated)
	Events.reload_started.connect(_on_reload_started)
	Events.reload_finished.connect(_on_reload_finished)
	Events.weapon_fired.connect(_on_weapon_fired)
	Events.door_impact.connect(_on_door_impact)

func _on_door_impact(_world_position: Vector2, intensity: float) -> void:
	trauma_camera.add_trauma(clampf(intensity * 0.13, 0.04, 0.24))

func _on_ammo_updated(current: int, maximum: int, is_reloading: bool) -> void:
	if phase == "cleanup": return
	ammo_label.text = "RELOAD" if is_reloading else "%02d/%02d" % [current, maximum]

func _on_reload_started(_duration: float) -> void:
	if phase != "cleanup": detail_label.text = "RELOADING..."

func _on_reload_finished(_current: int, _maximum: int) -> void:
	if phase != "cleanup": detail_label.text = "NO WITNESSES."

func _on_weapon_fired(origin: Vector2, direction: Vector2, enemy_owned: bool, weapon_id: String) -> void:
	var data = WEAPON_DATA.get(weapon_id, WEAPON_DATA.pistol)
	var casing = SHELL_CASING_SCENE.instantiate()
	add_child(casing)
	var perpendicular := direction.rotated(PI * 0.5)
	casing.global_position = origin - direction * randf_range(4.5, 7.5) + perpendicular * randf_range(-1.8, 1.8)
	casing.rotation = randf_range(-PI, PI)
	casing.setup(direction, enemy_owned)
	var flash = MUZZLE_FLASH_SCENE.instantiate()
	flash.global_position = origin
	flash.setup(direction, data.muzzle_flash_size, data.muzzle_flash_duration)
	add_child(flash)

func _start_run() -> void:
	status_label.text = "AFTERMATH // " + level_title
	detail_label.text = "NO WITNESSES."
	if not doors_enabled and has_node("Doors"): $Doors.queue_free()
	player = PLAYER_SCENE.instantiate()
	player.global_position = player_spawn
	player.projectile_requested.connect(_on_projectile_requested)
	player.clean_requested.connect(_on_clean_requested)
	player.died.connect(_on_player_died)
	add_child(player)
	for index in enemy_spawns.size(): _spawn_enemy(enemy_spawns[index], index)
	started_enemy_count = enemy_spawns.size()

func _sync_ammo_ui() -> void:
	if is_instance_valid(player) and is_instance_valid(player.gun):
		Events.publish_ammo(player.gun.ammo, player.gun.max_ammo, player.gun.is_reloading)

func _spawn_enemy(pos: Vector2, patrol_index := -1) -> void:
	var enemy = ENEMY_SCENE.instantiate()
	enemy.projectile_requested.connect(_on_projectile_requested)
	enemy.died_at.connect(_on_enemy_died)
	enemies_container.add_child(enemy)
	enemy.global_position = pos
	if patrol_index >= 0 and patrol_index < enemy_patrol_offsets.size():
		enemy.patrol_waypoints = PackedVector2Array([pos, pos + enemy_patrol_offsets[patrol_index]])

func _on_projectile_requested(origin: Vector2, direction: Vector2, enemy_owned: bool, damage: int, weapon_id: String) -> void:
	if phase != "combat" or run_over: return
	var data = WEAPON_DATA.get(weapon_id, WEAPON_DATA.pistol)
	var bullet = BULLET_SCENE.instantiate()
	bullet.global_position = origin
	bullet.blood_impact.connect(_on_blood_impact)
	bullet.setup(direction, enemy_owned, damage, weapon_id, origin, data.bullet_speed)
	add_child(bullet)
	trauma_camera.add_trauma(data.camera_shake * (0.1 if enemy_owned else 0.14))

func _on_enemy_died(pos: Vector2, facing: float) -> void:
	enemies_killed += 1
	combo += 1
	combo_timer = 2.2
	trauma_camera.add_trauma(0.42)
	var corpse = CORPSE_SCENE.instantiate()
	corpse.global_position = pos
	corpse.setup(facing, pending_death_direction, pending_death_knockback, pending_death_blood_power)
	add_child(corpse)
	blood_system.spawn_death_pool(pos, pending_death_blood_power)
	status_label.text = "TARGETS // %02d/%02d" % [enemies_killed, started_enemy_count]

func _on_blood_impact(hit_position: Vector2, direction: Vector2, damage: int, weapon_id: String, travel_distance: float, lethal: bool) -> void:
	blood_system.emit_hit(hit_position, direction, damage, weapon_id, travel_distance, lethal)
	if lethal:
		var data = WEAPON_DATA.get(weapon_id, WEAPON_DATA.pistol)
		pending_death_direction = direction
		pending_death_knockback = data.knockback
		pending_death_blood_power = data.blood_power
		_trigger_hit_stop(data.hit_stop)

func _trigger_hit_stop(duration: float) -> void:
	if duration <= 0.0: return
	hit_stop_generation += 1
	var generation := hit_stop_generation
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	if generation == hit_stop_generation: Engine.time_scale = 1.0

func _on_player_died() -> void:
	run_over = true
	trauma_camera.add_trauma(1.0)
	_trigger_death_flash()
	status_label.text = "YOU ARE DEAD"
	detail_label.text = "R TO RESTART"

func _trigger_death_flash() -> void:
	var flash := $DeathPresentation/Flash as ColorRect
	flash.color = Color(0.85, 0.03, 0.08, 0.48)
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_ignore_time_scale(true)
	tween.tween_property(flash, "color", Color(0.18, 0.18, 0.2, 0.0), 0.22)

func _exit_tree() -> void:
	Engine.time_scale = 1.0

func _enter_cleanup_phase() -> void:
	phase = "cleanup"
	player.set_cleanup_mode(true)
	for bullet in get_tree().get_nodes_in_group("bullet"): bullet.queue_free()
	status_label.text = "CLEANUP REQUIRED"
	detail_label.text = "GET CLOSE // HOLD LMB"
	ammo_label.text = "MOP"

func _begin_cleanup_transition() -> void:
	transitioning_cleanup = true
	await get_tree().create_timer(0.42, true, false, true).timeout
	if not is_inside_tree() or run_over: return
	Events.combat_ended.emit()
	_enter_cleanup_phase()

func _on_clean_requested(world_position: Vector2) -> void:
	if phase != "cleanup" or run_over: return
	if player.global_position.distance_to(world_position) > 33.0: return
	var best_stain: Node2D = null
	var best_distance := 99999.0
	for stain in get_tree().get_nodes_in_group("blood"):
		var distance: float = stain.global_position.distance_to(world_position)
		if distance < 15.0 and distance < best_distance:
			best_stain = stain
			best_distance = distance
	if best_stain != null: best_stain.clean_step()
