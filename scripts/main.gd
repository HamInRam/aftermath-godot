extends Node2D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const ENEMY_SCRIPT := preload("res://scripts/enemy.gd")
const BULLET_SCENE := preload("res://scenes/bullet.tscn")
const CORPSE_SCENE := preload("res://scenes/corpse.tscn")
const SHELL_CASING_SCENE := preload("res://scenes/effects/shell_casing.tscn")
const MUZZLE_FLASH_SCENE := preload("res://scenes/effects/muzzle_flash.tscn")
const WEAPON_PICKUP_SCENE := preload("res://scenes/props/weapon_pickup.tscn")
const AMMO_PICKUP_SCENE := preload("res://scenes/props/ammo_pickup.tscn")
const PLAYTEST_TELEMETRY := preload("res://scripts/controllers/playtest_telemetry.gd")
const THROWN_WEAPON_SCENE := preload("res://scenes/props/thrown_weapon.tscn")
const EXTRACTION_ZONE_SCENE := preload("res://scenes/props/extraction_zone.tscn")
const UI_DEFAULTS := preload("res://utility/scripts/ui_defaults.gd")
const CLEANING_WET_MARK := preload("res://scripts/effects/cleaning_wet_mark.gd")
const SCENE_SECRET := preload("res://scripts/props/scene_secret.gd")
const RESETTABLE_FURNITURE := preload("res://scripts/props/resettable_furniture.gd")
const CORPSE_DISPOSAL := preload("res://scripts/props/corpse_disposal.gd")
const NOISE_LURE := preload("res://scripts/props/noise_lure.gd")
const LEVEL_LANDMARK := preload("res://scripts/world/level_landmark.gd")
const SWING_DOOR_SCENE := preload("res://scenes/props/swing_door.tscn")
const WORLD_CONTEXT_MARKER := preload("res://scripts/ui/world_context_marker.gd")
const GAMEPLAY_RULES := preload("res://utility/gameplay_design_rules.gd")
const RAGDOLL_IMPACT := preload("res://scripts/combat/ragdoll_impact_resolver.gd")

@export var level_title := "FLOOR 01"
@export var player_spawn := Vector2(44, 100)
@export var enemy_spawns := PackedVector2Array([Vector2(52, 52), Vector2(52, 180), Vector2(132, 52), Vector2(204, 76), Vector2(236, 132), Vector2(300, 52), Vector2(340, 92), Vector2(140, 188), Vector2(228, 188), Vector2(340, 188)])
@export var enemy_patrol_offsets := PackedVector2Array([Vector2(0, 40), Vector2(48, 0), Vector2(0, 40), Vector2(-48, 0), Vector2(48, 0), Vector2(0, 48), Vector2(0, 40), Vector2(56, 0), Vector2(0, -48), Vector2(-48, 0)])
@export var enemy_types := PackedStringArray(["melee", "gunner", "melee", "assault", "gunner", "gunner", "dog", "melee", "gunner", "heavy"])
@export var fixed_sentry_indices := PackedInt32Array()
@export var ammo_pickup_positions := PackedVector2Array([Vector2(76, 108), Vector2(164, 132), Vector2(300, 132), Vector2(340, 204)])
@export var ammo_pickup_weapon_ids := PackedStringArray(["pistol", "smg", "lmg", "shotgun"])
@export var ammo_pickup_rounds := PackedInt32Array([12, 24, 30, 8])
@export var doors_enabled := true
@export var extraction_position := Vector2.ZERO
@export var disposal_positions := PackedVector2Array()
@export var disposal_types := PackedStringArray()
@export var cleanup_secret_positions := PackedVector2Array()
@export var cleanup_secret_types := PackedStringArray()
@export var cleanup_furniture_positions := PackedVector2Array()
@export var tactical_lure_positions := PackedVector2Array()
@export var mission_profile: MissionProfile
@export var record_progress := true
@export_enum("neon", "industrial", "ice", "gold", "police", "crimson", "broadcast", "finale") var visual_theme := "neon"

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
var pending_death_hit_zone := "torso"
var pending_death_hit_position := Vector2.ZERO
var pending_death_attack_id := "pistol"
var pending_death_travel_distance := 0.0
var pending_player_death_context: Dictionary = {}
var player_death_corpse: Node2D
var transitioning_cleanup := false
var vision_debug_enabled := false
var screen_effects_enabled := true
var hue_cycle_enabled := true
var extraction_zone: ExtractionZone
var corpse_disposals: Array[CorpseDisposal] = []
var tactical_lures: Array[NoiseLure] = []
var mission_tracker := MissionTracker.new()
var final_score := 0
var final_grade := ""
var interaction_scan_timer := 0.0
var cleanup_scan_timer := 0.0
var combat_hud_timer := 0.0
var security_devices: Array[SecurityCamera] = []
var security_devices_cached := false
var performance_debug_enabled := false
var current_ammo := 0
var current_capacity := 0
var current_reserve := -1
var combat_shots_fired := 0
var player_shot_records: Dictionary = {}
var precision_reward_bonus := 0
var combat_glass_broken := 0
var combat_doors_slammed := 0
var cleanup_footprints_created := 0
var combat_completion_hold := 0.0
var last_cleanup_risk := -1
var scene_certified_announced := false
var last_player_death_cause := "CONTACT"
var clues_collected := 0
var valuables_secured := 0
var valuables_stolen := 0
var furniture_restored := 0
var cleanup_opportunities_spawned := false
var cleanup_time_remaining := 0.0
var cleanup_pressure_active := false
var cleanup_timed_out := false
var ultraviolet_was_active := false
var ultraviolet_materials: Dictionary = {}
var ultraviolet_shader_material: ShaderMaterial
var pause_layer: CanvasLayer
var active_modifier: Dictionary = {}
var route_anchor := Vector2.ZERO
var combat_route_distance := 0.0
var cleanup_route_distance := 0.0
var combat_phase_elapsed := 0.0
var cleanup_phase_elapsed := 0.0
var playtest_telemetry: Node
var verified_cleanup_rooms: Dictionary = {}
var world_context_marker: WorldContextMarker
@onready var blood_system = $BloodSystem
@onready var enemies_container: Node2D = $Enemies
@onready var trauma_camera = $TraumaCamera

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	CombatDirector.reset_kill_zones()
	RenderingServer.set_default_clear_color(Color("0e0c10"))
	_create_ui()
	world_context_marker = WORLD_CONTEXT_MARKER.new() as WorldContextMarker
	add_child(world_context_marker)
	combat_feedback = CombatFeedback.new()
	add_child(combat_feedback)
	combat_feedback.configure($DeathPresentation/Flash, Settings.flash_intensity)
	playtest_telemetry = PLAYTEST_TELEMETRY.new()
	add_child(playtest_telemetry)
	screen_effects_enabled = Settings.screen_effects_enabled
	($RetroTreatment/Scanlines.material as ShaderMaterial).set_shader_parameter("enable_effect", screen_effects_enabled)
	($RetroTreatment/Scanlines.material as ShaderMaterial).set_shader_parameter("chromatic_aberration", 0.00025 * Settings.chromatic_aberration_strength)
	_connect_events()
	trauma_camera.impact_flash_requested.connect(_on_impact_flash_requested)
	_configure_level_lighting()
	_apply_visual_theme()
	_apply_pixel_light_textures()
	_start_run()
	call_deferred("_sync_ammo_ui")

func _extend_tactical_lab_lighting() -> void:
	var tile_world := get_node_or_null("TileMap")
	if not is_instance_valid(tile_world) or tile_world.layout_id != "tactical_lab" or tile_world.map_size.x <= 48: return
	var lighting := get_node_or_null("Lighting")
	if not is_instance_valid(lighting) or lighting.get_child_count() == 0: return
	var positions := [Vector2(420, 62), Vector2(462, 178), Vector2(304, 250), Vector2(454, 250)]
	var colors := [Color(0.12, 0.78, 1.0), Color(1.0, 0.16, 0.46), Color(0.95, 0.48, 0.12), Color(0.35, 1.0, 0.58)]
	for index in range(positions.size()):
		var source := lighting.get_child(index % lighting.get_child_count())
		var light := source.duplicate() as PointLight2D
		light.name = "TacticalExtensionLight%d" % index
		light.position = positions[index]
		light.color = colors[index]
		light.energy *= 0.86
		lighting.add_child(light)

func _configure_level_lighting() -> void:
	var world := get_node_or_null("TileMap")
	var lighting := get_node_or_null("Lighting")
	if not is_instance_valid(world) or not world.has_method("get_light_positions") or not is_instance_valid(lighting) or lighting.get_child_count() == 0: return
	var positions: Array[Vector2] = world.get_light_positions()
	if positions.is_empty(): return
	var source := lighting.get_child(0) as PointLight2D
	while lighting.get_child_count() < positions.size():
		var copy := source.duplicate() as PointLight2D
		copy.name = "RoomLight%d" % lighting.get_child_count()
		lighting.add_child(copy)
	for index in range(lighting.get_child_count()):
		var light := lighting.get_child(index) as PointLight2D
		light.visible = index < positions.size()
		if index < positions.size():
			light.position = positions[index]
			light.energy = 0.42 + float(index % 2) * 0.1
			if light.get_script() != null:
				light.set("base_energy", light.energy)
				light.set("wave_amplitude", 0.035)

func _apply_pixel_light_textures() -> void:
	var lighting := get_node_or_null("Lighting")
	if not is_instance_valid(lighting): return
	for node in lighting.get_children():
		if node is not PointLight2D: continue
		var light := node as PointLight2D
		light.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		light.texture_scale = 1.0

func _apply_visual_theme() -> void:
	var world := get_node_or_null("TileMap")
	var variant := str(world.get("layout_variant")) if is_instance_valid(world) else visual_theme
	var palettes := {
		"nightclub": [Color("d7ced0"), Color("bd294b"), Color("328f89"), Color("e6e1dc")],
		"sandwich_shop": [Color("ddd3c2"), Color("b85e35"), Color("4a8c79"), Color("ebe5d9")],
		"tactical_lab": [Color("ced7da"), Color("466f9d"), Color("b33448"), Color("e2e7e5")],
		"harbor_exchange": [Color("d1cdc3"), Color("aa673d"), Color("3e8188"), Color("e7e2d8")],
		"motel_witness": [Color("d8c9cd"), Color("b73b6b"), Color("428e88"), Color("e9e1e3")],
		"penthouse": [Color("ddd2bd"), Color("b98b43"), Color("b84060"), Color("ebe5d7")],
		"cold_storage": [Color("cfdbde"), Color("4e91aa"), Color("83b4b9"), Color("e5eaea")],
		"casino_floor": [Color("d9cdc2"), Color("b1843f"), Color("ae314b"), Color("e9e1da")],
		"police_archive": [Color("ced4dc"), Color("496b9a"), Color("ad3545"), Color("e3e6e7")],
		"slaughterhouse": [Color("d8cac7"), Color("b6293a"), Color("a97638"), Color("e9dedb")],
		"broadcast_tower": [Color("cad8ce"), Color("4d9569"), Color("76528d"), Color("e1e8e2")],
		"last_call": [Color("d7c7cd"), Color("b71f45"), Color("398b91"), Color("e8dfe2")],
	}
	var palette: Array = palettes.get(variant, palettes.nightclub)
	var canvas := get_node_or_null("CanvasModulate") as CanvasModulate
	if is_instance_valid(canvas): canvas.color = palette[0]
	if is_instance_valid(world):
		world.floor_layer.modulate = palette[3]
		world.wall_layer.modulate = Color(0.98, 0.97, 0.94, 1.0)
		world.decoration_layer.modulate = Color(0.72, 0.73, 0.72, 1.0)
	var lighting := get_node_or_null("Lighting")
	if is_instance_valid(lighting):
		for index in range(lighting.get_child_count()):
			var light := lighting.get_child(index) as PointLight2D
			if is_instance_valid(light): light.color = palette[1 + index % 2]

