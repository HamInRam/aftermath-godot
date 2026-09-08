class_name NoirPresenterLayer
extends CanvasLayer

## Global art-direction gate. It lives above menus, HUD and world rendering so
## every future screen inherits the same grayscale/crimson contract by default.

const SCREEN_SHADER := preload("res://shaders/screen_effect.gdshader")

var overlay: ColorRect
var screen_material: ShaderMaterial

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	screen_material = ShaderMaterial.new()
	screen_material.shader = SCREEN_SHADER
	overlay = ColorRect.new()
	overlay.name = "NoirGrade"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.color = Color.WHITE
	overlay.material = screen_material
	overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(overlay)
	set_effects_enabled(Settings.screen_effects_enabled)
	set_chromatic_strength(Settings.chromatic_aberration_strength)

func get_screen_material() -> ShaderMaterial:
	return screen_material

func set_effects_enabled(enabled: bool) -> void:
	if is_instance_valid(screen_material): screen_material.set_shader_parameter("enable_effect", enabled)

func set_chromatic_strength(strength: float) -> void:
	# Native 1x1 clarity wins over simulated registration error. Keep the setting
	# schema compatible, but never shift a world pixel away from its integer cell.
	if is_instance_valid(screen_material): screen_material.set_shader_parameter("chromatic_aberration", 0.0 * strength)

func set_focus_amount(amount: float) -> void:
	if is_instance_valid(screen_material): screen_material.set_shader_parameter("focus_amount", clampf(amount, 0.0, 1.0))

func set_blood_stance_amount(amount: float) -> void:
	if is_instance_valid(screen_material): screen_material.set_shader_parameter("blood_stance_amount", clampf(amount, 0.0, 1.0))
