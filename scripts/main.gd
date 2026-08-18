extends Node2D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const BULLET_SCENE := preload("res://scenes/bullet.tscn")
const CORPSE_SCENE := preload("res://scenes/corpse.tscn")
const SHELL_CASING_SCENE := preload("res://scenes/effects/shell_casing.tscn")
const MUZZLE_FLASH_SCENE := preload("res://scenes/effects/muzzle_flash.tscn")
const WEAPON_PICKUP_SCENE := preload("res://scenes/props/weapon_pickup.tscn")
const THROWN_WEAPON_SCENE := preload("res://scenes/props/thrown_weapon.tscn")
const EXTRACTION_ZONE_SCENE := preload("res://scenes/props/extraction_zone.tscn")

@export var level_title := "FLOOR 01"
@export var player_spawn := Vector2(44, 142)
@export var enemy_spawns := PackedVector2Array([Vector2(45, 47), Vector2(130, 28), Vector2(170, 64), Vector2(230, 38), Vector2(280, 62), Vector2(125, 108), Vector2(180, 147), Vector2(230, 113), Vector2(280, 147)])
@export var enemy_patrol_offsets := PackedVector2Array([Vector2(0, 48), Vector2(56, 0), Vector2(0, 48), Vector2(64, 0), Vector2(-48, 0), Vector2(48, 0), Vector2(56, 0), Vector2(0, 56), Vector2(56, 0)])
@export var enemy_types := PackedStringArray(["melee", "gunner", "gunner", "gunner", "gunner", "melee", "gunner", "gunner", "gunner"])
@export var fixed_sentry_indices := PackedInt32Array()
@export var doors_enabled := true
@export var extraction_position := Vector2.ZERO
@export var mission_profile: MissionProfile

var phase := "combat"
var player: CharacterBody2D
var status_label: Label
var detail_label: Label
var ammo_label: Label
var combo_label: Label
var interaction_label: Label
var hud: HudController
var combat_feedback: CombatFeedback
var enemies_killed := 0
var started_enemy_count := 0
var remaining_enemies := 0
var run_over := false
var elapsed := 0.0
var combo := 0
var combo_timer := 0.0
var pending_death_direction := Vector2.RIGHT
var pending_death_knockback := 20.0
var pending_death_blood_power := 1.0
var pending_death_style := "firearm"
var transitioning_cleanup := false
var vision_debug_enabled := false
var screen_effects_enabled := true
var hue_cycle_enabled := true
var extraction_zone: ExtractionZone
var mission_tracker := MissionTracker.new()
var final_score := 0
var final_grade := ""
@onready var blood_system = $BloodSystem
@onready var enemies_container: Node2D = $Enemies
@onready var trauma_camera = $TraumaCamera

func _ready() -> void:
	randomize()
	RenderingServer.set_default_clear_color(Color("0e0c10"))
	_create_ui()
	combat_feedback = CombatFeedback.new()
	add_child(combat_feedback)
	combat_feedback.configure($DeathPresentation/Flash)
	_connect_events()
	trauma_camera.impact_flash_requested.connect(_on_impact_flash_requested)
	_start_run()
	call_deferred("_sync_ammo_ui")

func _process(delta: float) -> void:
	elapsed += delta
	combo_timer -= delta
	if combo_timer <= 0.0: combo = 0
	hud.set_combo(combo)
	_update_interaction_prompt()
	if run_over: return
	if phase == "combat": _update_combat_objective_hud()
	if phase == "combat" and not transitioning_cleanup and mission_tracker.are_combat_objectives_complete():
		_begin_cleanup_transition()
	elif phase == "cleanup":
		ammo_label.text = player.current_cleanup_tool.to_upper().replace("_", " ")
		_deposit_bagged_corpses()
		var remaining_cleanup := CleanupRegistry.get_remaining_count()
		if remaining_cleanup == 0:
			_finish_run(false)
		else:
			status_label.text = "CLEAN // %02d  RISK // %03d" % [remaining_cleanup, CleanupRegistry.get_remaining_value()]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F3:
		_toggle_vision_debug()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F4:
		_toggle_screen_effects()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F5:
		_toggle_hue_cycle()
		return
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/ui/title_menu.tscn")
		return
	if run_over and event.is_action_pressed("reload"):
		get_tree().reload_current_scene()

func _create_ui() -> void:
	hud = HudController.new()
	add_child(hud)
	status_label = hud.status_label
	detail_label = hud.detail_label
	ammo_label = hud.ammo_label
	combo_label = hud.combo_label
	interaction_label = hud.interaction_label

