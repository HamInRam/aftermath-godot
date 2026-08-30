extends Node2D

var failures := 0
var restored_events := 0

func _ready() -> void:
	CleanupRegistry.reset()
	Events.prop_restored.connect(func(_position: Vector2, _kind: String) -> void: restored_events += 1)
	call_deferred("_run")

func _run() -> void:
	var prop := DestructibleProp.new()
	prop.setup("plant", Color("5bcf8d"))
	prop.global_position = Vector2(80, 60)
	add_child(prop)
	await get_tree().process_frame
	await get_tree().process_frame
	var home := prop.global_position
	prop.receive_projectile_impact_context(Vector2.RIGHT * 650.0, prop.global_position, "shotgun", 2)
	_expect(prop.is_displaced(), "a light decorative object should become displaced after a weapon impact")
	_expect(prop.state == DestructibleProp.PropState.DAMAGED, "a launched prop should retain a recognizable damaged core")
	_expect(prop.velocity.length() > 0.0, "weapon and distance response should produce controlled launch velocity")
	_expect(CleanupRegistry.get_type_counts().get("furniture", 0) == 1, "a displaced object should become an explicit cleanup target")
	var anchor := prop.get_restoration_anchor()
	_expect(is_instance_valid(anchor) and not anchor.visible, "original-location ghost should remain hidden during combat")
	prop.enter_cleanup_restore_state()
	await get_tree().process_frame
	_expect(anchor.visible, "cleanup should reveal the object's cyan original-location ghost")
	var actor := Node2D.new()
	actor.global_position = home + Vector2(5, 0)
	actor.rotation = 0.0
	add_child(actor)
	prop.global_position = home + Vector2(10, 0)
	_expect(prop.begin_drag(actor), "cleanup actor should be able to drag a displaced prop")
	prop._physics_process(0.016)
	_expect(not prop.is_displaced(), "a dragged object inside its slot should auto-snap and become fixed")
	_expect(prop.global_position.is_equal_approx(home), "slot snapping should restore the exact authored position")
	_expect(prop.state == DestructibleProp.PropState.RESTORED, "snapped prop should enter the stable restored state")
	_expect(CleanupRegistry.get_type_counts().get("furniture", 0) == 0, "snapping should resolve the furniture cleanup target")
	_expect(restored_events == 1, "restoration should publish one scoring/UI event")
	_expect(not anchor.visible, "restored objects should hide their ghost slot")
	var fixture := DestructibleProp.new()
	fixture.setup("sink", Color("71d4d8"))
	fixture.global_position = Vector2(130, 60)
	add_child(fixture)
	fixture.receive_projectile_impact_context(Vector2.RIGHT * 650.0, fixture.global_position, "pistol", 1)
	_expect(fixture.state == DestructibleProp.PropState.DAMAGED and not fixture.is_displaced(), "heavy fixtures should chip and partially break without being launched")
	fixture.receive_projectile_impact_context(Vector2.RIGHT * 650.0, fixture.global_position, "pistol", 1)
	await get_tree().process_frame
	_expect(fixture.state == DestructibleProp.PropState.DESTROYED, "repeated hits should fully break a heavy fixture")
	if failures == 0: print("prop restoration regression: PASS")
	get_tree().quit(failures)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
