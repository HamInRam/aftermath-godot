class_name CombatAudioDirector
extends Node

enum MixState { COMBAT, CLEANUP_SILENCE }

@export var combat_stream: AudioStream
@export var ambience_stream: AudioStream
@export var danger_stream: AudioStream
@export_range(-60.0, 6.0, 0.5) var combat_volume_db := 0.0
@export_range(-60.0, 6.0, 0.5) var combat_ambience_volume_db := -18.0
@export_range(-60.0, 6.0, 0.5) var cleanup_ambience_volume_db := -10.0
@export var autoplay := true

var mix_state := MixState.COMBAT
var combat_player: AudioStreamPlayer
var ambience_player: AudioStreamPlayer
var danger_player: AudioStreamPlayer
var combat_intensity := 0.12
var target_intensity := 0.12
var event_pressure := 0.0
var threat_sample_timer := 0.0

func _ready() -> void:
	if DisplayServer.get_name() == "headless": autoplay = false
	combat_player = AudioStreamPlayer.new()
	ambience_player = AudioStreamPlayer.new()
	danger_player = AudioStreamPlayer.new()
	combat_player.name = "CombatMusic"
	ambience_player.name = "RoomAmbience"
	danger_player.name = "DangerLayer"
	combat_player.bus = "Music"
	danger_player.bus = "Music"
	ambience_player.bus = "Ambience"
	add_child(combat_player)
	add_child(ambience_player)
	add_child(danger_player)
	Events.combat_ended.connect(_on_combat_ended)
	Events.weapon_fired.connect(_on_weapon_fired)
	Events.combat_noise.connect(_on_combat_noise)
	Events.tactical_alert.connect(_on_tactical_alert)
	if combat_stream == null: combat_stream = ProceduralAudioLibrary.get_loop("pulse")
	if danger_stream == null: danger_stream = ProceduralAudioLibrary.get_loop("danger")
	if ambience_stream == null: ambience_stream = ProceduralAudioLibrary.get_loop("ambience")
	configure_music(combat_stream, ambience_stream)
	danger_player.stream = danger_stream
	danger_player.volume_db = -60.0
	if autoplay and danger_stream != null: danger_player.play()

func _process(delta: float) -> void:
	if mix_state != MixState.COMBAT: return
	event_pressure = maxf(0.0, event_pressure - delta * 0.16)
	threat_sample_timer -= delta
	if threat_sample_timer <= 0.0:
		threat_sample_timer = 0.25
		_sample_active_threat()
	var desired_intensity := maxf(0.1, maxf(event_pressure, target_intensity))
	combat_intensity = move_toward(combat_intensity, desired_intensity, delta * (1.8 if desired_intensity > combat_intensity else 0.42))
	combat_player.volume_db = lerpf(combat_volume_db - 18.0, combat_volume_db, combat_intensity)
	combat_player.pitch_scale = lerpf(0.94, 1.05, combat_intensity)
	var danger_mix := clampf((combat_intensity - 0.42) / 0.58, 0.0, 1.0)
	danger_player.volume_db = lerpf(-60.0, -5.0, danger_mix)
	ambience_player.volume_db = lerpf(combat_ambience_volume_db, combat_ambience_volume_db - 7.0, combat_intensity)

func configure_music(combat_music: AudioStream, room_ambience: AudioStream = null) -> void:
	combat_stream = combat_music
	ambience_stream = room_ambience
	combat_player.stream = combat_stream
	ambience_player.stream = ambience_stream
	combat_player.volume_db = lerpf(combat_volume_db - 18.0, combat_volume_db, combat_intensity) if autoplay else combat_volume_db
	ambience_player.volume_db = combat_ambience_volume_db
	if autoplay and combat_stream != null: combat_player.play()
	if autoplay and ambience_stream != null: ambience_player.play()

func _sample_active_threat() -> void:
	var alive := 0
	var engaged := 0
	for enemy_node in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy_node) or bool(enemy_node.get("is_dead")): continue
		alive += 1
		if enemy_node.has_method("is_actively_engaging_player") and enemy_node.is_actively_engaging_player(): engaged += 1
	target_intensity = 0.12 if alive == 0 else clampf(0.12 + float(engaged) / float(alive) * 0.88, 0.12, 1.0)

func _on_weapon_fired(_origin: Vector2, _direction: Vector2, enemy_owned: bool, _weapon_id: String) -> void:
	event_pressure = maxf(event_pressure, 0.58 if enemy_owned else 0.72)

func _on_combat_noise(_world_position: Vector2, _radius: float, source_kind: String) -> void:
	if source_kind == "security_alarm": event_pressure = 1.0
	elif source_kind in ["execution", "melee"]: event_pressure = maxf(event_pressure, 0.62)

func _on_tactical_alert(_world_position: Vector2, _direction: Vector2, source_kind: String, _reporter: Node) -> void:
	event_pressure = maxf(event_pressure, 1.0 if source_kind in ["security_camera", "security_alarm"] else 0.78)

func _on_combat_ended() -> void:
	mix_state = MixState.CLEANUP_SILENCE
	set_process(false)
	if combat_player.playing:
		var tween := create_tween()
		tween.tween_property(combat_player, "volume_db", -60.0, 0.12)
		tween.tween_callback(combat_player.stop)
	if danger_player.playing:
		var danger_tween := create_tween()
		danger_tween.tween_property(danger_player, "volume_db", -60.0, 0.08)
		danger_tween.tween_callback(danger_player.stop)
	if autoplay and ambience_stream != null:
		if not ambience_player.playing: ambience_player.play()
		ambience_player.volume_db = -28.0
		create_tween().tween_property(ambience_player, "volume_db", cleanup_ambience_volume_db, 1.2)

func _exit_tree() -> void:
	for audio_player in [combat_player, danger_player, ambience_player]:
		if not is_instance_valid(audio_player): continue
		audio_player.stop()
		audio_player.stream = null
	combat_stream = null
	danger_stream = null
	ambience_stream = null
