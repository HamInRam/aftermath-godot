extends Node2D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const BULLET_SCENE := preload("res://scenes/bullet.tscn")
const CORPSE_SCENE := preload("res://scenes/corpse.tscn")
const SHELL_CASING_SCENE := preload("res://scenes/effects/shell_casing.tscn")
const UI_DEFAULTS := preload("res://utility/scripts/ui_defaults.gd")

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
var shake_strength := 0.0
var flash_alpha := 0.0
@onready var blood_system = $BloodSystem

var wall_rects: Array[Rect2] = [
	Rect2(0, 0, 320, 7), Rect2(0, 173, 320, 7), Rect2(0, 0, 7, 180), Rect2(313, 0, 7, 180),
	Rect2(88, 32, 6, 62), Rect2(88, 115, 6, 45), Rect2(190, 76, 75, 6),
	Rect2(190, 82, 6, 39), Rect2(145, 127, 6, 46),
]

func _ready() -> void:
	randomize()
	RenderingServer.set_default_clear_color(Color("0e0c10"))
	_create_world()
	_create_ui()
	_connect_events()
	_start_run()
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	shake_strength = move_toward(shake_strength, 0.0, 5.0 * delta)
	position = Vector2(randf_range(-shake_strength, shake_strength), randf_range(-shake_strength, shake_strength))
	flash_alpha = move_toward(flash_alpha, 0.0, 5.5 * delta)
	combo_timer -= delta
	if combo_timer <= 0.0: combo = 0
	queue_redraw()
	combo_label.text = ("x%d" % combo) if combo > 1 else ""
	if run_over: return
	if phase == "combat" and get_tree().get_nodes_in_group("enemy").is_empty():
		_enter_cleanup_phase()
	elif phase == "cleanup":
		var stains := get_tree().get_nodes_in_group("blood")
		if stains.is_empty():
			run_over = true
			status_label.text = "SCENE CLEAN"
			detail_label.text = "%.1fs  //  R RESTART" % elapsed
		else: status_label.text = "CLEAN // %02d" % stains.size()

func _unhandled_input(event: InputEvent) -> void:
	if run_over and event.is_action_pressed("reload"):
		get_tree().reload_current_scene()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 320, 180), Color("100d14"))
	# Checkerboard room.
	for x in range(7, 88, 8):
		for y in range(7, 32, 8):
			draw_rect(Rect2(x, y, 8, 8), Color("ede7df") if ((x + y) / 8 as int) % 2 == 0 else Color("1b1720"))
	# Wood rooms.
	draw_rect(Rect2(7, 32, 81, 128), Color("42281f"))
	draw_rect(Rect2(94, 7, 102, 69), Color("39251f"))
	for y in range(33, 160, 3): draw_line(Vector2(7, y), Vector2(88, y), Color(0.75, 0.38, 0.22, 0.2), 1)
	for y in range(8, 76, 3): draw_line(Vector2(94, y), Vector2(196, y), Color(0.8, 0.47, 0.25, 0.17), 1)
	# Wallpaper and grass.
	draw_rect(Rect2(196, 7, 117, 69), Color("c9aa9c"))
	for x in range(198, 313, 6):
		for y in range(9, 76, 6): draw_circle(Vector2(x, y), 1.0, Color(0.2, 0.42, 0.38, 0.4))
	draw_rect(Rect2(94, 82, 96, 45), Color("29331e"))
	draw_rect(Rect2(196, 82, 117, 91), Color("193326"))
	draw_rect(Rect2(151, 127, 162, 46), Color("352326"))
	_draw_neon_pool(Vector2(110, 58), Color("ff214f"), 60.0)
	_draw_neon_pool(Vector2(178, 58), Color("3cdb75"), 52.0)
	_draw_neon_pool(Vector2(235, 45), Color("dc2e79"), 58.0)
	_draw_neon_pool(Vector2(260, 135), Color("26bf69"), 62.0)
	for rect in wall_rects:
		draw_rect(rect.grow(1), Color("09080c"))
		draw_rect(rect, Color("30283b"))
		draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), Color("9d477c"), 1)
	for y in range(0, 180, 2): draw_line(Vector2(0, y), Vector2(320, y), Color(0, 0, 0, 0.08), 1)
	draw_rect(Rect2(1, 1, 318, 178), Color(1, 0.15, 0.25, flash_alpha), false, 3)

