extends Node

const MISSIONS := {
	"nightclub": "res://scenes/main.tscn",
	"sandwich_shop": "res://scenes/levels/sandwich_shop.tscn",
	"tactical_lab": "res://scenes/levels/after_hours.tscn",
	"harbor_exchange": "res://scenes/levels/harbor_exchange.tscn",
	"motel_witness": "res://scenes/levels/motel_witness.tscn",
	"penthouse": "res://scenes/levels/penthouse.tscn",
	"cold_storage": "res://scenes/levels/cold_storage.tscn",
	"casino_floor": "res://scenes/levels/casino_floor.tscn",
	"police_archive": "res://scenes/levels/police_archive.tscn",
	"slaughterhouse": "res://scenes/levels/slaughterhouse.tscn",
	"broadcast_tower": "res://scenes/levels/broadcast_tower.tscn",
	"last_call": "res://scenes/levels/last_call.tscn",
}
var failures := 0

func _ready() -> void:
	var room_catalog := preload("res://utility/handcrafted_room_catalog.gd")
	_expect(room_catalog.get_modules().size() >= 48, "roguelike generation needs at least 48 handcrafted combat-room modules")
	_expect(room_catalog.validate_catalog().is_empty(), "every handcrafted combat-room module must pass anchor, metadata and cover-spacing validation")
	var signatures := {}
	var acoustic_identities := {}
	for mission_id: String in MISSIONS:
		var packed := load(MISSIONS[mission_id]) as PackedScene
		_expect(packed != null, "%s should load" % mission_id)
		if packed == null: continue
		var level = packed.instantiate()
		level.record_progress = false
		add_child(level)
		await get_tree().process_frame
		var world := level.get_node("TileMap") as TileWorld
		if mission_id == "nightclub": _verify_run_room_seed(world)
		_expect(world.layout_variant == mission_id, "%s must use its own authored topology" % mission_id)
		var architecture: Dictionary = world.get_architectural_profile()
		_expect(is_equal_approx(float(architecture.meters_per_tile), 0.5), "%s must use the shared half-metre planning grid" % mission_id)
		_expect(int(architecture.minimum_corridor_tiles) >= 5 and int(architecture.primary_corridor_tiles) >= 7, "%s circulation must preserve human-scale secondary and primary passages" % mission_id)
		var architectural_rooms: Array = architecture.rooms
		_expect(architectural_rooms.size() >= 4 and architectural_rooms.size() <= 5, "%s should use four or five broad roguelike combat chambers instead of a micro-room maze" % mission_id)
		var room_ids := {}
		for room: Dictionary in architectural_rooms:
			var room_rect: Rect2i = room.rect
			_expect(not room_ids.has(str(room.id)), "%s room identities must be unique" % mission_id)
			room_ids[str(room.id)] = true
			_expect(room_rect.size.x >= 4 and room_rect.size.y >= 4, "%s room %s must remain large enough for a believable human function" % [mission_id, room.id])
			_expect(Rect2i(Vector2i.ONE, world.map_size - Vector2i(2,2)).encloses(room_rect), "%s room %s must remain inside the building envelope" % [mission_id, room.id])
		var acoustic_profile: Dictionary = world.get_acoustic_profile()
		var acoustic_identity := str(acoustic_profile.get("identity", ""))
		_expect(not acoustic_identity.is_empty(), "%s needs an authored acoustic identity" % mission_id)
		_expect(not acoustic_identities.has(acoustic_identity), "%s should not reuse another mission's acoustic identity" % mission_id)
		acoustic_identities[acoustic_identity] = mission_id
		_expect(world.acoustic_sector_count >= 2, "%s needs room-scale acoustic sectors rather than one global hearing space" % mission_id)
		_expect(world.acoustic_portals.size() >= 1, "%s needs at least one authored sound portal" % mission_id)
		var first_portal: Dictionary = world.acoustic_portals[0]
		var acoustic_route: Dictionary = world._find_acoustic_route(str(first_portal.a), str(first_portal.b), acoustic_profile)
		_expect(int(acoustic_route.get("hops", 0)) >= 1 and float(acoustic_route.get("cost", 0.0)) > 0.0, "%s acoustic portals must attenuate sound between room sectors" % mission_id)
		var building_rect := world.get_building_world_rect()
		var combat_space: Dictionary = world.get_combat_space_profile()
		_expect(world.scale == Vector2.ONE and int(combat_space.native_tile_px) == 8, "%s must enlarge room geometry without stretching actor artwork or native pixels" % mission_id)
		_expect(building_rect.size.x >= 768.0 and building_rect.size.y >= 448.0, "%s needs truly expanded playable space, not a zoomed-out camera" % mission_id)
		_expect(int(combat_space.door_width_px) == 24, "%s enlargement must retain human-sized 24px door leaves" % mission_id)
		for room_space: Dictionary in combat_space.rooms:
			var actual_bounds: Rect2 = room_space.bounds
			_expect(minf(actual_bounds.size.x, actual_bounds.size.y) >= 80.0, "%s room %s needs at least 80px of clear planning depth for movement and physics" % [mission_id, room_space.id])
			var origin_id := world.get_tactical_room_id(actual_bounds.get_center())
			_expect(not origin_id.ends_with("circulation") and origin_id != "exterior_approach", "%s actual expanded room bounds must agree with tactical triggers" % mission_id)
		_expect(not building_rect.has_point(level.player.global_position), "%s should begin on a readable exterior approach by default" % mission_id)
		_expect(world.get_tactical_room_id(level.player.global_position) == "exterior_approach", "%s exterior spawn needs an explicit tactical room identity" % mission_id)
		var visible_world: Vector2 = Vector2(320.0, 180.0) / Vector2(level.trauma_camera.zoom)
		_expect(visible_world.x < building_rect.size.x and visible_world.y < building_rect.size.y, "%s camera should reveal a local room cluster, not the complete building" % mission_id)
		_expect(level.started_enemy_count >= architectural_rooms.size() * 2 and level.started_enemy_count <= architectural_rooms.size() * 4, "%s must alternate short and full encounters within a 2-4 enemy room budget" % mission_id)
		world.room_run_seed_override = 1701
		var encounter_preview_a: Dictionary = world.get_handcrafted_encounter_layout()
		world.room_run_seed_override = 2917
		var encounter_preview_b: Dictionary = world.get_handcrafted_encounter_layout()
		world.room_run_seed_override = -1
		_expect(encounter_preview_a.spawns != encounter_preview_b.spawns or encounter_preview_a.patrols != encounter_preview_b.patrols, "%s must reshuffle proven room formations between run seeds" % mission_id)
		_expect(encounter_preview_a.modules != encounter_preview_b.modules, "%s should rearrange complete handcrafted room modules rather than only nudging spawn points" % mission_id)
		var assigned_modules: PackedStringArray = encounter_preview_a.modules
		var unique_modules := {}
		for module_id: String in assigned_modules: unique_modules[module_id] = true
		_expect(unique_modules.size() == assigned_modules.size(), "%s should not repeat a combat-room module within one floor" % mission_id)
		var current_preview: Dictionary = world.get_handcrafted_encounter_layout()
		_expect((current_preview.spawns as PackedVector2Array).size() == level.started_enemy_count, "%s current seed must preserve its actual encounter budget" % mission_id)
		_expect(level.fixed_sentry_indices.is_empty(), "%s should use mobile patrols instead of permanent fixed sentries" % mission_id)
		var authored_archetypes: Dictionary = {}
		for enemy_type in level.enemy_types: authored_archetypes[str(enemy_type)] = true
		_expect(authored_archetypes.size() >= 3, "%s should create difficulty through mixed enemy roles rather than raw headcount" % mission_id)
		var wall_cells: Array[Vector2i] = world.wall_layer.get_used_cells()
		_expect(wall_cells.size() >= 120, "%s needs enough walls to form tactical rooms" % mission_id)
		var floor_cells: Array[Vector2i] = world.floor_layer.get_used_cells()
		var walkable_cells := 0
		var clear_maneuver_zones := 0
		var longest_fire_lane := 0
		for cell: Vector2i in floor_cells:
			if not world.path_grid.is_point_solid(cell): walkable_cells += 1
			var clear_zone := true
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					var neighbor := cell + Vector2i(ox, oy)
					if not world.path_grid.is_in_boundsv(neighbor) or world.path_grid.is_point_solid(neighbor): clear_zone = false
			if clear_zone: clear_maneuver_zones += 1
			var lane_length := 0
			for offset in range(0, 28):
				var lane_cell := cell + Vector2i(offset, 0)
				if not world.path_grid.is_in_boundsv(lane_cell) or world.path_grid.is_point_solid(lane_cell): break
				lane_length += 1
			longest_fire_lane = maxi(longest_fire_lane, lane_length)
		var walkable_ratio := float(walkable_cells) / maxf(1.0, float(floor_cells.size()))
		_expect(walkable_ratio >= 0.68, "%s should reserve at least 68%% of authored floor for circulation (%.2f)" % [mission_id, walkable_ratio])
		_expect(clear_maneuver_zones >= 12, "%s needs multiple 3x3 CQB maneuver zones instead of one-cell corridors" % mission_id)
		_expect(longest_fire_lane >= 10, "%s needs at least one readable ten-cell firearm lane" % mission_id)
		var furniture_count := world.find_children("*", "DestructibleProp", true, false).size()
		_expect(furniture_count >= 10, "%s needs enough authored destructible props to make firefights physically expressive" % mission_id)
		_expect(furniture_count <= 16, "%s should preserve generous combat circulation instead of over-furnishing rooms (%d props)" % [mission_id, furniture_count])
		var signature := ""
		for cell: Vector2i in wall_cells: signature += "%d,%d;" % [cell.x, cell.y]
		_expect(not signatures.has(signature), "%s must not reuse another mission's wall topology" % mission_id)
		signatures[signature] = mission_id
		_expect(world.is_navigation_position_walkable(level.player.global_position), "%s player spawn must resolve to walkable floor" % mission_id)
		var door_specs: Array[Dictionary] = world.get_door_specs()
		var exterior_passage: Vector2 = door_specs[-1].passage_center if not door_specs.is_empty() else Vector2.INF
		for enemy in level.get_node("Enemies").get_children():
			_expect(world.is_navigation_position_walkable(enemy.global_position), "%s enemy spawn must resolve to walkable floor" % mission_id)
			_expect(not enemy.is_fixed_sentry and enemy.patrol_waypoints.size() >= 2, "%s must give every enemy a real two-point patrol" % mission_id)
			var route := world.get_navigation_path(level.player.global_position, enemy.global_position)
			_expect(not route.is_empty() or level.player.global_position.distance_to(enemy.global_position) < 8.0, "%s must connect every enemy room to the player route" % mission_id)
			var to_player: Vector2 = level.player.global_position - enemy.global_position
			_expect(not enemy._can_see_player(to_player.length(), to_player), "%s must not give an enemy direct sight of the motionless exterior spawn" % mission_id)
			for waypoint: Vector2 in enemy.patrol_waypoints:
				_expect(waypoint.distance_to(exterior_passage) >= 20.0, "%s enemy %d patrol point %s must not automatically open or camp exterior threshold %s" % [mission_id, enemy.get_index(), waypoint, exterior_passage])
			if enemy.patrol_waypoints.size() >= 2:
				_expect(enemy.patrol_waypoints[0].distance_to(enemy.patrol_waypoints[1]) >= 16.0, "%s mobile patrol routes must not collapse into a stationary duplicate point" % mission_id)
				_expect(world.get_tactical_room_id(enemy.patrol_waypoints[0]) == world.get_tactical_room_id(enemy.patrol_waypoints[1]), "%s enemy %d patrol endpoints %s (%s) and %s (%s) must remain in one authored room" % [mission_id, enemy.get_index(), enemy.patrol_waypoints[0], world.get_tactical_room_id(enemy.patrol_waypoints[0]), enemy.patrol_waypoints[1], world.get_tactical_room_id(enemy.patrol_waypoints[1])])
				var initial_heading: float = enemy.patrol_waypoints[0].direction_to(enemy.patrol_waypoints[1]).angle()
				_expect(absf(angle_difference(enemy.rotation, initial_heading)) < 0.01, "%s patrol actors must initially face their authored route" % mission_id)
		if mission_id == "nightclub":
			var lower_left_enemy = level.get_node("Enemies").get_child(1)
			var patrol_origin: Vector2 = lower_left_enemy.global_position
			var max_patrol_displacement := 0.0
			_expect(not bool(lower_left_enemy.get_meta("rogue_room_active", true)), "nightclub lower-left patrol should begin combat-dormant outside the arrival room")
			for frame in 180:
				await get_tree().physics_frame
				max_patrol_displacement = maxf(max_patrol_displacement, patrol_origin.distance_to(lower_left_enemy.global_position))
			_expect(max_patrol_displacement >= 8.0, "nightclub lower-left enemy must visibly patrol before its room is activated (moved %.1f px)" % max_patrol_displacement)
		for spec: Dictionary in world.get_door_specs():
			var passage_center: Vector2 = spec.passage_center
			var opening_cell: Vector2i = spec.opening_cell
			var leaf_step := Vector2i(0, 1) if absf(float(spec.rotation)) < 0.1 else Vector2i(1, 0)
			_expect(world.is_navigation_position_walkable(passage_center), "%s door centre must remain on navigable floor" % mission_id)
			for leaf_index in range(TileWorld.DOOR_CELL_SPAN):
				_expect(not world.path_grid.is_point_solid(opening_cell + leaf_step * leaf_index), "%s door cell %d must be open" % [mission_id, leaf_index])
			_expect(world.wall_layer.get_cell_source_id(opening_cell - leaf_step) >= 0, "%s door hinge must terminate against a wall instead of floating" % mission_id)
			_expect(world.wall_layer.get_cell_source_id(opening_cell + leaf_step * TileWorld.DOOR_CELL_SPAN) >= 0, "%s door latch side must terminate against a wall instead of floating" % mission_id)
		if mission_id == "sandwich_shop":
			var hounds := level.get_node("Enemies").get_children().filter(func(enemy: Node) -> bool: return str(enemy.actor_type) == "dog")
			_expect(hounds.size() == 1, "sandwich_shop should retain one authored hound encounter")
			# Exercise real AI/physics time: a player who provides no input and makes
			# no noise must receive a genuine arrival/read phase before breaching.
			for frame in 150: await get_tree().physics_frame
			for enemy in level.get_node("Enemies").get_children():
				_expect(enemy.state not in [enemy.State.CHASE, enemy.State.ATTACK], "sandwich_shop enemies must not acquire a motionless exterior arrival")
			_expect(not level.player.is_dead, "sandwich_shop exterior arrival must survive without player input")
		_expect(world.get_door_specs().size() >= 4 and world.get_door_specs().size() <= 7, "%s should combine one exterior threshold with a legible interior doorway budget" % mission_id)
		if level.mission_profile != null and level.mission_profile.required_security_shutdowns > 0:
			_expect(level._get_security_devices().size() >= level.mission_profile.required_security_shutdowns, "%s must author enough security devices for its objective" % mission_id)
		_expect(level.find_children("*", "LevelLandmark", true, false).size() == 1, "%s needs one signature landmark" % mission_id)
		level.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	_expect(signatures.size() == MISSIONS.size(), "all redesigned campaign maps need unique topology signatures")
	_expect(acoustic_identities.size() == MISSIONS.size(), "all campaign maps need distinct acoustic gameplay identities")
	# The fixture loads the whole weapon catalog indirectly through every scene.
	# Release its process-wide resource ownership after all levels and deferred
	# frees finish, rather than leaving GunData/audio references alive at shutdown.
	AttackCatalog.GUNS.clear()
	ProceduralAudioLibrary.clear_cache()
	PixelActorTextureFactory.clear_cache()
	PixelEnvironmentAtlas.clear_cache()
	if failures == 0: print("campaign map identity regression: PASS")
	# Let this fixture release its typed-script references before SceneTree exit.
	var tree := get_tree()
	tree.create_timer(0.01, true, false, true).timeout.connect(tree.quit.bind(failures))
	queue_free()

