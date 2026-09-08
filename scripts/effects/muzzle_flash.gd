extends Node2D

const PIXELS := preload("res://utility/pixel_art_painter.gd")
const PIXEL_LIGHTS := preload("res://utility/pixel_light_texture_factory.gd")

var flash_size := 26.0
var duration := 0.045
var elapsed := 0.0
var flash_direction := Vector2.RIGHT
var blood_enhanced := false
var seed_variant := 0
@onready var light: PointLight2D = $PointLight2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	light.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	light.texture = PIXEL_LIGHTS.create_texture()
	light.texture_scale = 1.0
	light.color = Color("d10b32") if blood_enhanced else Color.WHITE
	light.energy = 0.65
	seed_variant = randi_range(0, 2)
	queue_redraw()

func setup(direction: Vector2, size: float, flash_duration: float, enhanced := false) -> void:
	flash_direction = direction.normalized() if direction.length_squared() > 0.001 else Vector2.RIGHT
	rotation = 0.0
	flash_size = size
	duration = clampf(flash_duration, 0.035, 0.065)
	set_blood_enhanced(enhanced)

func set_blood_enhanced(enabled: bool) -> void:
	blood_enhanced = enabled
	if is_instance_valid(light): light.color = Color("d10b32") if enabled else Color.WHITE
	queue_redraw()

func _process(delta: float) -> void:
	# Explicit real-time envelope; even a hard impact does not leave the flash
	# covering a target for the whole hit-stop.
	elapsed += delta / maxf(0.05, Engine.time_scale)
	if elapsed >= duration:
		queue_free()
		return
	if is_instance_valid(light): light.energy = 0.65 * (1.0 - elapsed / duration)
	queue_redraw()

func _draw() -> void:
	var progress := clampf(elapsed / duration, 0.0, 1.0)
	var reach := maxi(2, roundi(clampf(flash_size * 0.24, 3.0, 11.0) * (1.0 - progress * 0.55)))
	var core := Color("ffffff")
	var edge := Color("d10b32") if blood_enhanced else Color("adadad")
	var side := flash_direction.orthogonal()
	draw_set_transform_matrix(global_transform.affine_inverse())
	# Short white-hot diamond and a forked tip, drawn as 1px cells in world axes.
	for x in range(reach + 1):
		var width := maxi(0, 2 - absi(x - 2)) if progress < 0.6 else 0
		for y in range(-width, width + 1):
			PIXELS.pixel(self, (global_position + flash_direction * float(x) + side * float(y)).round(), core if y == 0 else edge)
	if progress < 0.45:
		for sign_value in [-1, 1]:
			var branch := global_position + flash_direction * float(reach - 1) + side * float(sign_value * (2 + seed_variant % 2))
			PIXELS.pixel(self, branch.round(), edge)
	draw_set_transform_matrix(Transform2D.IDENTITY)
