class_name DetachedLimb
extends CharacterBody2D

const PIXEL_PAINTER := preload("res://utility/pixel_art_painter.gd")
const ACTOR_ART := preload("res://utility/pixel_actor_art.gd")

var limb_kind := "arm"
var visual_role := "gunner"
var spin := 0.0
var simulated_rotation := 0.0
var trail_distance := 0.0
var previous_position := Vector2.ZERO
var settled := false
var allow_blood_trail := true

func _ready() -> void:
	z_index = 6
	collision_layer = 0
	collision_mask = 4
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 2.0 if limb_kind == "head" else 1.5
	collision.shape = shape
	add_child(collision)
	add_to_group("gore_limb")
	previous_position = global_position

func setup(kind: String, direction: Vector2, intensity: float, blood_trail := true) -> void:
	limb_kind = kind
	allow_blood_trail = blood_trail
	velocity = direction.normalized().rotated(randf_range(-0.42, 0.42)) * randf_range(48.0, 88.0) * clampf(intensity, 0.8, 2.0)
	spin = randf_range(-11.0, 11.0)
	rotation = randf_range(-PI, PI)
	simulated_rotation = rotation
	queue_redraw()

func _physics_process(delta: float) -> void:
	if settled: return
	var collision := move_and_collide(velocity * delta)
	if collision != null:
		velocity = velocity.bounce(collision.get_normal()) * 0.22
		spin *= 0.35
		Events.publish_combat_noise(collision.get_position(), 46.0, "gore_impact")
	trail_distance += global_position.distance_to(previous_position)
	if allow_blood_trail and trail_distance >= 7.0:
		var blood_system := get_tree().get_first_node_in_group("blood_system")
		if is_instance_valid(blood_system) and blood_system.has_method("spawn_micro_drop"):
			blood_system.spawn_micro_drop(global_position, 0.45, previous_position.direction_to(global_position))
		trail_distance = 0.0
	previous_position = global_position
	velocity = velocity.move_toward(Vector2.ZERO, 110.0 * delta)
	# Keep continuous angular momentum before choosing the sharp rendered frame.
	# Rounding each incremental step used to erase every sub-45-degree impulse.
	simulated_rotation += spin * delta
	rotation = snappedf(simulated_rotation, PI / 8.0)
	spin = move_toward(spin, 0.0, 10.0 * delta)
	if velocity.length() < 2.0:
		settled = true
		velocity = Vector2.ZERO
		set_physics_process(false)

func _draw() -> void:
	var colors := ACTOR_ART.palette(visual_role)
	var cells := {}
	if visual_role == "hound" and limb_kind != "head":
		ACTOR_ART._stamp(cells, [".ni...", "icci..", ".iggi.", "..iggi", "...ii."], Vector2.ZERO, colors, "paw")
	elif limb_kind == "leg":
		# Trouser leg, bent knee and boot remain one recognisable severed chain.
		ACTOR_ART._stamp(cells, ["..iii......", ".nbbbi.....", "inbbbiii...", ".iibbbbbi..", "...iiibbbi.", "......ibbi.", ".......iii."], Vector2.ZERO, colors, "leg")
	elif limb_kind == "head":
		var head_rows := ACTOR_ART.HOUND_HEAD if visual_role == "hound" else (ACTOR_ART.MASK if visual_role == "player" else ACTOR_ART.CROWN)
		ACTOR_ART._stamp(cells, head_rows, Vector2.ZERO, colors, "head")
		ACTOR_ART._put(cells, Vector2(-2, 0), colors.n, "cut")
	else:
		# An upper sleeve narrows at the elbow, then ends in a cuff and palm.
		ACTOR_ART._stamp(cells, ["..iii.....", ".nuuui....", "inuuuuiii.", ".iiuuuuhhi", "...iiuuhhi", ".....iiii."], Vector2.ZERO, colors, "arm")
	var rotated := ACTOR_ART.rotate_pixels(cells, global_rotation)
	draw_set_transform(Vector2.ZERO, -global_rotation, Vector2.ONE)
	for cell: Vector2 in rotated: PIXEL_PAINTER.pixel(self, cell, rotated[cell].color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