func _verify_run_room_seed(world: TileWorld) -> void:
	var saved_active: bool = Progression.run_session.active
	var saved_serial: int = int(Progression.data.get("roguelike_run_serial", 0))
	var saved_floor: int = Progression.get_roguelike_floor()
	var saved_attempts: Dictionary = (Progression.data.get("mission_attempts", {}) as Dictionary).duplicate(true)
	Progression.run_session.active = true
	Progression.data.roguelike_run_serial = 913
	Progression.data.roguelike_floor = 2
	var original: Dictionary = world.get_handcrafted_encounter_layout()
	Progression.data.mission_attempts["nightclub"] = 700
	var retry: Dictionary = world.get_handcrafted_encounter_layout()
	_expect(original.seed == retry.seed and original.modules == retry.modules and original.spawns == retry.spawns, "same run/floor retry must retain enemies and cover despite mission-attempt changes")
	Progression.data.roguelike_run_serial = 914
	var next_run: Dictionary = world.get_handcrafted_encounter_layout()
	_expect(original.seed != next_run.seed and original.modules != next_run.modules, "a new run must reshuffle the room formations")
	Progression.data.roguelike_run_serial = 913
	Progression.data.roguelike_floor = 3
	_expect(world._get_room_run_seed() != int(original.seed), "different floor numbers must get distinct room seeds")
	Progression.run_session.active = false
	var preview_seed := world._get_room_run_seed()
	Progression.data.roguelike_run_serial = 990
	Progression.data.roguelike_floor = 5
	_expect(world._get_room_run_seed() == preview_seed, "standalone previews must ignore inactive roguelike session data")
	Progression.run_session.active = saved_active
	Progression.data.roguelike_run_serial = saved_serial
	Progression.data.roguelike_floor = saved_floor
	Progression.data.mission_attempts = saved_attempts

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