func _draw_neon_pool(center: Vector2, color: Color, radius: float) -> void:
	for i in range(7, 0, -1):
		draw_circle(center, radius * float(i) / 7.0, Color(color, 0.018 + float(8 - i) * 0.006))

func _create_world() -> void:
	for rect in wall_rects:
		var wall := StaticBody2D.new()
		wall.collision_layer = 2
		wall.collision_mask = 5
		var collider := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		collider.shape = shape
		wall.position = rect.position + rect.size * 0.5
		wall.add_child(collider)
		add_child(wall)

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
	controls.text = "WASD MOVE // MOUSE AIM // LMB FIRE // R RELOAD"

func _connect_events() -> void:
	Events.ammo_updated.connect(_on_ammo_updated)
	Events.reload_started.connect(_on_reload_started)
	Events.reload_finished.connect(_on_reload_finished)
	Events.weapon_fired.connect(_on_weapon_fired)

func _on_ammo_updated(current: int, maximum: int, is_reloading: bool) -> void:
	if phase == "cleanup": return
	ammo_label.text = "RELOAD" if is_reloading else "%02d/%02d" % [current, maximum]

func _on_reload_started(_duration: float) -> void:
	if phase != "cleanup": detail_label.text = "RELOADING..."

func _on_reload_finished(_current: int, _maximum: int) -> void:
	if phase != "cleanup": detail_label.text = "NO WITNESSES."

func _on_weapon_fired(origin: Vector2, direction: Vector2, enemy_owned: bool) -> void:
	var casing = SHELL_CASING_SCENE.instantiate()
	add_child(casing)
	casing.global_position = origin - direction * 6.0
	casing.setup(direction, enemy_owned)

func _start_run() -> void:
	status_label.text = "AFTERMATH // FLOOR 01"
	detail_label.text = "NO WITNESSES."
	player = PLAYER_SCENE.instantiate()
	player.global_position = Vector2(44, 142)
	player.projectile_requested.connect(_on_projectile_requested)
	player.clean_requested.connect(_on_clean_requested)
	player.died.connect(_on_player_died)
	add_child(player)
	var positions := [Vector2(45, 47), Vector2(130, 28), Vector2(170, 64), Vector2(230, 38), Vector2(280, 62), Vector2(125, 108), Vector2(180, 147), Vector2(230, 113), Vector2(280, 147)]
	for pos in positions: _spawn_enemy(pos)
	started_enemy_count = positions.size()

func _spawn_enemy(pos: Vector2) -> void:
	var enemy = ENEMY_SCENE.instantiate()
	enemy.global_position = pos
	enemy.projectile_requested.connect(_on_projectile_requested)
	enemy.died_at.connect(_on_enemy_died)
	add_child(enemy)

func _on_projectile_requested(origin: Vector2, direction: Vector2, enemy_owned: bool, damage: int, weapon_id: String) -> void:
	if phase != "combat" or run_over: return
	var bullet = BULLET_SCENE.instantiate()
	bullet.global_position = origin
	bullet.blood_impact.connect(_on_blood_impact)
	bullet.setup(direction, enemy_owned, damage, weapon_id, origin)
	add_child(bullet)
	shake_strength = maxf(shake_strength, 0.65 if enemy_owned else 1.0)
	flash_alpha = 0.22

func _on_enemy_died(pos: Vector2, facing: float) -> void:
	enemies_killed += 1
	combo += 1
	combo_timer = 2.2
	shake_strength = 2.2
	flash_alpha = 0.45
	var corpse = CORPSE_SCENE.instantiate()
	corpse.global_position = pos
	corpse.setup(facing)
	add_child(corpse)
	status_label.text = "TARGETS // %02d/%02d" % [enemies_killed, started_enemy_count]

func _on_blood_impact(hit_position: Vector2, direction: Vector2, damage: int, weapon_id: String, travel_distance: float, lethal: bool) -> void:
	blood_system.emit_hit(hit_position, direction, damage, weapon_id, travel_distance, lethal)

func _on_player_died() -> void:
	run_over = true
	shake_strength = 3.5
	status_label.text = "YOU ARE DEAD"
	detail_label.text = "R TO RESTART"

func _enter_cleanup_phase() -> void:
	phase = "cleanup"
	player.set_cleanup_mode(true)
	for bullet in get_tree().get_nodes_in_group("bullet"): bullet.queue_free()
	status_label.text = "CLEANUP REQUIRED"
	detail_label.text = "GET CLOSE // HOLD LMB"
	ammo_label.text = "MOP"

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
