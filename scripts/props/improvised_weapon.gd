class_name ImprovisedWeapon
extends CharacterBody2D

const PIXELS := preload("res://utility/pixel_art_painter.gd")
const FORMS := {
	"bottle": ["...ww...", "...ww...", "..iggi..", "..iggi..", "..iggi..", "..iii..."],
	"chair": ["iiiiiiii", "iggggggi", "iiiiiiii", "i......i", "i.gggg.i", "i.gggg.i", "iiiiiiii", "i......i"],
	"club": ["..iii...", "..iwi...", "..igi...", "..igi...", "..igi...", "...g....", "...g....", "...i...."]
}
var kind := "bottle"
var durability := 1
var holder: Node2D
var flight_time := 0.0
var cooldown := 0.0
var swing_time := 0.0
var art_angle := 0.0
var broken := false
var owner_player: Node2D
var shape_node: CollisionShape2D

func configure(value: String) -> void:
	kind = value if FORMS.has(value) else "bottle"
	durability = {"bottle": 1, "chair": 2, "club": 3}[kind]

func _ready() -> void:
	add_to_group("improvised_pickup")
	collision_layer = 4
	collision_mask = 6
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	shape_node = CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 2.0
	shape_node.shape = shape
	add_child(shape_node)
	z_index = 4
	set_physics_process(false)

func collect(player: Node2D) -> bool:
	if broken or is_instance_valid(holder) or flight_time > 0.0: return false
	if is_instance_valid(player.improvised_weapon): player.improvised_weapon.release(false)
	holder = player
	owner_player = player
	collision_layer = 0
	player.improvised_weapon = self
	player.gun.cancel_reload()
	player.gun.visible = false
	player.melee_weapon_visual.visible = false
	player.improvised_loadout_changed.emit()
	remove_from_group("improvised_pickup")
	set_physics_process(true)
	z_index = 11
	return true

func release(throw_it: bool) -> void:
	if not is_instance_valid(holder): return
	var player := holder
	art_angle = player.actual_aim_angle
	# Start at the real actor position; never teleport a throw through thin walls.
	global_position = player.global_position
	player.improvised_weapon = null
	player.gun.visible = player.equipped_mode == "gun" and not player.is_dead
	player.melee_weapon_visual.visible = player.equipped_mode != "gun" and not player.is_dead
	holder = null
	player.improvised_loadout_changed.emit()
	if throw_it:
		velocity = Vector2.RIGHT.rotated(art_angle) * (220.0 if kind == "chair" else 300.0)
		flight_time = 0.65
	else:
		collision_layer = 4
		velocity = Vector2.ZERO
		flight_time = 0.0
		add_to_group("improvised_pickup")
		set_physics_process(false)
	z_index = 4
	queue_redraw()

func strike() -> void:
	if not is_instance_valid(holder) or cooldown > 0.0 or broken: return
	cooldown = 0.38 if kind == "chair" else 0.24
	swing_time = 0.16
	var forward := Vector2.RIGHT.rotated(holder.actual_aim_angle)
	var candidates: Array[Node2D] = []
	for target in get_tree().get_nodes_in_group("enemy") + get_tree().get_nodes_in_group("destructible_prop"):
		if not target is Node2D or target.is_queued_for_deletion(): continue
		var offset: Vector2 = target.global_position - holder.global_position
		if offset.length() > (27.0 if kind == "chair" else 22.0) or forward.dot(offset.normalized()) < 0.35: continue
		if target.is_in_group("enemy") and target.is_dead: continue
		var ray := PhysicsRayQueryParameters2D.create(holder.global_position, target.global_position, 4)
		ray.exclude = [target.get_rid()] if target is CollisionObject2D else []
		if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty(): continue
		candidates.append(target)
	candidates.sort_custom(func(a: Node2D, b: Node2D): return holder.global_position.distance_squared_to(a.global_position) < holder.global_position.distance_squared_to(b.global_position))
	if not candidates.is_empty():
		_hit(candidates[0], forward, holder.global_position)
		durability -= 1
		if is_instance_valid(holder): holder.improvised_loadout_changed.emit()
		if durability <= 0: shatter()
	Events.publish_combat_noise(global_position, 65.0, "melee")

func _hit(target: Node, direction: Vector2, source: Vector2) -> void:
	if target.is_in_group("enemy") and not target.is_dead:
		if target.has_method("apply_stagger"): target.apply_stagger(direction, 0.32)
		# Use the ordinary injury/death event chain; no independent blood minting.
		var amount := int({"bottle": 32, "chair": 48, "club": 38}[kind])
		if is_instance_valid(owner_player): owner_player.improvised_impact.emit(target, source, direction, amount)
		target.apply_ballistic_hit({"health_damage": amount, "hit_zone": "torso", "damage_ratio": 0.45, "lethal": target.hp <= amount}, source)
		if not target.is_dead: target.apply_stagger(direction, 0.32)
	elif target.has_method("receive_thrown_impact"):
		target.receive_thrown_impact(direction, 1.0)

func shatter() -> void:
	if broken: return
	broken = true
	if is_instance_valid(holder): release(false)
	MicroDebrisField.for_scene(self).emit_impact(global_position, Vector2.RIGHT.rotated(art_angle), "glass" if kind == "bottle" else "wood", 1.0)
	queue_free()

func receive_projectile_impact_context(_velocity: Vector2, _point: Vector2, _weapon: String, _damage: int) -> void:
	if not is_instance_valid(holder): shatter()

func _physics_process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	swing_time = maxf(0.0, swing_time - delta)
	if is_instance_valid(holder):
		if holder.is_dead: release(false); return
		art_angle = holder.actual_aim_angle + sin(swing_time / 0.16 * PI) * 0.9
		global_position = (holder.global_position + Vector2.RIGHT.rotated(art_angle) * 9.0).round()
		queue_redraw()
		return
	if flight_time <= 0.0: set_physics_process(false); return
	flight_time -= delta
	var direction := velocity.normalized()
	var collision := move_and_collide(velocity * minf(delta, 0.05))
	art_angle += delta * 16.0
	if collision != null:
		var target := collision.get_collider()
		if target is Node: _hit(target, direction, global_position - direction * 3.0)
		shatter()
		return
	velocity = velocity.move_toward(Vector2.ZERO, delta * 180.0)
	if flight_time <= 0.0:
		collision_layer = 4
		add_to_group("improvised_pickup")
		set_physics_process(false)
	queue_redraw()

func _draw() -> void:
	var rows: Array = FORMS[kind]
	var colors := {"i": Color("111111"), "g": Color("8a8a8a"), "w": Color("eeeeee")}
	for y in rows.size():
		for x in str(rows[y]).length():
			var token: String = str(rows[y])[x]
			if colors.has(token): PIXELS.pixel(self, (Vector2(x - 4, y - 4).rotated(art_angle)).round(), colors[token])
	if is_instance_valid(holder):
		for i in durability: PIXELS.pixel(self, Vector2(i * 2 - 2, 6), Color.WHITE)