func _update_interaction_prompt() -> void:
	if run_over: return
	if not is_instance_valid(interaction_label) or not is_instance_valid(player) or player.is_executing:
		if is_instance_valid(interaction_label): interaction_label.text = ""
		return
	if phase == "cleanup":
		if is_instance_valid(player.dragged_corpse): interaction_label.text = "[ E ] DROP BODY"
		elif is_instance_valid(player.get_nearby_draggable_corpse()): interaction_label.text = "[ E ] DRAG BODY"
		elif is_instance_valid(extraction_zone) and extraction_zone.contains_position(player.global_position): interaction_label.text = "[ E ] LEAVE SCENE // RISK %d" % CleanupRegistry.get_remaining_value()
		else: interaction_label.text = "[ 1 ] MOP  [ 2 ] EVIDENCE  [ 3 ] BODY BAG"
		return
	if phase != "combat":
		interaction_label.text = ""
		return
	if is_instance_valid(player.peek_nearby_execution_target()):
		interaction_label.text = "[ SPACE ] EXECUTE"
	else:
		var pickup = player.get_nearby_weapon_pickup()
		if is_instance_valid(pickup):
			interaction_label.text = "[ E ] PICK UP %s" % pickup.weapon_id.to_upper()
			return
		var security_device := _get_nearby_security_device()
		if is_instance_valid(security_device):
			interaction_label.text = security_device.get_interaction_prompt()
			return
		interaction_label.text = "[ Q ] THROW %s" % player.get_equipped_weapon_name() if player.equipped_mode == "gun" else ""

func _connect_events() -> void:
	Events.ammo_updated.connect(_on_ammo_updated)
	Events.reload_started.connect(_on_reload_started)
	Events.reload_finished.connect(_on_reload_finished)
	Events.weapon_fired.connect(_on_weapon_fired)
	Events.door_impact.connect(_on_door_impact)
	Events.glass_shattered.connect(_on_glass_shattered)

func _on_door_impact(_world_position: Vector2, intensity: float) -> void:
	trauma_camera.add_trauma(clampf(intensity * 0.13, 0.04, 0.24))
	if intensity >= 1.4: _on_impact_flash_requested(Color(1.0, 0.92, 0.8, 0.18))

func _on_glass_shattered(_world_position: Vector2) -> void:
	trauma_camera.add_trauma(0.16)
	_on_impact_flash_requested(Color(0.72, 0.92, 1.0, 0.12))

func _on_ammo_updated(current: int, maximum: int, is_reloading: bool) -> void:
	if phase == "cleanup": return
	ammo_label.text = "RELOAD" if is_reloading else "%02d/%02d" % [current, maximum]

func _on_reload_started(_duration: float) -> void:
	if phase != "cleanup": detail_label.text = "RELOADING..."

func _on_reload_finished(_current: int, _maximum: int) -> void:
	if phase != "cleanup": detail_label.text = "NO WITNESSES."

func _on_weapon_fired(origin: Vector2, direction: Vector2, enemy_owned: bool, weapon_id: String) -> void:
	var data := AttackCatalog.get_gun_data(weapon_id)
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
	CleanupRegistry.reset()
	CorpseIncidentRegistry.reset()
	status_label.text = "AFTERMATH // " + level_title
	detail_label.text = "NO WITNESSES."
	if not doors_enabled and has_node("Doors"): $Doors.queue_free()
	player = PLAYER_SCENE.instantiate()
	player.global_position = player_spawn
	player.projectile_requested.connect(_on_projectile_requested)
	player.clean_requested.connect(_on_clean_requested)
	player.died.connect(_on_player_died)
	player.execution_impact.connect(_on_execution_impact)
	player.melee_impact.connect(_on_melee_impact)
	player.weapon_throw_requested.connect(_on_weapon_throw_requested)
	player.extraction_requested.connect(_on_extraction_requested)
	player.world_interaction_requested.connect(_on_world_interaction_requested)
	add_child(player)
	extraction_zone = EXTRACTION_ZONE_SCENE.instantiate() as ExtractionZone
	extraction_zone.global_position = player_spawn if extraction_position == Vector2.ZERO else extraction_position
	add_child(extraction_zone)
	extraction_zone.set_active(false)
	for index in enemy_spawns.size(): _spawn_enemy(enemy_spawns[index], index)
	started_enemy_count = enemy_spawns.size()
	remaining_enemies = started_enemy_count
	var security_devices := _get_security_devices()
	for device in security_devices:
		device.alarm_triggered.connect(_on_security_alarm)
		device.disabled.connect(_on_security_disabled)
	mission_tracker.configure(_get_mission_profile(), started_enemy_count, security_devices.size())
	detail_label.text = mission_tracker.profile.briefing
	_update_combat_objective_hud()