func _process(delta: float) -> void:
	if get_tree().paused: return
	elapsed += delta
	if phase == "combat": combat_phase_elapsed += delta
	elif phase == "cleanup": cleanup_phase_elapsed += delta
	if is_instance_valid(player):
		if route_anchor == Vector2.ZERO: route_anchor = player.global_position
		var route_step := player.global_position.distance_to(route_anchor)
		if route_step <= 24.0:
			if phase == "combat": combat_route_distance += route_step
			elif phase == "cleanup": cleanup_route_distance += route_step
		route_anchor = player.global_position
	combo_timer -= delta
	if combo_timer <= 0.0: combo = 0
	hud.set_combo(combo)
	if is_instance_valid(player) and is_instance_valid(player.gun):
		hud.set_weapon_aim_feedback(player.get_aim_feedback(), phase == "combat" and not run_over and player.equipped_mode == "gun")
	interaction_scan_timer -= delta
	if interaction_scan_timer <= 0.0:
		interaction_scan_timer = 0.08
		_update_interaction_prompt()
	if performance_debug_enabled: hud.set_performance(PerformanceMonitor.get_debug_line())
	if run_over: return
	_update_ultraviolet_mode()
	if phase == "combat":
		combat_hud_timer -= delta
		if combat_hud_timer <= 0.0:
			combat_hud_timer = 0.1
			_update_combat_objective_hud()
	if phase == "combat" and not transitioning_cleanup and mission_tracker.are_combat_objectives_complete():
		combat_completion_hold += delta
		if combat_completion_hold >= 0.22: _begin_cleanup_transition()
	elif phase == "combat":
		combat_completion_hold = 0.0
	elif phase == "cleanup":
		if cleanup_pressure_active:
			cleanup_time_remaining = maxf(0.0, cleanup_time_remaining - delta)
			if cleanup_time_remaining <= 0.0:
				cleanup_timed_out = true
				cleanup_pressure_active = false
				_finish_run(true)
				return
		hud.set_cleanup_tool(player.current_cleanup_tool, player.get_mop_saturation_ratio())
		cleanup_scan_timer -= delta
		if cleanup_scan_timer <= 0.0:
			cleanup_scan_timer = 0.1
			_deposit_bagged_corpses()
			var remaining_cleanup := CleanupRegistry.get_remaining_count()
			if remaining_cleanup == 0:
				_finish_run(false)
			else:
				var risk := CleanupRegistry.get_remaining_value()
				var tile_world := get_node_or_null("TileMap")
				var area := CleanupRegistry.get_room_summary(tile_world, player.global_position)
				var room_name := str(area.get("room_id", "area")).to_upper().replace("_", " ")
				var scene_cleanliness := CleanupRegistry.get_cleanup_ratio()
				hud.set_cleanup_summary(scene_cleanliness, risk, cleanup_time_remaining if cleanup_pressure_active else -1.0)
				var counts := CleanupRegistry.get_type_counts()
				var cleanup_tier: Dictionary = GAMEPLAY_RULES.get_cleanup_tier(scene_cleanliness)
				var scan_active: bool = player.ultraviolet_scan_time > 0.0 and Progression.get_cleaner_mode() == "normal"
				hud.set_cleanup_context(room_name, float(area.cleanliness), bool(cleanup_tier.can_extract), scan_active, counts, GAMEPLAY_RULES.get_cleanup_guidance(counts))
				if bool(cleanup_tier.can_extract) and not scene_certified_announced:
					scene_certified_announced = true
					hud.show_banner("SCENE CERTIFIED // EXIT AVAILABLE", Color("73f7e4"))
					detail_label.text = "90% SECURED // CONTINUE FOR PERFECT"
					_play_area_clean_feedback()
				# A room is complete at the same forgiving threshold used by modern
				# cleaning games: the last nearly invisible pixels are not busywork.
				if float(area.cleanliness) >= 0.95:
					if not verified_cleanup_rooms.has(room_name):
						verified_cleanup_rooms[room_name] = true
						combat_feedback.show_flash(Color(0.18, 1.0, 0.78, 0.16), 0.12)
						hud.set_objective("ROOM VERIFIED // %s" % room_name)
						hud.show_banner("AREA CLEAN // %s" % room_name)
						_play_area_clean_feedback()
				if last_cleanup_risk >= 0 and risk < last_cleanup_risk:
					combat_feedback.show_flash(Color(0.2, 0.9, 0.72, 0.08), 0.07)
				last_cleanup_risk = risk

func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		if event.is_action_pressed("ui_cancel"):
			_toggle_pause(false)
		elif event.is_action_pressed("ui_accept"):
			get_tree().paused = false
			SceneTransition.transition_to("res://scenes/ui/title_menu.tscn")
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F3:
		_toggle_vision_debug()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F4:
		_toggle_screen_effects()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F5:
		_toggle_hue_cycle()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F6:
		performance_debug_enabled = not performance_debug_enabled
		hud.set_performance(PerformanceMonitor.get_debug_line() if performance_debug_enabled else "")
		return
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause(true)
		return
	if run_over and event.is_action_pressed("reload"):
		get_tree().reload_current_scene()
		return
	if run_over and not final_grade.is_empty() and event.is_action_pressed("ui_accept"):
		SceneTransition.transition_to("res://scenes/ui/debrief_screen.tscn")

func _create_ui() -> void:
	hud = HudController.new()
	add_child(hud)
	status_label = hud.status_label
	detail_label = hud.detail_label
	ammo_label = hud.ammo_label
	combo_label = hud.combo_label
	interaction_label = hud.interaction_label

func _toggle_pause(enabled: bool) -> void:
	get_tree().paused = enabled
	if enabled:
		if not is_instance_valid(pause_layer):
			pause_layer = CanvasLayer.new()
			pause_layer.layer = 100
			pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
			var shade := ColorRect.new()
			shade.color = Color(0.02, 0.01, 0.035, 0.86)
			shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			pause_layer.add_child(shade)
			var pause_text := Label.new()
			pause_text.text = "PAUSED\n\n[ ESC ] RESUME\n[ ENTER ] QUIT TO MENU"
			pause_text.position = Vector2(64, 54)
			pause_text.size = Vector2(192, 80)
			pause_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			UI_DEFAULTS.apply_label(pause_text, 11, Color("fff1f7"))
			pause_layer.add_child(pause_text)
			add_child(pause_layer)
		pause_layer.visible = true
	elif is_instance_valid(pause_layer):
		pause_layer.visible = false

func _update_interaction_prompt() -> void:
	if run_over: return
	if not is_instance_valid(interaction_label) or not is_instance_valid(player) or player.is_executing:
		if is_instance_valid(interaction_label): interaction_label.text = ""
		if is_instance_valid(world_context_marker): world_context_marker.hide_target()
		return
	if phase == "cleanup":
		if is_instance_valid(player.dragged_restoration_prop): interaction_label.text = "[ E ] DROP OBJECT // ALIGN WITH CYAN OUTLINE"
		elif is_instance_valid(player.dragged_corpse) and is_instance_valid(_get_nearby_disposal()): interaction_label.text = _get_nearby_disposal().get_interaction_prompt()
		elif is_instance_valid(player.dragged_corpse): interaction_label.text = "[ E ] DROP BODY"
		elif is_instance_valid(extraction_zone) and extraction_zone.contains_position(player.global_position): interaction_label.text = "[ E ] LEAVE SCENE // RISK %d" % CleanupRegistry.get_remaining_value()
		elif _is_player_near_sink(): interaction_label.text = "[ E ] RINSE MOP // DIRTY %d%%" % roundi(player.get_mop_saturation_ratio() * 100.0)
		elif is_instance_valid(player.get_nearby_restoration_prop()): interaction_label.text = player.get_nearby_restoration_prop().get_interaction_prompt()
		elif is_instance_valid(player.get_nearby_draggable_corpse()):
			var corpse: Node2D = player.get_nearby_draggable_corpse()
			interaction_label.text = "[ E ] DRAG BAG" if corpse.is_bagged() else "[ E ] BAG BODY // %d%%" % roundi(corpse.get_cleanup_progress() * 100.0)
		elif is_instance_valid(_get_nearby_loose_evidence()):
			var batch_count := CleanupRegistry.get_targets_in_radius(player.global_position, 30.0, 12, PackedStringArray(["shell", "dropped_weapon", "debris"])).size()
			interaction_label.text = "[ E ] SECURE NEARBY EVIDENCE x%d" % batch_count
		elif is_instance_valid(_get_nearby_scene_secret()): interaction_label.text = _get_nearby_scene_secret().get_interaction_prompt() + " // OPTIONAL"
		elif is_instance_valid(_get_nearby_furniture()): interaction_label.text = _get_nearby_furniture().get_interaction_prompt() + " // OPTIONAL"
		else:
			var nearby_cleanup := CleanupRegistry.get_nearest_target(player.global_position, 24.0)
			if is_instance_valid(nearby_cleanup):
				var cleanup_type := str(nearby_cleanup.get_cleanup_type()) if nearby_cleanup.has_method("get_cleanup_type") else "unknown"
				var required_tool := _required_cleanup_tool(cleanup_type)
				var progress := float(nearby_cleanup.get_cleanup_progress()) if nearby_cleanup.has_method("get_cleanup_progress") else 0.0
				interaction_label.text = "[ LMB ] %s %d%%" % [required_tool.to_upper().replace("_", " "), roundi(progress * 100.0)]
			else: interaction_label.text = ""
		_update_world_context_marker()
		return
	if phase != "combat":
		interaction_label.text = ""
		if is_instance_valid(world_context_marker): world_context_marker.hide_target()
		return
	if is_instance_valid(player.peek_nearby_execution_target()):
		interaction_label.text = "[ SPACE ] EXECUTE"
	else:
		var pickup = player.get_nearby_weapon_pickup()
		if is_instance_valid(pickup):
			interaction_label.text = "[ E ] PICK UP %s" % pickup.weapon_id.to_upper()
		else:
			var security_device := _get_nearby_security_device()
			if is_instance_valid(security_device): interaction_label.text = security_device.get_interaction_prompt()
			else:
				var lure := _get_nearby_noise_lure()
				if is_instance_valid(lure): interaction_label.text = lure.get_interaction_prompt()
				else: interaction_label.text = "[ Q ] THROW %s" % player.get_equipped_weapon_name() if player.equipped_mode == "gun" else ""
	_update_world_context_marker()

