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
	var signatures := {}
	for mission_id: String in MISSIONS:
		var packed := load(MISSIONS[mission_id]) as PackedScene
		_expect(packed != null, "%s should load" % mission_id)
		if packed == null: continue
		var level = packed.instantiate()
		level.record_progress = false
		add_child(level)
		await get_tree().process_frame
		var world := level.get_node("TileMap") as TileWorld
		_expect(world.layout_variant == mission_id, "%s must use its own authored topology" % mission_id)
		_expect(level.started_enemy_count >= 7 and level.started_enemy_count <= 11, "%s should use a readable 7-11 enemy encounter budget instead of crowding rooms (%d)" % [mission_id, level.started_enemy_count])
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
		_expect(furniture_count >= 6, "%s needs authored destructible functional furniture" % mission_id)
		_expect(furniture_count <= 14, "%s should preserve generous combat circulation instead of over-furnishing rooms (%d props)" % [mission_id, furniture_count])
		var signature := ""
		for cell: Vector2i in wall_cells: signature += "%d,%d;" % [cell.x, cell.y]
		_expect(not signatures.has(signature), "%s must not reuse another mission's wall topology" % mission_id)
		signatures[signature] = mission_id
		_expect(world.is_navigation_position_walkable(level.player.global_position), "%s player spawn must resolve to walkable floor" % mission_id)
		for enemy in level.get_node("Enemies").get_children():
			_expect(world.is_navigation_position_walkable(enemy.global_position), "%s enemy spawn must resolve to walkable floor" % mission_id)
			var route := world.get_navigation_path(level.player.global_position, enemy.global_position)
			_expect(not route.is_empty() or level.player.global_position.distance_to(enemy.global_position) < 8.0, "%s must connect every enemy room to the player route" % mission_id)
		for spec: Dictionary in world.get_door_specs():
			var passage_center: Vector2 = spec.passage_center
			var opening_cell: Vector2i = spec.opening_cell
			var leaf_step := Vector2i(0, 1) if absf(float(spec.rotation)) < 0.1 else Vector2i(1, 0)
			_expect(world.is_navigation_position_walkable(passage_center), "%s door centre must remain on navigable floor" % mission_id)
			_expect(not world.path_grid.is_point_solid(opening_cell), "%s door hinge-side cell must be open" % mission_id)
			_expect(not world.path_grid.is_point_solid(opening_cell + leaf_step), "%s door far-side cell must be open" % mission_id)
		_expect(world.get_door_specs().size() >= 3 and world.get_door_specs().size() <= 7, "%s should use a legible three-to-seven tactical doorway budget" % mission_id)
		_expect(world.get_children().filter(func(child: Node) -> bool: return child is DestructibleProp and child.prop_kind == "sink").size() >= 1, "%s needs a reachable cleanup rinse point" % mission_id)
		if level.mission_profile != null and level.mission_profile.required_security_shutdowns > 0:
			_expect(level._get_security_devices().size() >= level.mission_profile.required_security_shutdowns, "%s must author enough security devices for its objective" % mission_id)
		_expect(level.find_children("*", "LevelLandmark", true, false).size() == 1, "%s needs one signature landmark" % mission_id)
		level.queue_free()
		await get_tree().process_frame
	_expect(signatures.size() == MISSIONS.size(), "all redesigned campaign maps need unique topology signatures")
	if failures == 0: print("campaign map identity regression: PASS")
	get_tree().quit(failures)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
