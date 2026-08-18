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
	_expect(director.combat_player.bus == "Music" and director.ambience_player.bus == "Ambience", "music and room tone should use independent audio buses")
	_expect(director.danger_player.stream is AudioStreamWAV, "missing danger music should receive an original procedural loop")
	director._on_weapon_fired(Vector2.ZERO, Vector2.RIGHT, false, "pistol")
	var previous_intensity := director.combat_intensity
	director._process(0.1)
	_expect(director.event_pressure >= 0.7 and director.combat_intensity > previous_intensity, "player gunfire should immediately raise dynamic music pressure")
	var pulse := ProceduralAudioLibrary.get_loop("pulse")
	_expect(pulse == ProceduralAudioLibrary.get_loop("pulse"), "procedural loops should be cached instead of regenerated per level")
	_expect(pulse.loop_mode == AudioStreamWAV.LOOP_FORWARD and pulse.data.size() == ProceduralAudioLibrary.MIX_RATE * 8, "procedural music should be a seamless four-second 16-bit loop")
	director.ambience_stream = null
	director._on_combat_ended()
	_expect(director.mix_state == CombatAudioDirector.MixState.CLEANUP_SILENCE, "combat end should enter the cleanup mix")
	if failures == 0: print("combat audio director regression: PASS")
	director.combat_player.stop()
	director.ambience_player.stop()
	director.danger_player.stop()
	director.configure_music(null, null)
	director.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(failures)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