func _update_world_context_marker() -> void:
	if not is_instance_valid(world_context_marker): return
	var target: Node2D
	var kind := "interact"
	var color := Color("fff0a8")
	var progress := -1.0
	if phase == "combat":
		target = player.peek_nearby_execution_target()
		if is_instance_valid(target): kind = "execute"; color = Color("ff536e")
		else:
			target = player.get_nearby_weapon_pickup()
			if is_instance_valid(target): kind = "weapon"; color = Color("ffe5a8")
			else:
				target = _get_nearby_security_device()
				if is_instance_valid(target): kind = "target"; color = Color("82d8ff")
				else: target = _get_nearby_noise_lure()
	else:
		if is_instance_valid(player.dragged_restoration_prop):
			target = player.dragged_restoration_prop.get_restoration_anchor()
			kind = "target"
			color = Color("73f7e4")
		else: target = player.get_nearby_restoration_prop()
		if is_instance_valid(target) and (is_instance_valid(player.dragged_restoration_prop) or target.is_in_group("displaced_prop")):
			kind = "target"
			color = Color("73f7e4")
		else:
			target = player.get_nearby_draggable_corpse()
		if is_instance_valid(target):
			if target.is_in_group("corpse"):
				kind = "bag" if target.is_bagged() else "body"
				progress = target.get_cleanup_progress()
		else:
			target = _get_nearby_loose_evidence()
			if is_instance_valid(target): kind = "evidence"; color = Color("82d8ff")
			else:
				target = CleanupRegistry.get_nearest_target(player.global_position, 24.0)
				if is_instance_valid(target):
					var cleanup_type := str(target.get_cleanup_type()) if target.has_method("get_cleanup_type") else "blood"
					kind = "blood" if cleanup_type in ["blood", "blood_pool", "blood_footprint", "gore", "spill"] else "clean"
					color = Color("c77dff") if player.ultraviolet_scan_time > 0.0 else Color("73f7e4")
					progress = target.get_cleanup_progress() if target.has_method("get_cleanup_progress") else -1.0
	if is_instance_valid(target): world_context_marker.show_target(target.global_position, kind, color, progress)
	else: world_context_marker.hide_target()

func _connect_events() -> void:
	Events.ammo_updated.connect(_on_ammo_updated)
	Events.ammo_reserve_updated.connect(_on_ammo_reserve_updated)
	Events.reload_started.connect(_on_reload_started)
	Events.reload_finished.connect(_on_reload_finished)
	Events.weapon_fired.connect(_on_weapon_fired)
	Events.precision_reward.connect(_on_precision_reward)
	Events.door_impact.connect(_on_door_impact)
	Events.glass_shattered.connect(_on_glass_shattered)
	Events.prop_destroyed.connect(_on_prop_destroyed)
	Events.prop_restored.connect(_on_prop_restored)
	Events.prop_impacted.connect(_on_prop_impacted)
	Events.hazard_spawned.connect(_on_hazard_spawned)
	Events.setpiece_triggered.connect(_on_setpiece_triggered)

func _on_door_impact(_world_position: Vector2, intensity: float) -> void:
	if phase == "combat" and intensity >= 1.4:
		combat_doors_slammed += 1
		mission_tracker.record_property_damage()
		_show_scene_consequence("PROPERTY +1 // FORCED ENTRY")
	trauma_camera.add_trauma(clampf(intensity * 0.13, 0.04, 0.24))
	if intensity >= 1.4: _on_impact_flash_requested(Color(1.0, 0.92, 0.8, 0.18))

func _on_glass_shattered(_world_position: Vector2) -> void:
	if phase == "combat":
		combat_glass_broken += 1
		mission_tracker.record_property_damage()
		_show_scene_consequence("PROPERTY +1 // GLASS TRACE")
	trauma_camera.add_trauma(0.16)
	_on_impact_flash_requested(Color(0.72, 0.92, 1.0, 0.12))

func _on_prop_destroyed(_world_position: Vector2, prop_kind: String) -> void:
	if phase == "combat": mission_tracker.record_property_damage()
	trauma_camera.add_trauma(0.1 if prop_kind in ["plant", "toilet", "sink"] else 0.16)
	_show_scene_consequence("PROPERTY +1 // %s" % prop_kind.to_upper().replace("_", " "))

func _on_prop_restored(_world_position: Vector2, prop_kind: String) -> void:
	if phase != "cleanup": return
	furniture_restored += 1
	detail_label.text = "%s RESET // OBJECTS RESTORED %d" % [prop_kind.to_upper().replace("_", " "), furniture_restored]

func _show_scene_consequence(text: String) -> void:
	if phase != "combat" or run_over: return
	detail_label.text = "SCENE COST // " + text

func _on_prop_impacted(_world_position: Vector2, material: String, energy: float, structural_stage: int) -> void:
	if energy >= 1.15:
		_trigger_hit_stop(clampf(0.012 + energy * 0.009, 0.018, 0.042))
	trauma_camera.add_trauma(clampf(energy * 0.035, 0.015, 0.12))
	_play_material_impact(_world_position, material, energy)
	if structural_stage == 1: detail_label.text = "%s STRUCTURE COMPROMISED" % material.to_upper()

func _play_material_impact(world_position: Vector2, material: String, energy: float) -> void:
	if DisplayServer.get_name() == "headless": return
	var player_2d := AudioStreamPlayer2D.new()
	player_2d.stream = ProceduralAudioLibrary.get_sfx("impact_%s" % material)
	player_2d.volume_db = lerpf(-12.0, -2.0, clampf(energy / 2.0, 0.0, 1.0))
	player_2d.pitch_scale = randf_range(0.9, 1.1)
	player_2d.max_distance = 420.0
	add_child(player_2d)
	player_2d.global_position = world_position
	player_2d.finished.connect(player_2d.queue_free)
	player_2d.play()

func _play_area_clean_feedback() -> void:
	if DisplayServer.get_name() == "headless": return
	var feedback := AudioStreamPlayer.new()
	feedback.stream = ProceduralAudioLibrary.get_sfx("area_clean")
	feedback.volume_db = -7.0
	add_child(feedback)
	feedback.finished.connect(feedback.queue_free)
	feedback.play()

func _on_hazard_spawned(_world_position: Vector2, hazard_kind: String) -> void:
	detail_label.text = "%s HAZARD // ISOLATE SOURCE BEFORE CLEANING" % hazard_kind.to_upper()

func _on_setpiece_triggered(_world_position: Vector2, setpiece_kind: String, hazard_kind: String) -> void:
	_trigger_hit_stop(0.045)
	trauma_camera.add_trauma(0.38)
	_on_impact_flash_requested(Color(1.0, 0.72, 0.32, 0.2))
	detail_label.text = "%s CHAIN REACTION // %s" % [setpiece_kind.to_upper().replace("_", " "), hazard_kind.to_upper()]
	if setpiece_kind in ["dj_booth", "broken_dj", "motel_sign"]:
		var lighting := get_node_or_null("Lighting")
		if is_instance_valid(lighting):
			for light in lighting.get_children():
				if light is PointLight2D: create_tween().tween_property(light, "energy", light.energy * 0.45, 0.18)
	elif setpiece_kind == "broadcast_console":
		for camera in _get_security_devices():
			camera.disable()

func _on_ammo_updated(current: int, maximum: int, is_reloading: bool) -> void:
	if phase == "cleanup": return
	current_ammo = current
	current_capacity = maximum
	ammo_label.text = "RELOAD" if is_reloading else _format_ammo()

func _on_ammo_reserve_updated(reserve: int) -> void:
	current_reserve = reserve
	if phase != "cleanup" and is_instance_valid(ammo_label): ammo_label.text = _format_ammo()

func _format_ammo() -> String:
	return "%02d/%02d  +%s" % [current_ammo, current_capacity, "∞" if current_reserve < 0 else "%02d" % current_reserve]

func _on_reload_started(_duration: float) -> void:
	if phase != "cleanup": detail_label.text = "RELOADING..."

func _on_reload_finished(_current: int, _maximum: int) -> void:
	if phase != "cleanup": detail_label.text = "NO WITNESSES."

func _on_weapon_fired(origin: Vector2, direction: Vector2, enemy_owned: bool, weapon_id: String) -> void:
	if not enemy_owned:
		combat_shots_fired += 1
		mission_tracker.record_player_shot(weapon_id)
		_show_scene_consequence("BALLISTIC +1 // %s" % weapon_id.to_upper())
		var shot_id: int = player.gun.current_shot_id if is_instance_valid(player) and is_instance_valid(player.gun) else -1
		if shot_id >= 0:
			var shot_data := AttackCatalog.get_gun_data(weapon_id)
			player_shot_records[shot_id] = {
				"expected": maxi(1, shot_data.pellet_count),
				"resolved": 0,
				"hit": false,
				"lethal": false,
				"reported": false,
				"weapon_id": weapon_id,
			}
	var data := AttackCatalog.get_gun_data(weapon_id)
	trauma_camera.add_trauma(data.camera_shake * (0.1 if enemy_owned else 0.14))
	var casing = SHELL_CASING_SCENE.instantiate()
	if RuntimeBudget.try_add("shell", casing, self):
		var perpendicular := direction.rotated(PI * 0.5)
		casing.global_position = origin - direction * randf_range(4.5, 7.5) + perpendicular * randf_range(-1.8, 1.8)
		casing.rotation = randf_range(-PI, PI)
		casing.setup(direction, enemy_owned)
	var flash = MUZZLE_FLASH_SCENE.instantiate()
	flash.position = to_local(origin)
	flash.setup(direction, data.muzzle_flash_size, data.muzzle_flash_duration)
	RuntimeBudget.try_add("transient_fx", flash, self)

func _on_precision_reward(weapon_id: String, streak: int) -> void:
	if phase != "combat" or run_over: return
	precision_reward_bonus += 120
	hud.show_banner("CLEAN MAG // FAST RELOAD ARMED", Color("ff68c8"))
	detail_label.text = "%s PRECISION x%d // EMPTY MAG RELOAD BOOST" % [weapon_id.to_upper(), streak]

