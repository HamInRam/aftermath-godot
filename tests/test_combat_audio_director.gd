extends Node

var failures := 0

func _ready() -> void:
	var director := CombatAudioDirector.new()
	var combat_stream := AudioStreamWAV.new()
	var ambience_stream := AudioStreamWAV.new()
	director.combat_stream = combat_stream
	director.ambience_stream = ambience_stream
	director.autoplay = false
	director.combat_volume_db = -3.0
	director.combat_ambience_volume_db = -20.0
	add_child(director)
	_expect(director.combat_player.stream == combat_stream, "combat music should configure itself on ready")
	_expect(director.ambience_player.stream == ambience_stream, "room ambience should configure itself on ready")
	_expect(is_equal_approx(director.combat_player.volume_db, -3.0), "combat volume should use the scene setting")
	_expect(is_equal_approx(director.ambience_player.volume_db, -20.0), "ambience volume should use the scene setting")
	director.ambience_stream = null
	director._on_combat_ended()
	_expect(director.mix_state == CombatAudioDirector.MixState.CLEANUP_SILENCE, "combat end should enter the cleanup mix")
	if failures == 0: print("combat audio director regression: PASS")
	director.combat_player.stop()
	director.ambience_player.stop()
	director.configure_music(null, null)
	director.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(failures)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
