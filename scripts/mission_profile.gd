class_name MissionProfile
extends Resource

@export var mission_id := "standard_cleanup"
@export var display_name := "NO WITNESSES"
@export_multiline var briefing := "ELIMINATE HOSTILES // SECURE THE SCENE"
@export var required_eliminations := -1
@export var required_security_shutdowns := 0
@export var completion_bonus := 500
@export var alarm_penalty := 125
@export_file("*.tscn") var scene_path := ""
@export_multiline var debrief_text := "THE FLOOR IS QUIET. THE EVIDENCE IS NOT."
@export var unlock_after := ""
@export var campaign_order := 0
@export var is_campaign_mission := true