func _start_run() -> void:
	CleanupRegistry.reset()
	CorpseIncidentRegistry.reset()
	player_shot_records.clear()
	precision_reward_bonus = 0
	scene_certified_announced = false
	last_player_death_cause = "CONTACT"
	pending_player_death_context.clear()
	player_death_corpse = null
	_configure_run_modifier()
	status_label.text = "AFTERMATH // " + level_title
	detail_label.text = "NO WITNESSES."
	if not doors_enabled and has_node("Doors"): $Doors.queue_free()
	player = PLAYER_SCENE.instantiate()
	var world := get_node_or_null("TileMap")
	_configure_level_doors(world)
	_configure_security_layout(world)
	var resolved_player_spawn := player_spawn
	if is_instance_valid(world) and world.has_method("get_nearest_walkable_position"):
		var candidate: Vector2 = world.get_nearest_walkable_position(player_spawn, 8)
		if candidate != Vector2.INF: resolved_player_spawn = candidate
	player.global_position = resolved_player_spawn
	player.projectile_requested.connect(_on_projectile_requested)
	player.clean_requested.connect(_on_clean_requested)
	player.cleaner_requested.connect(_on_cleaner_requested)
	player.died.connect(_on_player_died)
	player.execution_impact.connect(_on_execution_impact)
	player.melee_impact.connect(_on_melee_impact)
	player.weapon_throw_requested.connect(_on_weapon_throw_requested)
	player.extraction_requested.connect(_on_extraction_requested)
	player.world_interaction_requested.connect(_on_world_interaction_requested)
	add_child(player)
	player.configure_field_kit(LoadoutCatalog.get_kit(Progression.get_current_kit_id()))
	_spawn_level_landmarks(world)
	route_anchor = player.global_position
	extraction_zone = EXTRACTION_ZONE_SCENE.instantiate() as ExtractionZone
	var resolved_extraction := resolved_player_spawn if extraction_position == Vector2.ZERO else extraction_position
	if is_instance_valid(world) and world.has_method("get_nearest_walkable_position"):
		var extraction_candidate: Vector2 = world.get_nearest_walkable_position(resolved_extraction, 8)
		if extraction_candidate != Vector2.INF: resolved_extraction = extraction_candidate
	extraction_zone.global_position = resolved_extraction
	add_child(extraction_zone)
	extraction_zone.set_active(false)
	_spawn_corpse_disposals()
	_spawn_tactical_lures()
	for index in enemy_spawns.size(): _spawn_enemy(enemy_spawns[index], index)
	for index in ammo_pickup_positions.size(): _spawn_ammo_pickup(index)
	started_enemy_count = enemy_spawns.size()
	remaining_enemies = started_enemy_count
	security_devices = _get_security_devices()
	security_devices_cached = true
	for device in security_devices:
		device.alarm_triggered.connect(_on_security_alarm)
		device.disabled.connect(_on_security_disabled)
	mission_tracker.configure(_get_mission_profile(), started_enemy_count, security_devices.size())
	playtest_telemetry.begin_run(mission_tracker.profile.mission_id)
	if record_progress: Progression.current_mission_id = mission_tracker.profile.mission_id
	detail_label.text = mission_tracker.profile.briefing
	_update_combat_objective_hud()

func _configure_level_doors(world: Node) -> void:
	var doors_root := get_node_or_null("Doors")
	if not doors_enabled:
		if is_instance_valid(doors_root): doors_root.queue_free()
		return
	if not is_instance_valid(doors_root):
		doors_root = Node2D.new()
		doors_root.name = "Doors"
		add_child(doors_root)
	for child in doors_root.get_children(): child.queue_free()
	if not is_instance_valid(world) or not world.has_method("get_door_specs"): return
	for spec: Dictionary in world.get_door_specs():
		var door := SWING_DOOR_SCENE.instantiate()
		door.position = spec.position
		door.rotation = spec.rotation
		doors_root.add_child(door)

func _configure_security_layout(world: Node) -> void:
	if not is_instance_valid(world) or not world.has_method("get_security_specs"): return
	var specs: Array[Dictionary] = world.get_security_specs()
	var cameras: Array[SecurityCamera] = []
	for node in get_children():
		if node is SecurityCamera: cameras.append(node)
	for index in range(mini(cameras.size(), specs.size())):
		cameras[index].position = specs[index].position
		cameras[index].rotation = specs[index].rotation
		cameras[index].base_rotation = specs[index].rotation

func _sync_ammo_ui() -> void:
	if is_instance_valid(player) and is_instance_valid(player.gun):
		Events.publish_ammo(player.gun.ammo, player.gun.max_ammo, player.gun.is_reloading)

func _spawn_enemy(pos: Vector2, patrol_index := -1) -> void:
	var enemy = ENEMY_SCENE.instantiate()
	enemy.projectile_requested.connect(_on_projectile_requested)
	enemy.died_at.connect(_on_enemy_died.bind(enemy))
	enemies_container.add_child(enemy)
	var world := get_node_or_null("TileMap")
	var resolved_position := pos
	if is_instance_valid(world) and world.has_method("get_nearest_walkable_position"):
		var candidate: Vector2 = world.get_nearest_walkable_position(pos, 8)
		if candidate != Vector2.INF: resolved_position = candidate
	enemy.global_position = resolved_position
	enemy.debug_draw_vision = vision_debug_enabled
	var configured_type := enemy_types[patrol_index] if patrol_index >= 0 and patrol_index < enemy_types.size() else "gunner"
	if str(active_modifier.get("id", "standard")) == "armed_response" and patrol_index >= 0 and patrol_index % 3 == 1:
		configured_type = "heavy" if patrol_index % 2 == 1 else "assault"
	enemy.configure_combat(configured_type)
	if enemy.enemy_type == "gunner":
		var enemy_weapon_ids := ["pistol", "smg", "lmg"]
		var enemy_weapon_id: String = enemy.default_weapon_id if not enemy.default_weapon_id.is_empty() else enemy_weapon_ids[patrol_index % enemy_weapon_ids.size()]
		enemy.gun.set_gun_data(AttackCatalog.get_gun_data(enemy_weapon_id), true)
	if Progression.get_run_mode() == "new_game_plus":
		enemy.reaction_time_min = maxf(0.08, enemy.reaction_time_min * 0.68)
		enemy.reaction_time_max = maxf(enemy.reaction_time_min, enemy.reaction_time_max * 0.72)
		enemy.reaction_time *= 0.70
		enemy.chase_speed_multiplier *= 1.12
	if patrol_index in fixed_sentry_indices:
		enemy.configure_fixed_sentry()
	elif patrol_index >= 0 and patrol_index < enemy_patrol_offsets.size():
		var patrol_offset: Vector2 = enemy_patrol_offsets[patrol_index]
		if str(active_modifier.get("id", "standard")) != "standard":
			var route_variant := posmod((Progression.current_mission_id + ":" + str(patrol_index) + ":" + str(active_modifier.id)).hash(), 3)
			if route_variant == 1: patrol_offset = patrol_offset.rotated(PI * 0.5)
			elif route_variant == 2: patrol_offset = -patrol_offset
		var patrol_destination := resolved_position + patrol_offset
		if is_instance_valid(world) and world.has_method("get_nearest_walkable_position"):
			var patrol_candidate: Vector2 = world.get_nearest_walkable_position(patrol_destination, 8)
			if patrol_candidate != Vector2.INF: patrol_destination = patrol_candidate
		enemy.configure_patrol(PackedVector2Array([resolved_position, patrol_destination]))

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
	Settings.update_values({"screen_effects_enabled": screen_effects_enabled})
	detail_label.text = "SCREEN FX: %s" % ("ON" if screen_effects_enabled else "OFF")

func _toggle_hue_cycle() -> void:
	hue_cycle_enabled = not hue_cycle_enabled
	var material := $TileMap/ExteriorBackdrop.material as ShaderMaterial
	material.set_shader_parameter("enable_cycle", hue_cycle_enabled)
	detail_label.text = "HUE CYCLE: %s" % ("ON" if hue_cycle_enabled else "OFF")

func _on_projectile_requested(origin: Vector2, direction: Vector2, enemy_owned: bool, damage: int, weapon_id: String, shooter: CollisionObject2D = null) -> void:
	if phase != "combat" or run_over: return
	var data := AttackCatalog.get_gun_data(weapon_id)
	var bullet = BULLET_SCENE.instantiate()
	bullet.global_position = origin
	bullet.damage_impact.connect(_on_damage_impact)
	if not enemy_owned and is_instance_valid(player) and is_instance_valid(player.gun):
		bullet.shot_id = player.gun.current_shot_id
		bullet.shot_resolved.connect(_on_player_shot_resolved)
	bullet.setup(direction, enemy_owned, damage, weapon_id, origin, data.bullet_speed, shooter)
	if not RuntimeBudget.try_add("bullet", bullet, self): return

func _on_player_shot_resolved(shot_id: int, outcome: String, lethal: bool, _weapon_id: String) -> void:
	if not player_shot_records.has(shot_id): return
	var record: Dictionary = player_shot_records[shot_id]
	record.resolved = int(record.resolved) + 1
	if outcome == "enemy":
		record.hit = true
		record.lethal = bool(record.lethal) or lethal
		if not bool(record.reported):
			record.reported = true
			if is_instance_valid(player) and is_instance_valid(player.gun): player.gun.report_shot_result(true, lethal)
	elif outcome == "overkill":
		_show_scene_consequence("BIOLOGICAL +1 // OVERKILL")
	if int(record.resolved) >= int(record.expected):
		if not bool(record.reported) and is_instance_valid(player) and is_instance_valid(player.gun):
			player.gun.report_shot_result(false, false)
		player_shot_records.erase(shot_id)
	else:
		player_shot_records[shot_id] = record

func _on_enemy_died(pos: Vector2, facing: float, defeated_enemy: Node = null) -> void:
	enemies_killed += 1
	remaining_enemies = maxi(0, remaining_enemies - 1)
	mission_tracker.record_enemy_eliminated()
	combo += 1
	combo_timer = 2.2
	trauma_camera.trigger_kill_effect(0.72, "red")
	var corpse = CORPSE_SCENE.instantiate()
	corpse.position = to_local(pos)
	var rig_kind := "hound" if is_instance_valid(defeated_enemy) and str(defeated_enemy.actor_type) == "dog" else "human"
	var living_pose: Dictionary = defeated_enemy.get_lifecycle_pose() if is_instance_valid(defeated_enemy) and defeated_enemy.has_method("get_lifecycle_pose") else {}
	corpse.setup(facing, pending_death_direction, pending_death_knockback, pending_death_blood_power, pending_death_style, pending_death_hit_zone, pending_death_attack_id, pending_death_travel_distance, rig_kind, "enemy", living_pose)
	RuntimeBudget.add_persistent("corpse", corpse, self)
	_show_scene_consequence("BODY +25 // BIOLOGICAL LOAD %s" % ("EXTREME" if pending_death_blood_power >= 1.7 else ("HIGH" if pending_death_blood_power >= 1.2 else "STANDARD")))
	var pool_offset := pending_death_hit_position - pos if pending_death_hit_position != Vector2.ZERO else Vector2.ZERO
	blood_system.spawn_death_pool(pos, pending_death_blood_power, pool_offset, pending_death_direction, pending_death_attack_id)
	Events.publish_casualty(pos, pending_death_direction)
	if is_instance_valid(defeated_enemy) and defeated_enemy.enemy_type == "gunner":
		var remaining_rounds: int = defeated_enemy.gun.ammo
		# The weapon is physical evidence even when the enemy emptied its magazine.
		_spawn_weapon_pickup(pos, defeated_enemy.gun.weapon_id, remaining_rounds)
	pending_death_style = "firearm"
	pending_death_hit_zone = "torso"
	pending_death_hit_position = Vector2.ZERO
	pending_death_attack_id = "pistol"
	pending_death_travel_distance = 0.0
	_update_combat_objective_hud()

func _get_mission_profile() -> MissionProfile:
	if mission_profile != null: return mission_profile
	var fallback := MissionProfile.new()
	fallback.display_name = level_title
	return fallback

func _get_security_devices() -> Array[SecurityCamera]:
	if security_devices_cached: return security_devices
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

