class_name MicroDebrisField
extends Node2D

## Cosmetic fragments never damage actors or enter the blood ledger.
const LIMIT := 512
const RAY_BUDGET := 64
var fragments: Array[Dictionary] = []
var replacement := 0
var simulation_cursor := 0
var magnet_actor: Node2D
var magnet_enabled := false
var magnet_clock := 0.0
var body_cursor := 0
var erosion_audio: AudioStreamPlayer2D
var last_erosion_ms := -1000
var erosion_chain := 0

func play_erosion_tick(point: Vector2) -> void:
	var now := Time.get_ticks_msec()
	if now - last_erosion_ms < 65: return
	erosion_chain = mini(12, erosion_chain + 1) if now - last_erosion_ms < 400 else 0
	last_erosion_ms = now
	if erosion_audio == null:
		erosion_audio = AudioStreamPlayer2D.new()
		erosion_audio.stream = preload("res://assets/audio/sfx/casing_03.wav")
		erosion_audio.bus = "SFX"
		erosion_audio.volume_db = -19
		add_child(erosion_audio)
	erosion_audio.global_position = point
	erosion_audio.pitch_scale = minf(1.65, 0.85 + erosion_chain * 0.065)
	if DisplayServer.get_name() != "headless": erosion_audio.play()

static func for_scene(node: Node) -> MicroDebrisField:
	var root := node.get_tree().current_scene
	if root == null: root = node.get_parent()
	var field := root.get_node_or_null("MicroDebrisField") as MicroDebrisField
	if field == null:
		field = MicroDebrisField.new()
		field.name = "MicroDebrisField"
		root.add_child(field)
	return field

func _ready() -> void:
	z_index = 3
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func emit_impact(point: Vector2, direction: Vector2, material_name: String, strength := 1.0) -> void:
	set_physics_process(true)
	var count := clampi(roundi(16 * strength), 8, 32)
	for i in count:
		var paper := material_name in ["paper", "fabric", "carpet"]
		var metal := material_name in ["metal", "electronic", "electronics"]
		var color := Color("dddddd") if i % 3 == 0 else Color("777777")
		if material_name == "wood": color = Color("d0d0d0") if i % 3 == 0 else Color("555555")
		if paper: color = Color("eeeeee")
		if metal: color = Color("ffffff") if i % 3 != 0 else Color("171717")
		var fragment := {"p": point, "v": -direction.normalized().rotated(randf_range(-1.0, 1.0)) * randf_range(42, 135), "color": color, "air": 0.5 if paper else 0.3, "paper": paper, "spark": metal and i % 3 != 0, "collected": false}
		if fragments.size() < LIMIT: fragments.append(fragment)
		else:
			fragments[replacement] = fragment
			replacement = (replacement + 1) % LIMIT
	queue_redraw()

func emit_scuff(point: Vector2, direction: Vector2) -> void:
	set_physics_process(true)
	for i in range(6):
		var fragment := {"p": point + direction.orthogonal() * randf_range(-4,4), "v": -direction.normalized().rotated(randf_range(-0.6,0.6)) * randf_range(12,28), "color": Color("777777") if i % 2 else Color("333333"), "air": 0.16, "paper": false, "spark": false, "collected": true, "scuff_life": 0.2}
		if fragments.size() < LIMIT: fragments.append(fragment)
	queue_redraw()

func breach_wave(point: Vector2, direction: Vector2) -> void:
	set_physics_process(true)
	var side := direction.normalized().orthogonal()
	var affected := 0
	for fragment in fragments:
		if affected >= 48: break
		var offset: Vector2 = fragment.p - point
		if offset.length_squared() > 32.0 * 32.0: continue
		var sign_side := 1.0 if offset.dot(side) >= 0 else -1.0
		fragment.v = (side * sign_side * 100.0 - direction.normalized() * 25.0).limit_length(110.0)
		fragment.air = 0.25
		affected += 1

func captures(point: Vector2) -> bool:
	if not magnet_enabled or not is_instance_valid(magnet_actor): return false
	var offset := point - magnet_actor.global_position
	if offset.length_squared() > 224.0 * 224.0: return false
	var forward := (magnet_actor.get_global_mouse_position() - magnet_actor.global_position).normalized()
	return offset.length_squared() <= 48.0 * 48.0 or offset.normalized().dot(forward) >= cos(PI / 4.0)

func _physics_process(delta: float) -> void:
	var scuff_active := false
	for i in range(fragments.size()-1,-1,-1):
		if fragments[i].has("scuff_life"):
			scuff_active = true
			fragments[i].scuff_life -= delta
			if fragments[i].scuff_life <= 0.0:
				fragments.remove_at(i)
				queue_redraw()
	var rays := 0
	var changed := false
	for index in fragments.size():
		var f := fragments[(simulation_cursor + index) % fragments.size()]
		var pulling: bool = not f.collected and captures(f.p)
		if pulling:
			var offset: Vector2 = magnet_actor.global_position - f.p
			if offset.length() <= 10:
				f.collected = true
				f.v = Vector2.ZERO
			else: f.v = offset.normalized() * minf(150.0, offset.length() * 6.0) + offset.normalized().orthogonal() * 18.0
		if f.v.length_squared() < 1: continue
		if rays >= RAY_BUDGET: continue
		var destination: Vector2 = f.p + f.v * delta
		var query := PhysicsRayQueryParameters2D.create(f.p, destination, 4)
		var hit := get_world_2d().direct_space_state.intersect_ray(query)
		rays += 1
		if not hit.is_empty():
			f.p = hit.position + hit.normal
			f.v = f.v.bounce(hit.normal) * 0.22
			# Stop magnetic attempts against a wall until RMB is released.
			if pulling: f.collected = true
		else: f.p = destination
		f.air = maxf(0.0, f.air - delta)
		if not pulling: f.v *= exp(-(2.0 if f.paper and f.air > 0 else 9.0) * delta)
		changed = true
	# Share the unchanged ray budget across new and old fragments; otherwise
	# the first moving scraps can starve newly spawned impact feedback.
	if not fragments.is_empty(): simulation_cursor = (simulation_cursor + RAY_BUDGET) % fragments.size()
	magnet_clock += delta
	if magnet_enabled and magnet_clock >= 0.05:
		magnet_clock = 0
		var bodies := get_tree().get_nodes_in_group("siphon_scrap")
		for i in mini(16, bodies.size()):
			body_cursor %= bodies.size()
			var body = bodies[body_cursor]
			body_cursor += 1
			if captures(body.global_position):
				var query := PhysicsRayQueryParameters2D.create(body.global_position, magnet_actor.global_position, 4)
				if get_world_2d().direct_space_state.intersect_ray(query).is_empty(): body.siphon_toward(magnet_actor.global_position)
	if changed: queue_redraw()
	elif not magnet_enabled and not scuff_active: set_physics_process(false)

func set_magnet(actor: Node2D, active: bool) -> void:
	if magnet_enabled and not active:
		for f in fragments: f.collected = false
	magnet_actor = actor
	magnet_enabled = active
	if active: set_physics_process(true)

func _draw() -> void:
	for f in fragments:
		var point := to_local(f.p).round()
		draw_rect(Rect2(point, Vector2.ONE), f.color)
		if f.spark and f.air > 0:
			draw_rect(Rect2(point - Vector2(f.v).normalized().round(), Vector2.ONE), f.color)
