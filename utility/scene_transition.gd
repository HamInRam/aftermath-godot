class_name SceneTransitionLayer
extends CanvasLayer

var overlay: ColorRect
var busy := false

func _ready() -> void:
	layer = 100
	overlay = ColorRect.new()
	overlay.name = "FadeOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.015, 0.008, 0.025, 0.0)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

func transition_to(scene_path: String, fade_out := 0.16, fade_in := 0.24) -> bool:
	if busy or scene_path.is_empty(): return false
	busy = true
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var out_tween := create_tween().set_ignore_time_scale(true)
	out_tween.tween_property(overlay, "color:a", 1.0, fade_out)
	await out_tween.finished
	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		busy = false
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return false
	await get_tree().process_frame
	var in_tween := create_tween().set_ignore_time_scale(true)
	in_tween.tween_property(overlay, "color:a", 0.0, fade_in)
	await in_tween.finished
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	busy = false
	return true