func _spawn_tactical_lures() -> void:
	tactical_lures.clear()
	var positions := tactical_lure_positions
	if positions.is_empty(): positions = PackedVector2Array([player_spawn + Vector2(76, -28), player_spawn + Vector2(164, -70)])
	var world := get_node_or_null("TileMap")
	for position in positions:
		var resolved: Vector2 = position
		if is_instance_valid(world) and world.has_method("get_nearest_walkable_position"):
			resolved = world.get_nearest_walkable_position(position, 8)
			if resolved == Vector2.INF: continue
		var lure := NOISE_LURE.new() as NoiseLure
		add_child(lure)
		lure.global_position = resolved
		tactical_lures.append(lure)

func _get_nearby_noise_lure() -> NoiseLure:
	if not is_instance_valid(player): return null
	var nearest: NoiseLure
	var nearest_distance := 20.0 * 20.0
	for lure in tactical_lures:
		if not is_instance_valid(lure) or lure.spent: continue
		var distance := player.global_position.distance_squared_to(lure.global_position)
		if distance <= nearest_distance:
			nearest = lure
			nearest_distance = distance
	return nearest

func _on_world_interaction_requested() -> void:
	if phase == "cleanup":
		if is_instance_valid(player.dragged_restoration_prop):
			player.attempt_restoration_prop_drag()
			detail_label.text = "OBJECT RELEASED // GUIDE IT INTO THE CYAN OUTLINE"
			return
		if is_instance_valid(player.dragged_corpse):
			var disposal := _get_nearby_disposal()
			if is_instance_valid(disposal) and disposal.dispose(player.dragged_corpse):
				player.dragged_corpse = null
				detail_label.text = "BODY DISPOSED // %s" % disposal.disposal_type.to_upper()
				return
			player.attempt_corpse_drag()
			return
		if _is_player_near_sink():
			if player.rinse_mop(): detail_label.text = "MOP RINSED // CLEAN WATER"
			else: detail_label.text = "MOP ALREADY CLEAN"
			return
		var displaced_prop: Node2D = player.get_nearby_restoration_prop()
		if is_instance_valid(displaced_prop) and player.attempt_restoration_prop_drag():
			detail_label.text = "OBJECT SECURED // RETURN IT TO THE CYAN OUTLINE"
			return
		var corpse: Node2D = player.get_nearby_draggable_corpse()
		if is_instance_valid(corpse):
			if corpse.is_bagged():
				player.attempt_corpse_drag()
				detail_label.text = "BODY READY FOR EXTRACTION"
			else:
				var seal_steps := 2 if Progression.has_upgrade_perk("rapid_seal") else 1
				for step in range(seal_steps):
					if corpse.is_bagged(): break
					corpse.apply_cleanup_tool("body_bag")
				detail_label.text = "BODY BAGGED" if corpse.is_bagged() else "PACKAGING BODY // PRESS E AGAIN"
			return
		var loose_evidence := _get_nearby_loose_evidence()
		if is_instance_valid(loose_evidence):
			var collected := 0
			# One deliberate interaction clears a local evidence cluster. Requiring
			# individual casing pickup adds repetition without adding decisions.
			var collect_radius := 38.0 if Progression.has_upgrade_perk("field_collector") else 30.0
			var collect_limit := 18 if Progression.has_upgrade_perk("field_collector") else 12
			var nearby_evidence := CleanupRegistry.get_targets_in_radius(player.global_position, collect_radius, collect_limit, PackedStringArray(["shell", "dropped_weapon", "debris"]))
			for evidence in nearby_evidence:
				if not is_instance_valid(evidence) or not evidence.has_method("clean_step"): continue
				for step in range(4):
					if not is_instance_valid(evidence) or evidence.is_queued_for_deletion(): break
					evidence.clean_step()
				collected += 1
			detail_label.text = "EVIDENCE BATCH // %d SECURED" % collected
			return
		var secret := _get_nearby_scene_secret()
		if is_instance_valid(secret):
			var result: Dictionary = secret.interact(Input.is_key_pressed(KEY_SHIFT))
			if str(result.get("type", "")) == "clue": clues_collected += 1
			elif bool(result.get("stolen", false)): valuables_stolen += 1
			else: valuables_secured += 1
			detail_label.text = "CLUE RECOVERED" if str(result.get("type", "")) == "clue" else ("VALUABLE POCKETED" if bool(result.get("stolen", false)) else "VALUABLE SECURED")
			return
		var furniture := _get_nearby_furniture()
		if is_instance_valid(furniture) and furniture.interact():
			if furniture is ResettableFurniture:
				furniture_restored += 1
				detail_label.text = "FURNITURE RESTORED // %d/3" % furniture_restored
			return
		return
	if phase != "combat" or run_over: return
	var device := _get_nearby_security_device()
	if is_instance_valid(device):
		device.interact(player)
		return
	var lure := _get_nearby_noise_lure()
	if is_instance_valid(lure) and lure.activate():
		detail_label.text = "NOISE LURE ACTIVE // HOSTILES INVESTIGATING"
		trauma_camera.add_trauma(0.08)

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
	var enemies_left := mission_tracker.get_required_eliminations() - mission_tracker.enemies_eliminated
	var cameras_left := mission_tracker.get_required_security_shutdowns() - mission_tracker.security_shutdowns
	hud.set_combat_counts(enemies_left, cameras_left, mission_tracker.alarm_triggers)

func _spawn_weapon_pickup(world_position: Vector2, weapon_id: String, rounds: int) -> void:
	# Merge coincident drops to keep evidence readable without ever deleting it.
	for existing in get_tree().get_nodes_in_group("weapon_pickup"):
		if existing is WeaponPickup and existing.weapon_id == weapon_id and existing.global_position.distance_to(world_position) <= 9.0:
			existing.absorb_rounds(rounds)
			return
	var pickup = WEAPON_PICKUP_SCENE.instantiate()
	if not RuntimeBudget.add_persistent("weapon_pickup", pickup, self): return
	pickup.global_position = world_position + Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0))
	pickup.rotation = randf_range(-PI, PI)
	pickup.setup(weapon_id, rounds)

func _spawn_ammo_pickup(index: int) -> void:
	var pickup = AMMO_PICKUP_SCENE.instantiate()
	if not RuntimeBudget.try_add("ammo_pickup", pickup, self): return
	var spawn_position := ammo_pickup_positions[index]
	var world := get_node_or_null("TileMap")
	if is_instance_valid(world) and world.has_method("get_nearest_walkable_position"):
		var candidate: Vector2 = world.get_nearest_walkable_position(spawn_position, 8)
		if candidate != Vector2.INF: spawn_position = candidate
	pickup.global_position = spawn_position
	var weapon_id := ammo_pickup_weapon_ids[index] if index < ammo_pickup_weapon_ids.size() else "pistol"
	var rounds := ammo_pickup_rounds[index] if index < ammo_pickup_rounds.size() else 12
	if str(active_modifier.get("id", "standard")) == "scarce_ammo": rounds = maxi(1, floori(float(rounds) * 0.5))
	pickup.setup(weapon_id, rounds)

func _spawn_level_landmarks(world: Node) -> void:
	if not is_instance_valid(world): return
	var variant: String = str(world.get("layout_variant"))
	var landmark_data := {
		"nightclub": ["dj_booth", Vector2(200, 78), Color("ff2a8a")],
		"sandwich_shop": ["diner_counter", Vector2(260, 76), Color("ff8748")],
		"tactical_lab": ["training_target", Vector2(260, 100), Color("50d9ff")],
		"harbor_exchange": ["cargo_crane", Vector2(212, 104), Color("ff8738")],
		"motel_witness": ["motel_sign", Vector2(194, 108), Color("ff3ca6")],
		"penthouse": ["city_window", Vector2(334, 80), Color("ffd05a")],
		"cold_storage": ["freezer_fans", Vector2(192, 104), Color("72e9ff")],
		"casino_floor": ["roulette", Vector2(192, 112), Color("ffcb49")],
		"police_archive": ["evidence_wall", Vector2(196, 104), Color("4d8cff")],
		"slaughterhouse": ["conveyor", Vector2(260, 108), Color("ff304c")],
		"broadcast_tower": ["broadcast_console", Vector2(192, 112), Color("61ff9a")],
		"last_call": ["broken_dj", Vector2(200, 80), Color("ff165f")],
	}
	if not landmark_data.has(variant): return
	var data: Array = landmark_data[variant]
	var landmark := LEVEL_LANDMARK.new() as LevelLandmark
	landmark.position = data[1]
	landmark.setup(data[0], data[2])
	add_child(landmark)
	if world.has_method("set_dynamic_obstacle"):
		world.set_dynamic_obstacle(landmark.global_position, true)
		landmark.solidity_changed.connect(func(solid: bool) -> void: world.set_dynamic_obstacle(landmark.global_position, solid))

func _configure_run_modifier() -> void:
	active_modifier = RunModifierCatalog.get_modifier(Progression.get_current_modifier_id())
	blood_system.violence_scale = 1.38 if str(active_modifier.id) == "forensic_nightmare" else 1.0
	if str(active_modifier.id) == "blackout":
		var canvas := get_node_or_null("CanvasModulate") as CanvasModulate
		if is_instance_valid(canvas): canvas.color = canvas.color.darkened(0.48)
		var lighting := get_node_or_null("Lighting")
		if is_instance_valid(lighting):
			for child in lighting.get_children():
				if child is PointLight2D: child.energy *= 1.35

func _on_weapon_throw_requested(origin: Vector2, direction: Vector2, weapon_id: String, rounds: int) -> void:
	if phase != "combat" or run_over: return
	var thrown_weapon := THROWN_WEAPON_SCENE.instantiate()
	if not RuntimeBudget.try_add("thrown_weapon", thrown_weapon, self): return
	thrown_weapon.global_position = origin
	thrown_weapon.setup(direction, weapon_id, rounds)

func _on_blood_impact(hit_position: Vector2, direction: Vector2, damage: int, weapon_id: String, travel_distance: float, lethal: bool, hit_zone: String) -> void:
	_on_damage_impact(DamageContext.create(hit_position, direction, damage, weapon_id, travel_distance, lethal, hit_zone))

func _on_damage_impact(context: DamageContext) -> void:
	blood_system.emit_context(context)
	var hit_position := context.hit_position
	var direction := context.direction
	var weapon_id := context.weapon_id
	var lethal := context.lethal
	if is_instance_valid(context.target) and context.target.has_method("apply_lifecycle_impact"):
		var target_rig := "hound" if context.target.is_in_group("enemy") and str(context.target.get("actor_type")) == "dog" else "human"
		var physical := RAGDOLL_IMPACT.resolve(weapon_id, context.travel_distance, context.hit_zone, target_rig)
		context.target.apply_lifecycle_impact(direction, float(physical.limb_force) * 0.58, context.hit_zone)
	if lethal:
		var data := AttackCatalog.get_gun_data(weapon_id)
		if context.target == player:
			last_player_death_cause = weapon_id.to_upper()
			pending_player_death_context = {
				"direction": direction,
				"knockback": data.knockback,
				"blood_power": data.blood_power,
				"style": data.death_style,
				"hit_zone": context.hit_zone,
				"hit_position": hit_position,
				"attack_id": weapon_id,
				"travel_distance": context.travel_distance,
			}
		else:
			pending_death_direction = direction
			pending_death_knockback = data.knockback
			pending_death_blood_power = data.blood_power
			pending_death_style = data.death_style
			pending_death_hit_zone = context.hit_zone
			pending_death_hit_position = hit_position
			pending_death_attack_id = weapon_id
			pending_death_travel_distance = context.travel_distance
		_trigger_hit_stop(data.hit_stop)