func _sync_ammo_ui() -> void:
	if is_instance_valid(player) and is_instance_valid(player.gun):
		Events.publish_ammo(player.gun.ammo, player.gun.max_ammo, player.gun.is_reloading)

func _spawn_enemy(pos: Vector2, patrol_index := -1) -> void:
	var enemy = ENEMY_SCENE.instantiate()
	enemy.projectile_requested.connect(_on_projectile_requested)
	enemy.died_at.connect(_on_enemy_died.bind(enemy))
	enemies_container.add_child(enemy)
	enemy.global_position = pos
	enemy.debug_draw_vision = vision_debug_enabled
	if patrol_index >= 0 and patrol_index < enemy_types.size(): enemy.configure_combat(enemy_types[patrol_index])
	if enemy.enemy_type == "gunner":
		var enemy_weapon_ids := ["pistol", "smg", "lmg"]
		var enemy_weapon_id: String = enemy.default_weapon_id if not enemy.default_weapon_id.is_empty() else enemy_weapon_ids[patrol_index % enemy_weapon_ids.size()]
		enemy.gun.set_gun_data(AttackCatalog.get_gun_data(enemy_weapon_id), true)
	if patrol_index in fixed_sentry_indices:
		enemy.configure_fixed_sentry()
	elif patrol_index >= 0 and patrol_index < enemy_patrol_offsets.size():
		enemy.configure_patrol(PackedVector2Array([pos, pos + enemy_patrol_offsets[patrol_index]]))

func _toggle_vision_debug() -> void:
	vision_debug_enabled = not vision_debug_enabled
	for enemy_node in get_tree().get_nodes_in_group("enemy"):
		enemy_node.debug_draw_vision = vision_debug_enabled
		enemy_node.queue_redraw()
	detail_label.text = "VISION DEBUG: %s" % ("ON" if vision_debug_enabled else "OFF")

func _toggle_screen_effects() -> void:
	screen_effects_enabled = not screen_effects_enabled
	var material := $RetroTreatment/Scanlines.material as ShaderMaterial
	material.set_shader_parameter("enable_effect", screen_effects_enabled)
	detail_label.text = "SCREEN FX: %s" % ("ON" if screen_effects_enabled else "OFF")

func _toggle_hue_cycle() -> void:
	hue_cycle_enabled = not hue_cycle_enabled
	var material := $TileMap/ExteriorBackdrop.material as ShaderMaterial
	material.set_shader_parameter("enable_cycle", hue_cycle_enabled)
	detail_label.text = "HUE CYCLE: %s" % ("ON" if hue_cycle_enabled else "OFF")

func _on_projectile_requested(origin: Vector2, direction: Vector2, enemy_owned: bool, damage: int, weapon_id: String) -> void:
	if phase != "combat" or run_over: return
	var data := AttackCatalog.get_gun_data(weapon_id)
	var bullet = BULLET_SCENE.instantiate()
	bullet.global_position = origin
	bullet.blood_impact.connect(_on_blood_impact)
	bullet.setup(direction, enemy_owned, damage, weapon_id, origin, data.bullet_speed)
	add_child(bullet)
	trauma_camera.add_trauma(data.camera_shake * (0.1 if enemy_owned else 0.14))

func _on_enemy_died(pos: Vector2, facing: float, defeated_enemy: Node = null) -> void:
	enemies_killed += 1
	remaining_enemies = maxi(0, remaining_enemies - 1)
	mission_tracker.record_enemy_eliminated()
	combo += 1
	combo_timer = 2.2
	trauma_camera.trigger_kill_effect(0.72, "red")
	var corpse = CORPSE_SCENE.instantiate()
	corpse.global_position = pos
	corpse.setup(facing, pending_death_direction, pending_death_knockback, pending_death_blood_power, pending_death_style)
	add_child(corpse)
	blood_system.spawn_death_pool(pos, pending_death_blood_power)
	if is_instance_valid(defeated_enemy) and defeated_enemy.enemy_type == "gunner":
		var remaining_rounds: int = defeated_enemy.gun.ammo
		if remaining_rounds > 0:
			_spawn_weapon_pickup(pos, defeated_enemy.gun.weapon_id, remaining_rounds)
	pending_death_style = "firearm"
	_update_combat_objective_hud()

func _get_mission_profile() -> MissionProfile:
	if mission_profile != null: return mission_profile
	var fallback := MissionProfile.new()
	fallback.display_name = level_title
	return fallback

