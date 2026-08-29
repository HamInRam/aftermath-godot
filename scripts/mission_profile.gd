class_name MissionProfile
extends Resource

@export var mission_id := "standard_cleanup"
@export var display_name := "NO WITNESSES"
@export_multiline var briefing := "ELIMINATE HOSTILES // SECURE THE SCENE"
@export var required_eliminations := -1
@export var required_security_shutdowns := 0
@export var completion_bonus := 500
@export var alarm_penalty := 125
@export var optional_quiet_bonus := 200
@export var maximum_alarms_for_bonus := -1
@export var maximum_player_shots_for_bonus := -1
@export var property_damage_penalty := 25
@export_file("*.tscn") var scene_path := ""
@export_multiline var debrief_text := "THE FLOOR IS QUIET. THE EVIDENCE IS NOT."
@export var unlock_after := ""
@export var campaign_order := 0
@export var is_campaign_mission := true
@export_range(0.0, 600.0, 5.0) var cleanup_pressure_seconds := 0.0
@export_group("Operational Intelligence")
@export var location_archetype := "COMMERCIAL INTERIOR"
@export var expected_resistance := "MODERATE"
@export var access_routes := 2
@export_multiline var primary_hazard := "UNKNOWN SIGHTLINES"
@export_multiline var cleanup_complication := "BIOLOGICAL AND BALLISTIC EVIDENCE"
@export_multiline var recommended_approach := "CONTROL THE FIRST ROOM // PRESERVE AN EXIT ROUTE"
@export var allowed_contracts := PackedStringArray()
@export_range(180.0, 1200.0, 15.0) var target_duration_seconds := 600.0
@export_range(0.25, 0.75, 0.05) var target_combat_ratio := 0.5
@export_group("Mission Identity")
@export var signature_rule := "CONTROL SPACE // CONTROL CONSEQUENCES"
@export var combat_hook := "LETHAL ROOM CONTROL"
@export var cleanup_hook := "RECOVER BODIES AND BALLISTICS"
