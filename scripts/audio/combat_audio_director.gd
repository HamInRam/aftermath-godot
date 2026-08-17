class_name CombatAudioDirector
extends Node

enum MixState { COMBAT, CLEANUP_SILENCE }

var mix_state := MixState.COMBAT
var combat_stream: AudioStream
var ambience_stream: AudioStream

func _ready() -> void:
	Events.combat_ended.connect(_on_combat_ended)

func configure_music(combat_music: AudioStream, room_ambience: AudioStream = null) -> void:
	combat_stream = combat_music
	ambience_stream = room_ambience

func _on_combat_ended() -> void:
	mix_state = MixState.CLEANUP_SILENCE