func _on_melee_impact(target: CharacterBody2D, hit_position: Vector2, direction: Vector2, melee_type: String, lethal: bool) -> void:
	if not is_instance_valid(target) or target.is_dead: return
	if not lethal:
		target.take_door_hit(direction, "knockdown")
		trauma_camera.add_trauma(0.16)
		return
	var profile := AttackCatalog.get_impact_profile(melee_type)
	if target.has_method("apply_lifecycle_impact"): target.apply_lifecycle_impact(direction, float(profile.knockback) * 0.72, "torso")
	pending_death_direction = direction
	pending_death_knockback = float(profile.knockback)
	pending_death_blood_power = float(profile.blood_power)
	pending_death_style = str(profile.style)
	pending_death_attack_id = melee_type
	pending_death_hit_position = hit_position
	pending_death_travel_distance = target.global_position.distance_to(player.global_position) if is_instance_valid(player) else 0.0
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
		pending_death_attack_id = attack_id
		pending_death_hit_position = hit_position
		pending_death_travel_distance = 0.0
		_on_impact_flash_requested(Color(0.9, 0.02, 0.12, 0.28))
		_trigger_hit_stop(float(profile.hit_stop))

func _trigger_hit_stop(duration: float) -> void:
	duration *= Settings.hit_stop_strength
	if duration <= 0.001: return
	combat_feedback.trigger_hit_stop(duration)

func _on_player_died(source_position := Vector2.ZERO) -> void:
	if is_instance_valid(playtest_telemetry):
		var world := get_node_or_null("TileMap")
		var room_id: String = str(world.get_tactical_room_id(player.global_position)) if is_instance_valid(world) and world.has_method("get_tactical_room_id") else "unknown"
		playtest_telemetry.record_death(player.global_position, room_id)
	run_over = true
	if is_instance_valid(player) and player.has_method("set_controls_enabled"): player.set_controls_enabled(false)
	_spawn_player_death_ragdoll(source_position)
	trauma_camera.add_trauma(1.0)
	_trigger_death_flash()
	status_label.text = "YOU ARE DEAD"
	var attack_direction := "UNKNOWN"
	if source_position != Vector2.ZERO and is_instance_valid(player):
		var delta := source_position - player.global_position
		if absf(delta.x) > absf(delta.y): attack_direction = "EAST" if delta.x > 0.0 else "WEST"
		else: attack_direction = "SOUTH" if delta.y > 0.0 else "NORTH"
	detail_label.text = "%s FROM %s // R TO RESTART" % [last_player_death_cause, attack_direction]

func _spawn_player_death_ragdoll(source_position: Vector2) -> void:
	if not is_instance_valid(player) or is_instance_valid(player_death_corpse): return
	var death: Dictionary = pending_player_death_context.duplicate()
	if death.is_empty():
		var attack_id := "fist"
		var closest_distance := INF
		for enemy_node in get_tree().get_nodes_in_group("enemy"):
			if not enemy_node is Node2D or not is_instance_valid(enemy_node): continue
			var distance := (enemy_node as Node2D).global_position.distance_to(source_position)
			if distance < closest_distance:
				closest_distance = distance
				attack_id = "hound_bite" if str(enemy_node.get("actor_type")) == "dog" else "fist"
		var profile := AttackCatalog.get_impact_profile(attack_id)
		var direction := source_position.direction_to(player.global_position)
		if direction.length_squared() < 0.001: direction = Vector2.RIGHT.rotated(player.rotation)
		death = {
			"direction": direction,
			"knockback": profile.knockback,
			"blood_power": profile.blood_power,
			"style": profile.style,
			"hit_zone": "torso",
			"hit_position": player.global_position,
			"attack_id": attack_id,
			"travel_distance": closest_distance if closest_distance < INF else 0.0,
		}
		last_player_death_cause = attack_id.to_upper().replace("_", " ")
	var corpse := CORPSE_SCENE.instantiate()
	corpse.position = to_local(player.global_position)
	var living_pose: Dictionary = player.get_lifecycle_pose() if player.has_method("get_lifecycle_pose") else {}
	corpse.setup(
		player.rotation,
		death.get("direction", Vector2.RIGHT),
		float(death.get("knockback", 18.0)),
		float(death.get("blood_power", 1.0)),
		str(death.get("style", "melee")),
		str(death.get("hit_zone", "torso")),
		str(death.get("attack_id", "fist")),
		float(death.get("travel_distance", 0.0)),
		"human",
		"player",
		living_pose
	)
	RuntimeBudget.add_persistent("player_ragdoll", corpse, self)
	corpse.set_cleanup_tracking(false)
	player_death_corpse = corpse
	blood_system.spawn_death_pool(
		player.global_position,
		float(death.get("blood_power", 1.0)),
		Vector2.ZERO,
		death.get("direction", Vector2.RIGHT),
		str(death.get("attack_id", "fist"))
	)
	player.collision_layer = 0
	player.collision_mask = 0
	player.visible = false
	pending_player_death_context.clear()

func _trigger_death_flash() -> void:
	_show_flash(Color(0.85, 0.03, 0.08, 0.48), 0.22)

func _on_impact_flash_requested(color: Color) -> void:
	_show_flash(color, 0.12)

func _show_flash(color: Color, duration: float) -> void:
	combat_feedback.show_flash(color, duration)

func _exit_tree() -> void:
	CombatDirector.reset_kill_zones()
	RuntimeBudget.reset_session()
	ENEMY_SCRIPT.clear_shared_caches()
	EnemyNavigation.clear_shared_cache()
	for saved in ultraviolet_materials.values():
		var evidence := (saved.node as WeakRef).get_ref() as CanvasItem
		if is_instance_valid(evidence):
			evidence.material = saved.material
			if evidence.has_method("set_ultraviolet_visible"): evidence.set_ultraviolet_visible(false)
	ultraviolet_materials.clear()
	ultraviolet_shader_material = null
	if is_instance_valid(combat_feedback): combat_feedback.reset()
	# Procedural streams are cached only for the lifetime of an active level.
	ProceduralAudioLibrary.clear_cache()
	# Runtime 8x8 icons are cached for a scene, not for the whole process. Keeping
	# strong ImageTexture references here leaked one GPU texture per HUD state
	# across repeated retries and scene transitions.
	PixelIconFactory.clear_cache()

func _enter_cleanup_phase() -> void:
	phase = "cleanup"
	if blood_system.has_method("settle_pixel_blood_for_cleanup"): blood_system.settle_pixel_blood_for_cleanup()
	hud.set_phase("cleanup")
	player.set_cleanup_mode(true)
	if player.has_method("set_controls_enabled"): player.set_controls_enabled(true)
	for bullet in get_tree().get_nodes_in_group("bullet"): bullet.queue_free()
	player_shot_records.clear()
	for corpse_node in get_tree().get_nodes_in_group("corpse"):
		if is_instance_valid(corpse_node) and corpse_node.has_method("enter_cleanup_stable_state"):
			corpse_node.enter_cleanup_stable_state()
	for prop_node in get_tree().get_nodes_in_group("displaced_prop"):
		if is_instance_valid(prop_node) and prop_node.has_method("enter_cleanup_restore_state"):
			prop_node.enter_cleanup_restore_state()
	status_label.text = "CLEANUP REQUIRED"
	detail_label.text = "GET CLOSE // HOLD LMB"
	hud.set_objective("OBJECTIVES COMPLETE // ERASE ALL EVIDENCE")
	last_cleanup_risk = CleanupRegistry.get_remaining_value()
	var contract := ContractCatalog.get_contract(Progression.get_current_contract_id())
	cleanup_time_remaining = float(contract.get("cleanup_time", mission_tracker.profile.cleanup_pressure_seconds if mission_tracker.profile != null else 0.0))
	if cleanup_time_remaining > 0.0: cleanup_time_remaining *= lerpf(1.0, 0.72, float(Progression.get_heat()) / 100.0)
	if Progression.get_run_mode() == "new_game_plus": cleanup_time_remaining *= 0.82
	if str(active_modifier.get("id", "standard")) == "forensic_nightmare": cleanup_time_remaining *= 0.78
	cleanup_pressure_active = cleanup_time_remaining > 0.0
	cleanup_timed_out = false
	if cleanup_pressure_active: detail_label.text = "POLICE ETA %02d:%02d // GET CLOSE // HOLD LMB" % [floori(cleanup_time_remaining / 60.0), floori(fmod(cleanup_time_remaining, 60.0))]
	if is_instance_valid(extraction_zone): extraction_zone.set_active(true)
	for disposal in corpse_disposals: disposal.set_active(true)
	_spawn_cleanup_opportunities()

func _spawn_corpse_disposals() -> void:
	corpse_disposals.clear()
	for index in range(disposal_positions.size()):
		var disposal := CORPSE_DISPOSAL.new() as CorpseDisposal
		add_child(disposal)
		disposal.global_position = disposal_positions[index]
		var kind := disposal_types[index] if index < disposal_types.size() else "dumpster"
		disposal.setup(kind, 2 if kind == "incinerator" else 3)
		corpse_disposals.append(disposal)

func _spawn_cleanup_opportunities() -> void:
	if cleanup_opportunities_spawned: return
	cleanup_opportunities_spawned = true
	var world := get_node_or_null("TileMap")
	var authored_secrets := cleanup_secret_positions
	var authored_furniture := cleanup_furniture_positions
	if authored_secrets.is_empty(): authored_secrets = PackedVector2Array([player.global_position + Vector2(54, -34), player.global_position + Vector2(92, 30), player.global_position + Vector2(-48, -42)])
	if authored_furniture.is_empty(): authored_furniture = PackedVector2Array([player.global_position + Vector2(72, 62), player.global_position + Vector2(-62, 48), player.global_position + Vector2(112, -54)])
	for index in range(authored_secrets.size()):
		var spawn_position: Vector2 = authored_secrets[index]
		if is_instance_valid(world) and world.has_method("get_nearest_walkable_position"):
			spawn_position = world.get_nearest_walkable_position(spawn_position, 8)
			if spawn_position == Vector2.INF: continue
		var secret := SCENE_SECRET.new() as SceneSecret
		add_child(secret)
		secret.global_position = spawn_position
		secret.setup(cleanup_secret_types[index] if index < cleanup_secret_types.size() else ("clue" if index < 2 else "valuable"))
	for spawn_position in authored_furniture:
		var resolved_position: Vector2 = spawn_position
		if is_instance_valid(world) and world.has_method("get_nearest_walkable_position"):
			resolved_position = world.get_nearest_walkable_position(resolved_position, 8)
			if resolved_position == Vector2.INF: continue
		var furniture := RESETTABLE_FURNITURE.new() as ResettableFurniture
		add_child(furniture)
		furniture.global_position = resolved_position
		furniture.setup(randf_range(-0.65, 0.65))

