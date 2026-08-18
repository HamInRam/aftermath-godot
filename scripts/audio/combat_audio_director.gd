class_name CombatAudioDirector
extends Node

enum MixState { COMBAT, CLEANUP_SILENCE }

@export var combat_stream: AudioStream
@export var ambience_stream: AudioStream
@export_range(-60.0, 6.0, 0.5) var combat_volume_db := 0.0
@export_range(-60.0, 6.0, 0.5) var combat_ambience_volume_db := -18.0
@export_range(-60.0, 6.0, 0.5) var cleanup_ambience_volume_db := -10.0
@export var autoplay := true

var mix_state := MixState.COMBAT
var combat_player: AudioStreamPlayer
var ambience_player: AudioStreamPlayer

func _ready() -> void:
	combat_player = AudioStreamPlayer.new()
	ambience_player = AudioStreamPlayer.new()
	combat_player.name = "CombatMusic"
	ambience_player.name = "RoomAmbience"
	add_child(combat_player)
	add_child(ambience_player)
	Events.combat_ended.connect(_on_combat_ended)
	configure_music(combat_stream, ambience_stream)

func configure_music(combat_music: AudioStream, room_ambience: AudioStream = null) -> void:
	combat_stream = combat_music
	ambience_stream = room_ambience
	combat_player.stream = combat_stream
	ambience_player.stream = ambience_stream
	combat_player.volume_db = combat_volume_db
	ambience_player.volume_db = combat_ambience_volume_db
	if autoplay and combat_stream != null: combat_player.play()
	if autoplay and ambience_stream != null: ambience_player.play()

func _on_combat_ended() -> void:
	mix_state = MixState.CLEANUP_SILENCE
	if combat_player.playing:
		var tween := create_tween()
		tween.tween_property(combat_player, "volume_db", -60.0, 0.12)
		tween.tween_callback(combat_player.stop)
	if autoplay and ambience_stream != null:
		if not ambience_player.playing: ambience_player.play()
		ambience_player.volume_db = -28.0
		create_tween().tween_property(ambience_player, "volume_db", cleanup_ambience_volume_db, 1.2)