func _get_security_devices() -> Array[SecurityCamera]:
	var devices: Array[SecurityCamera] = []
	for node in get_tree().get_nodes_in_group("security_device"):
		if node is SecurityCamera and is_ancestor_of(node): devices.append(node)
	return devices

func _get_nearby_security_device() -> SecurityCamera:
	if not is_instance_valid(player): return null
	var nearest: SecurityCamera
	var nearest_distance := INF
	for device in _get_security_devices():
		if device.is_offline: continue
		var distance := player.global_position.distance_squared_to(device.global_position)
		if distance <= device.interaction_range * device.interaction_range and distance <= nearest_distance:
			nearest = device
			nearest_distance = distance
	return nearest

func _on_world_interaction_requested() -> void:
	if phase != "combat" or run_over: return
	var device := _get_nearby_security_device()
	if is_instance_valid(device): device.interact(player)

func _on_security_alarm(_camera: SecurityCamera, _player_position: Vector2) -> void:
	if phase != "combat" or run_over: return
	mission_tracker.record_alarm_trigger()
	detail_label.text = "SECURITY BREACH // POSITION COMPROMISED"
	trauma_camera.add_trauma(0.22)
	_on_impact_flash_requested(Color(1.0, 0.05, 0.18, 0.18))

func _on_security_disabled(_camera: SecurityCamera) -> void:
	if phase != "combat" or run_over: return
	mission_tracker.record_security_shutdown()
	detail_label.text = "SECURITY NODE OFFLINE"
	_update_combat_objective_hud()

func _update_combat_objective_hud() -> void:
	if phase != "combat" or run_over: return
	status_label.text = "MISSION // " + mission_tracker.profile.display_name if mission_tracker.profile != null else "MISSION // " + level_title
	hud.set_objective(mission_tracker.get_status_line() + " // ALARMS %d" % mission_tracker.alarm_triggers)

func _spawn_weapon_pickup(world_position: Vector2, weapon_id: String, rounds: int) -> void:
	var pickup = WEAPON_PICKUP_SCENE.instantiate()
	pickup.global_position = world_position + Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0))
	pickup.rotation = randf_range(-PI, PI)
	pickup.setup(weapon_id, rounds)
	add_child(pickup)

func _on_weapon_throw_requested(origin: Vector2, direction: Vector2, weapon_id: String, rounds: int) -> void:
	if phase != "combat" or run_over: return
	var thrown_weapon := THROWN_WEAPON_SCENE.instantiate()
	thrown_weapon.global_position = origin
	thrown_weapon.setup(direction, weapon_id, rounds)
	add_child(thrown_weapon)

func _on_blood_impact(hit_position: Vector2, direction: Vector2, damage: int, weapon_id: String, travel_distance: float, lethal: bool) -> void:
	blood_system.emit_hit(hit_position, direction, damage, weapon_id, travel_distance, lethal)
	if lethal:
		var data := AttackCatalog.get_gun_data(weapon_id)
		pending_death_direction = direction
		pending_death_knockback = data.knockback
		pending_death_blood_power = data.blood_power
		pending_death_style = data.death_style
		_trigger_hit_stop(data.hit_stop)

func _on_melee_impact(target: CharacterBody2D, hit_position: Vector2, direction: Vector2, melee_type: String, lethal: bool) -> void:
	if not is_instance_valid(target) or target.is_dead: return
	if not lethal:
		target.take_door_hit(direction, "knockdown")
		trauma_camera.add_trauma(0.16)
		return
	var profile := AttackCatalog.get_impact_profile(melee_type)
	pending_death_direction = direction
	pending_death_knockback = float(profile.knockback)
	pending_death_blood_power = float(profile.blood_power)
	pending_death_style = str(profile.style)
	blood_system.emit_hit(hit_position, direction, 1, melee_type, 0.0, true)
	trauma_camera.add_trauma(float(profile.trauma))
	_on_impact_flash_requested(Color(1.0, 0.06, 0.35, 0.2 if melee_type == "bat" else 0.13))
	_trigger_hit_stop(float(profile.hit_stop))
	target.take_damage(maxi(1, target.hp), hit_position - direction * 2.0)

func _on_execution_impact(hit_position: Vector2, direction: Vector2, lethal: bool, execution_type: String) -> void:
	var attack_id := execution_type if lethal else "fist"
	blood_system.emit_hit(hit_position, direction, 1, attack_id, 0.0, lethal)
	trauma_camera.add_trauma(0.42 if lethal else 0.2)
	if lethal:
		var profile := AttackCatalog.get_impact_profile(execution_type)
		pending_death_direction = direction
		pending_death_knockback = float(profile.knockback)
		pending_death_blood_power = float(profile.blood_power)
		pending_death_style = str(profile.style)
		_on_impact_flash_requested(Color(0.9, 0.02, 0.12, 0.28))
		_trigger_hit_stop(float(profile.hit_stop))