func _get_nearby_scene_secret() -> SceneSecret:
	var nearest: SceneSecret
	var nearest_distance := 20.0 * 20.0
	for node in get_tree().get_nodes_in_group("scene_secret"):
		if not node is SceneSecret: continue
		var distance := player.global_position.distance_squared_to(node.global_position)
		if distance <= nearest_distance: nearest = node; nearest_distance = distance
	return nearest

func _get_nearby_furniture() -> Node2D:
	var nearest: Node2D
	var nearest_distance := 22.0 * 22.0
	for node in get_tree().get_nodes_in_group("resettable_furniture"):
		if not node is Node2D or not node.has_method("interact") or not node.has_method("get_interaction_prompt"): continue
		if node.has_method("is_displaced") and node.is_displaced(): continue
		if node is ResettableFurniture and node.restored: continue
		var distance := player.global_position.distance_squared_to(node.global_position)
		if distance <= nearest_distance: nearest = node; nearest_distance = distance
	return nearest

func _get_nearby_loose_evidence() -> Node2D:
	if not is_instance_valid(player): return null
	var candidates := CleanupRegistry.get_targets_in_radius(player.global_position, 24.0, 1, PackedStringArray(["shell", "dropped_weapon", "debris"]))
	return candidates[0] if not candidates.is_empty() else null

func _get_nearby_disposal() -> CorpseDisposal:
	if not is_instance_valid(player): return null
	var nearest: CorpseDisposal
	var nearest_distance := 22.0 * 22.0
	for disposal in corpse_disposals:
		if not is_instance_valid(disposal) or not disposal.can_accept(): continue
		var distance := player.global_position.distance_squared_to(disposal.global_position)
		if distance <= nearest_distance:
			nearest = disposal
			nearest_distance = distance
	return nearest

func _is_player_near_sink() -> bool:
	var tile_world := get_node_or_null("TileMap")
	return is_instance_valid(tile_world) and tile_world.has_method("is_near_sink") and tile_world.is_near_sink(player.global_position)

func _update_ultraviolet_mode() -> void:
	var active: bool = phase == "cleanup" and is_instance_valid(player) and bool(player.ultraviolet_active)
	if active:
		if ultraviolet_shader_material == null:
			var shader := Shader.new()
			shader.code = "shader_type canvas_item; render_mode unshaded; void fragment(){ vec4 base = COLOR; float strength = max(base.r, max(base.g, base.b)); COLOR = vec4(0.20, 1.0, 0.46, base.a * max(0.55, strength)); }"
			ultraviolet_shader_material = ShaderMaterial.new()
			ultraviolet_shader_material.shader = shader
		var illuminated := {}
		for evidence in get_tree().get_nodes_in_group("blood_evidence"):
			if not evidence is CanvasItem or not _is_inside_ultraviolet_beam(evidence): continue
			var instance_id := evidence.get_instance_id()
			illuminated[instance_id] = true
			if not ultraviolet_materials.has(instance_id):
				ultraviolet_materials[instance_id] = {"node": weakref(evidence), "material": evidence.material}
			evidence.material = ultraviolet_shader_material
			if evidence.has_method("set_ultraviolet_visible"): evidence.set_ultraviolet_visible(true)
		var no_longer_visible: Array[int] = []
		for instance_id in ultraviolet_materials:
			if illuminated.has(instance_id): continue
			var saved: Dictionary = ultraviolet_materials[instance_id]
			var old_evidence := (saved.node as WeakRef).get_ref() as CanvasItem
			if is_instance_valid(old_evidence):
				old_evidence.material = saved.material
				if old_evidence.has_method("set_ultraviolet_visible"): old_evidence.set_ultraviolet_visible(false)
			no_longer_visible.append(instance_id)
		for instance_id in no_longer_visible: ultraviolet_materials.erase(instance_id)
	elif ultraviolet_was_active:
		for saved in ultraviolet_materials.values():
			var evidence := (saved.node as WeakRef).get_ref() as CanvasItem
			if is_instance_valid(evidence):
				evidence.material = saved.material
				if evidence.has_method("set_ultraviolet_visible"): evidence.set_ultraviolet_visible(false)
		ultraviolet_materials.clear()
	ultraviolet_was_active = active

func _is_inside_ultraviolet_beam(evidence: CanvasItem) -> bool:
	if not evidence is Node2D: return false
	var to_evidence: Vector2 = evidence.global_position - player.global_position
	if player.ultraviolet_scan_time > 0.0:
		var scan_radius := 82.0 + Progression.get_upgrade_level("scanner") * 18.0
		# Nightclub's dark carpet is its authored cleanup identity: the pulse has
		# stronger reach here, rewarding deliberate UV verification over pixel hunt.
		if mission_tracker.profile != null and mission_tracker.profile.mission_id == "nightclub": scan_radius += 20.0
		if to_evidence.length_squared() > scan_radius * scan_radius: return false
	else:
		if to_evidence.length_squared() > 66.0 * 66.0 or to_evidence.length_squared() < 1.0: return false
		var beam_direction := Vector2.RIGHT.rotated(player.rotation)
		if absf(beam_direction.angle_to(to_evidence.normalized())) > 0.44: return false
	var query := PhysicsRayQueryParameters2D.create(player.global_position, evidence.global_position, 4)
	query.collide_with_areas = false
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _begin_cleanup_transition() -> void:
	transitioning_cleanup = true
	if is_instance_valid(player) and player.has_method("set_controls_enabled"): player.set_controls_enabled(false)
	status_label.text = "SCENE STABILIZATION"
	detail_label.text = "CHECKING WEAPONS // BODIES // ACTIVE HAZARDS"
	hud.show_banner("AREA SECURE // STABILIZE THE SCENE")
	combat_feedback.show_flash(Color(0.28, 0.78, 1.0, 0.10), 0.18)
	await get_tree().create_timer(1.15, true, false, true).timeout
	if not is_inside_tree() or run_over: return
	if not mission_tracker.are_combat_objectives_complete():
		transitioning_cleanup = false
		combat_completion_hold = 0.0
		if is_instance_valid(player) and player.has_method("set_controls_enabled"): player.set_controls_enabled(true)
		return
	Events.combat_ended.emit()
	_enter_cleanup_phase()

func _on_clean_requested(world_position: Vector2, stroke_direction := Vector2.RIGHT, stroke_strength := 1.0, stroke_start := Vector2.INF) -> void:
	if phase != "cleanup" or run_over: return
	if player.global_position.distance_to(world_position) > 38.0: return
	if stroke_start == Vector2.INF: stroke_start = world_position - stroke_direction.normalized() * maxf(2.0, stroke_strength * 9.0)
	# Blood and every environmental liquid share the same continuous capsule
	# gesture. They keep separate evidence channels but never disappear in blocks.
	var pixel_cleaned := false
	var pixel_power := 0
	if player.current_cleanup_tool in ["mop", "pressure_washer"] and blood_system.has_method("clean_pixel_stroke"):
		pixel_power = maxi(1, roundi(float(player.get_cleanup_efficiency("blood")) * clampf(stroke_strength, 0.45, 1.25)))
		var brush_radius := 7.0 if player.current_cleanup_tool == "pressure_washer" else (5.0 if Progression.has_upgrade_perk("wide_finish") else 4.0)
		pixel_cleaned = blood_system.clean_pixel_stroke(stroke_start, world_position, brush_radius, pixel_power, player.current_cleanup_tool)
	var compatible_types := CleanupWorkflow.get_compatible_types(player.current_cleanup_tool)
	var target := CleanupRegistry.get_nearest_compatible_target(world_position, 26.0, compatible_types)
	# The owning canvas already handled every crossed chunk above; choose another
	# nearby legacy/solid evidence target instead of cleaning the endpoint twice.
	if is_instance_valid(target) and target.is_in_group("pixel_blood_chunk"):
		target = null
		for candidate in CleanupRegistry.get_targets_in_radius(world_position, 26.0, 24, compatible_types):
			if candidate.is_in_group("pixel_blood_chunk"): continue
			target = candidate
			break
	# Invisible forensic residue must not absorb ordinary mop input. It remains
	# indexed so the pressure washer can remove it when the player chooses to.
	if player.current_cleanup_tool == "mop" and is_instance_valid(target) and target.has_method("is_ultraviolet_residue") and target.is_ultraviolet_residue():
		target = null
		for candidate in CleanupRegistry.get_targets_in_radius(world_position, 26.0, 24, compatible_types):
			if candidate.has_method("is_ultraviolet_residue") and candidate.is_ultraviolet_residue(): continue
			target = candidate
			break
	# A live pipe/electrical source must be isolated before its connected pixels
	# can be removed. This check occurs before the shared liquid canvas is touched.
	var active_liquid_source_near := false
	for hazard in get_tree().get_nodes_in_group("environment_hazard"):
		if not hazard is EnvironmentHazard or not hazard.source_active or hazard.hazard_kind not in ["water", "electric"]: continue
		if hazard.global_position.distance_to(world_position) <= hazard.target_radius * 1.6:
			active_liquid_source_near = true
			break
	if active_liquid_source_near:
		detail_label.text = "SOURCE STILL ACTIVE // RESTORE DAMAGED EQUIPMENT FIRST"
		return
	if player.current_cleanup_tool in ["mop", "pressure_washer"]:
		var liquid_system := get_tree().get_first_node_in_group("pixel_liquid_system") as Node2D
		if is_instance_valid(liquid_system):
			if pixel_power <= 0: pixel_power = maxi(1, roundi(float(player.get_cleanup_efficiency("spill")) * clampf(stroke_strength, 0.45, 1.25)))
			var liquid_brush := 7.0 if player.current_cleanup_tool == "pressure_washer" else (5.0 if Progression.has_upgrade_perk("wide_finish") else 4.0)
			pixel_cleaned = liquid_system.clean_stroke(stroke_start, world_position, liquid_brush, pixel_power, player.current_cleanup_tool) or pixel_cleaned
	if not is_instance_valid(target):
		if pixel_cleaned:
			if player.current_cleanup_tool == "mop": player.record_mop_use(0.34 + 0.08 * pixel_power)
			ammo_label.text = player.current_cleanup_tool.to_upper().replace("_", " ")
		return
	var cleanup_type := str(target.get_cleanup_type()) if target.has_method("get_cleanup_type") else "unknown"
	if target.has_method("is_cleanup_blocked") and target.is_cleanup_blocked():
		detail_label.text = "SOURCE STILL ACTIVE // RESTORE DAMAGED EQUIPMENT FIRST"
		return
	if target.has_method("apply_cleanup_tool"):
		if target.apply_cleanup_tool(player.current_cleanup_tool): return
		if player.current_cleanup_tool != _required_cleanup_tool(cleanup_type):
			detail_label.text = "NEED %s" % _required_cleanup_tool(cleanup_type).to_upper().replace("_", " ")
			return
	var steps: int = int(player.get_cleanup_efficiency(cleanup_type))
	if steps <= 0:
		detail_label.text = "NEED %s" % _required_cleanup_tool(cleanup_type).to_upper().replace("_", " ")
		return
	var used_cleaner := bool(target.get_meta("cleaner_primed", false))
	if used_cleaner:
		steps += 2
		target.set_meta("cleaner_primed", false)
	steps = maxi(1, roundi(float(steps) * clampf(stroke_strength, 0.45, 1.25)))
	# Closing Time's grease/liquid identity gives the washer a real situational
	# advantage without letting it replace the mop for solid gore.
	if mission_tracker.profile != null and mission_tracker.profile.mission_id == "sandwich_shop" and player.current_cleanup_tool == "pressure_washer" and cleanup_type == "spill":
		steps += 3
	var targets: Array[Node2D] = [target]
	if player.current_cleanup_tool in ["mop", "pressure_washer"]:
		var clean_radius := 30.0 if player.current_cleanup_tool == "pressure_washer" else (27.0 if Progression.has_upgrade_perk("wide_finish") else 22.0)
		var clean_count := 10 if player.current_cleanup_tool == "pressure_washer" else 6
		targets = CleanupRegistry.get_targets_in_radius(world_position, clean_radius, clean_count, compatible_types)
	for cleanup_target in targets:
		if cleanup_target.has_method("clean_stroke"):
			cleanup_target.clean_stroke(world_position, stroke_direction, steps, player.current_cleanup_tool)
		elif cleanup_target.has_method("clean_at"):
			cleanup_target.clean_at(world_position, steps)
		else:
			for index in range(steps):
				if not is_instance_valid(cleanup_target) or cleanup_target.is_queued_for_deletion(): break
				cleanup_target.clean_step()
	if used_cleaner and is_instance_valid(target): target.modulate = Color.WHITE
	var liquid_surface := get_tree().get_first_node_in_group("pixel_liquid_system") as Node2D
	if not is_instance_valid(liquid_surface):
		liquid_surface = preload("res://scripts/effects/pixel_liquid_system.gd").get_or_create(get_tree()) as Node2D
	if is_instance_valid(liquid_surface): liquid_surface.stamp_cleaning_stroke(stroke_start, world_position, player.current_cleanup_tool)
	if player.current_cleanup_tool == "mop": player.record_mop_use(0.38 + 0.16 * steps)
	ammo_label.text = player.current_cleanup_tool.to_upper().replace("_", " ")

