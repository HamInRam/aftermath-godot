class_name MissionCatalog
extends RefCounted

const MISSION_PROFILES: Array[MissionProfile] = [
	preload("res://resources/missions/nightclub.tres"),
	preload("res://resources/missions/sandwich_shop.tres"),
	preload("res://resources/missions/after_hours.tres"),
	preload("res://resources/missions/harbor_exchange.tres"),
	preload("res://resources/missions/motel_witness.tres"),
	preload("res://resources/missions/penthouse.tres"),
	preload("res://resources/missions/cold_storage.tres"),
	preload("res://resources/missions/casino_floor.tres"),
	preload("res://resources/missions/police_archive.tres"),
	preload("res://resources/missions/slaughterhouse.tres"),
	preload("res://resources/missions/broadcast_tower.tres"),
	preload("res://resources/missions/last_call.tres"),
	preload("res://resources/missions/tactical_lab.tres"),
]

static func get_mission(mission_id: String) -> MissionProfile:
	for profile in MISSION_PROFILES:
		if profile.mission_id == mission_id: return profile
	return null

static func get_all_missions() -> Array[MissionProfile]:
	return MISSION_PROFILES.duplicate()

static func get_campaign_missions() -> Array[MissionProfile]:
	var missions: Array[MissionProfile] = []
	for profile in MISSION_PROFILES:
		if profile.is_campaign_mission: missions.append(profile)
	missions.sort_custom(func(a: MissionProfile, b: MissionProfile) -> bool: return a.campaign_order < b.campaign_order)
	return missions

static func get_next_mission(mission_id: String) -> MissionProfile:
	var missions := get_campaign_missions()
	for index in range(missions.size() - 1):
		if missions[index].mission_id == mission_id: return missions[index + 1]
	return null
