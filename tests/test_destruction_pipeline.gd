extends Node2D

var failures := 0
var setpiece_events := 0

func _ready() -> void:
	Events.setpiece_triggered.connect(func(_position: Vector2, _kind: String, _hazard: String) -> void: setpiece_events += 1)
	var material_names := {}
	for kind in ["table", "bottle", "tv", "vending", "sofa", "sink"]:
		var profile := DestructionMaterial.for_kind(kind)
		material_names[profile.material] = true
	_expect(material_names.size() == 6, "common props should resolve to six distinct destruction materials")
	var prop := DestructibleProp.new()
	add_child(prop)
	prop.setup("sink", Color("71d4d8"))
	prop.receive_projectile_impact_context(Vector2.RIGHT * 650.0, prop.global_position, "pistol", 1)
	_expect(prop.state == DestructibleProp.PropState.DAMAGED and prop.structural_stage == 1, "first normal-energy impact should create structural damage")
	prop.receive_door_impact(Vector2.RIGHT, 1.2)
	await get_tree().process_frame
	_expect(prop.state == DestructibleProp.PropState.DESTROYED, "second energetic impact should structurally collapse the prop")
	_expect(get_tree().get_nodes_in_group("environment_debris").size() >= 2, "collapse should spawn budgeted physical major chunks")
	_expect(get_tree().get_nodes_in_group("environment_hazard").any(func(node: Node) -> bool: return node is EnvironmentHazard and node.hazard_kind == "water"), "ceramic plumbing should create a persistent water hazard")
	_expect(prop.interact(), "destroyed source should remain restorable during cleanup")
	_expect(is_instance_valid(prop.active_hazard) and not prop.active_hazard.source_active, "restoring the source should stop continued leakage")
	var debris := get_tree().get_nodes_in_group("environment_debris")[0] as PhysicalDebris
	_expect(debris.get_cleanup_type() == "debris", "major fragments should become explicit cleanup evidence")
	debris.clean_step()
	var setpiece_kinds := ["dj_booth", "diner_counter", "training_target", "cargo_crane", "motel_sign", "city_window", "freezer_fans", "roulette", "evidence_wall", "conveyor", "broadcast_console", "broken_dj"]
	for index in setpiece_kinds.size():
		var landmark := LevelLandmark.new()
		add_child(landmark)
		landmark.position = Vector2(index * 40.0, 80.0)
		landmark.setup(setpiece_kinds[index], Color("ff3f86"))
		landmark.take_damage(3, landmark.global_position - Vector2.RIGHT)
	await get_tree().process_frame
	_expect(setpiece_events == setpiece_kinds.size(), "all twelve campaign landmarks should trigger a distinct chain-reaction event")
	_expect(get_tree().get_nodes_in_group("environment_hazard").size() >= setpiece_kinds.size(), "setpiece destruction should leave persistent tactical and cleanup consequences")
	_expect(RuntimeBudget.get_count("debris") <= int(RuntimeBudget.limits.debris), "layered physical chunks must remain inside the global debris budget")
	_expect(RuntimeBudget.get_count("hazard") <= int(RuntimeBudget.limits.hazard), "persistent setpiece consequences must remain inside the hazard budget")
	if failures == 0: print("destruction pipeline regression: PASS")
	get_tree().quit(failures)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