func _on_cleaner_requested(world_position: Vector2) -> void:
	if phase != "cleanup" or run_over: return
	if player.global_position.distance_to(world_position) > 38.0: return
	var target := CleanupRegistry.get_nearest_target(world_position, 16.0)
	if not is_instance_valid(target):
		detail_label.text = "NO STAIN IN RANGE // CLEANER %d" % player.cleaner_charges
		return
	var cleanup_type := str(target.get_cleanup_type()) if target.has_method("get_cleanup_type") else ""
	if cleanup_type not in ["blood", "blood_pool", "blood_footprint", "gore"]:
		detail_label.text = "CLEANER ONLY WORKS ON BIOLOGICAL STAINS"
		return
	var liquid_surface := get_tree().get_first_node_in_group("pixel_liquid_system") as Node2D
	if not is_instance_valid(liquid_surface): liquid_surface = preload("res://scripts/effects/pixel_liquid_system.gd").get_or_create(get_tree()) as Node2D
	if is_instance_valid(liquid_surface): liquid_surface.emit_burst(world_position, &"cleaner", player.global_position.direction_to(world_position), 0.55)
	target.set_meta("cleaner_primed", true)
	target.modulate = Color(1.15, 0.72, 0.88, 1.0)
	detail_label.text = "STAIN TREATED // CLEANER %d" % player.cleaner_charges

func _required_cleanup_tool(cleanup_type: String) -> String:
	return CleanupWorkflow.get_required_tool(cleanup_type)

func _get_cleanup_workflow_hint(counts: Dictionary) -> String:
	return CleanupWorkflow.get_hint(counts)

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
	if is_instance_valid(player) and player.has_method("set_controls_enabled"): player.set_controls_enabled(false)
	var cleanup_ratio := CleanupRegistry.get_cleanup_ratio()
	var contract := ContractCatalog.get_contract(Progression.get_current_contract_id())
	var evidence_counts := CleanupRegistry.get_type_counts()
	var bodies_remaining := int(evidence_counts.get("corpse", 0))
	var ballistic_remaining := int(evidence_counts.get("shell", 0)) + int(evidence_counts.get("dropped_weapon", 0))
	var biological_remaining := int(evidence_counts.get("blood", 0)) + int(evidence_counts.get("blood_pool", 0)) + int(evidence_counts.get("blood_footprint", 0)) + int(evidence_counts.get("gore", 0))
	var contract_success := ContractCatalog.evaluate(str(contract.id), cleanup_ratio, mission_tracker.alarm_triggers, combat_shots_fired, cleanup_timed_out, mission_tracker.property_damage, bodies_remaining, ballistic_remaining)
	if contract_success and str(contract.id) != "standard": final_score += roundi(250.0 * float(contract.payout))
	var cleanup_tier: Dictionary = GAMEPLAY_RULES.get_cleanup_tier(cleanup_ratio)
	var scene_certified := bool(cleanup_tier.can_extract)
	left_evidence = left_evidence or cleanup_ratio < 0.999
	var target_duration := mission_tracker.profile.target_duration_seconds if mission_tracker.profile != null else 600.0
	var time_bonus := roundi(clampf((target_duration - elapsed) / maxf(target_duration, 1.0), 0.0, 1.0) * 500.0)
	var restoration_cost := MissionResultBuilder.restoration_cost(mission_tracker.property_damage, ballistic_remaining, biological_remaining)
	var room_verification_bonus := verified_cleanup_rooms.size() * 35
	final_score += maxi(0, roundi(cleanup_ratio * 1000.0) + enemies_killed * 100 + time_bonus + mission_tracker.get_score_modifier() + clues_collected * 90 + valuables_secured * 80 + valuables_stolen * 130 + furniture_restored * 45 + room_verification_bonus + precision_reward_bonus - restoration_cost)
	if Progression.get_run_mode() == "score_attack": final_score = roundi(final_score * 1.5)
	elif Progression.get_run_mode() == "new_game_plus": final_score = roundi(final_score * 1.25)
	final_grade = MissionResultBuilder.grade(cleanup_ratio, mission_tracker.alarm_triggers, mission_tracker.property_damage)
	status_label.text = "PERFECT CLEANUP" if cleanup_ratio >= 0.999 else ("SCENE CERTIFIED" if scene_certified else "SCENE ABANDONED")
	var footprint_count := get_tree().get_nodes_in_group("footprint").size()
	detail_label.text = "GRADE %s // %04d // %s // SHOTS %d // %d ALARMS // ENTER REPORT // R RETRY" % [final_grade, final_score, "CONTRACT OK" if contract_success else "CONTRACT FAILED", combat_shots_fired, mission_tracker.alarm_triggers]
	hud.set_objective("MISSION COMPLETE // " + mission_tracker.get_status_line())
	interaction_label.text = "ACCEPTABLE CLEAN // RISK %d" % CleanupRegistry.get_remaining_value() if scene_certified and left_evidence else ("EVIDENCE LEFT // %d" % CleanupRegistry.get_remaining_value() if left_evidence else "PERFECT CLEANUP")
	if record_progress:
		Progression.record_mission_result(mission_tracker.profile.mission_id, final_score, final_grade, elapsed, cleanup_ratio, mission_tracker.alarm_triggers, CleanupRegistry.get_remaining_value(), _build_forensic_report(cleanup_ratio))
	if is_instance_valid(playtest_telemetry): playtest_telemetry.complete_run(cleanup_ratio, combat_phase_elapsed, cleanup_phase_elapsed, CleanupRegistry.get_remaining_value(), mission_tracker.alarm_triggers)

func _build_forensic_report(cleanup_ratio: float) -> Dictionary:
	var counts := CleanupRegistry.get_type_counts()
	var traces: Array[String] = []
	var biological := int(counts.get("blood", 0)) + int(counts.get("blood_pool", 0)) + int(counts.get("blood_footprint", 0)) + int(counts.get("gore", 0))
	var ballistic := int(counts.get("shell", 0)) + int(counts.get("dropped_weapon", 0))
	var bodies := int(counts.get("corpse", 0))
	if bodies > 0: traces.append("%d BODY%s RECOVERABLE" % [bodies, "" if bodies == 1 else "S"])
	if ballistic > 0: traces.append("%d BALLISTIC TRACE%s" % [ballistic, "" if ballistic == 1 else "S"])
	if biological > 0: traces.append("%d BIOLOGICAL TRACE%s" % [biological, "" if biological == 1 else "S"])
	if mission_tracker.alarm_triggers > 0: traces.append("SECURITY RESPONSE LOGGED")
	if mission_tracker.property_damage > 0: traces.append("%d PROPERTY IMPACT%s" % [mission_tracker.property_damage, "" if mission_tracker.property_damage == 1 else "S"])
	if valuables_stolen > 0: traces.append("VALUABLES REPORTED MISSING")
	if traces.is_empty(): traces.append("NO ACTIONABLE TRACE CHAIN")
	var contract := ContractCatalog.get_contract(Progression.get_current_contract_id())
	var contract_success := ContractCatalog.evaluate(str(contract.id), cleanup_ratio, mission_tracker.alarm_triggers, combat_shots_fired, cleanup_timed_out, mission_tracker.property_damage, bodies, ballistic)
	return {
		"classification": "PERFECT" if cleanup_ratio >= 0.999 else ("CERTIFIED" if cleanup_ratio >= 0.90 else "COMPROMISED"),
		"cleanup_percent": roundi(cleanup_ratio * 100.0),
		"shots": combat_shots_fired,
		"dominant_weapon": mission_tracker.get_dominant_weapon(),
		"projected_weapon_cleanup": mission_tracker.get_projected_weapon_cleanup_cost(),
		"bodies": bodies,
		"ballistic": ballistic,
		"biological": biological,
		"property_damage": mission_tracker.property_damage,
		"restoration_cost": MissionResultBuilder.restoration_cost(mission_tracker.property_damage, ballistic, biological),
		"dominant_cost": MissionResultBuilder.dominant_cost(mission_tracker.property_damage, ballistic, biological, bodies),
		"rooms_verified": verified_cleanup_rooms.size(),
		"field_kit": Progression.get_current_kit_id(),
		"traces": traces,
		"contract_id": str(contract.id),
		"contract_name": str(contract.name),
		"contract_success": contract_success,
		"contract_multiplier": float(contract.payout),
		"cleanup_timed_out": cleanup_timed_out,
		"alarms": mission_tracker.alarm_triggers,
		"valuables_stolen": valuables_stolen > 0,
		"run_mode": Progression.get_run_mode(),
		"combat_route": roundi(combat_route_distance),
		"cleanup_route": roundi(cleanup_route_distance),
		"combat_seconds": combat_phase_elapsed,
		"cleanup_seconds": cleanup_phase_elapsed,
		"target_duration": mission_tracker.profile.target_duration_seconds if mission_tracker.profile != null else 600.0,
	}
