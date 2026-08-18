class_name EnemyCatalog
extends RefCounted

const PROFILES := {
	"gunner": preload("res://resources/enemies/gunner.tres"),
	"melee": preload("res://resources/enemies/melee.tres"),
	"assault": preload("res://resources/enemies/assault.tres"),
	"heavy": preload("res://resources/enemies/heavy.tres"),
	"dog": preload("res://resources/enemies/dog.tres"),
}

static func get_profile(archetype_id: String) -> EnemyProfile:
	return PROFILES.get(archetype_id, PROFILES.gunner) as EnemyProfile

static func has_profile(archetype_id: String) -> bool:
	return PROFILES.has(archetype_id)