func _trigger_hit_stop(duration: float) -> void:
	combat_feedback.trigger_hit_stop(duration)

func _on_player_died() -> void:
	run_over = true
	trauma_camera.add_trauma(1.0)
	_trigger_death_flash()
	status_label.text = "YOU ARE DEAD"
	detail_label.text = "R TO RESTART"

func _trigger_death_flash() -> void:
	_show_flash(Color(0.85, 0.03, 0.08, 0.48), 0.22)

func _on_impact_flash_requested(color: Color) -> void:
	_show_flash(color, 0.12)

func _show_flash(color: Color, duration: float) -> void:
	combat_feedback.show_flash(color, duration)

func _exit_tree() -> void:
	if is_instance_valid(combat_feedback): combat_feedback.reset()

func _enter_cleanup_phase() -> void:
	phase = "cleanup"
	player.set_cleanup_mode(true)
	for bullet in get_tree().get_nodes_in_group("bullet"): bullet.queue_free()
	status_label.text = "CLEANUP REQUIRED"
	detail_label.text = "GET CLOSE // HOLD LMB"
	hud.set_objective("OBJECTIVES COMPLETE // ERASE ALL EVIDENCE")
	if is_instance_valid(extraction_zone): extraction_zone.set_active(true)

func _begin_cleanup_transition() -> void:
	transitioning_cleanup = true
	await get_tree().create_timer(0.42, true, false, true).timeout
	if not is_inside_tree() or run_over: return
	Events.combat_ended.emit()
	_enter_cleanup_phase()

func _on_clean_requested(world_position: Vector2) -> void:
	if phase != "cleanup" or run_over: return
	if player.global_position.distance_to(world_position) > 33.0: return
	var target := CleanupRegistry.get_nearest_target(world_position, 15.0)
	if not is_instance_valid(target): return
	var cleanup_type := str(target.get_cleanup_type()) if target.has_method("get_cleanup_type") else "unknown"
	if target.has_method("apply_cleanup_tool") and target.apply_cleanup_tool(player.current_cleanup_tool): return
	var steps: int = int(player.get_cleanup_efficiency(cleanup_type))
	for index in range(steps):
		if not is_instance_valid(target) or target.is_queued_for_deletion(): break
		target.clean_step()
	ammo_label.text = player.current_cleanup_tool.to_upper().replace("_", " ")

func _deposit_bagged_corpses() -> void:
	if not is_instance_valid(extraction_zone): return
	for corpse_node in get_tree().get_nodes_in_group("corpse"):
		if not is_instance_valid(corpse_node) or not corpse_node.has_method("is_bagged") or not corpse_node.is_bagged(): continue
		if extraction_zone.contains_position(corpse_node.global_position, 15.0): corpse_node.extract_bag()

func _on_extraction_requested() -> void:
	if phase != "cleanup" or run_over or not is_instance_valid(extraction_zone): return
	if not extraction_zone.contains_position(player.global_position): return
	_finish_run(CleanupRegistry.get_remaining_count() > 0)

func _finish_run(left_evidence: bool) -> void:
	if run_over: return
	run_over = true
	var cleanup_ratio := CleanupRegistry.get_cleanup_ratio()
	var time_bonus := maxi(0, 500 - roundi(elapsed * 3.0))
	final_score = maxi(0, roundi(cleanup_ratio * 1000.0) + enemies_killed * 100 + time_bonus + mission_tracker.get_score_modifier())
	var alarm_performance := maxf(0.0, 1.0 - mission_tracker.alarm_triggers * 0.15)
	var mission_rating := cleanup_ratio * 0.75 + alarm_performance * 0.25
	if cleanup_ratio >= 0.999 and mission_tracker.alarm_triggers == 0: final_grade = "S"
	elif mission_rating >= 0.9: final_grade = "A"
	elif mission_rating >= 0.75: final_grade = "B"
	elif mission_rating >= 0.5: final_grade = "C"
	else: final_grade = "D"
	status_label.text = "SCENE ABANDONED" if left_evidence else "SCENE CLEAN"
	detail_label.text = "GRADE %s // %04d PTS // %d ALARMS // R RESTART" % [final_grade, final_score, mission_tracker.alarm_triggers]
	hud.set_objective("MISSION COMPLETE // " + mission_tracker.get_status_line())
	interaction_label.text = "EVIDENCE LEFT // %d" % CleanupRegistry.get_remaining_value() if left_evidence else "PERFECT CLEANUP"
