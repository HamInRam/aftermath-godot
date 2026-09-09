class_name ExpandedRoomCompositions
extends RefCounted

# 52 individually specified compositions. Coordinates are authored percentages,
# not random points; rotation/mirroring is applied later and not counted as rooms.
const PLANS := [
	["atrium_crossfire",18,30,76,20,30,78,80,68,44,24,64,74],
	["atrium_open",22,18,80,38,66,82,18,70,22,48,78,58],
	["atrium_orbit",38,20,82,42,58,80,16,56,48,42,52,64],
	["atrium_breach",24,32,72,18,82,72,38,80,46,54,68,48],
	["library_gallery",18,18,44,72,68,22,82,78,28,44,72,52],
	["library_crossfire",22,40,74,22,34,82,82,60,46,24,62,74],
	["library_defense",24,18,76,36,28,68,64,82,48,42,76,64],
	["library_open",16,36,80,18,76,80,28,76,20,56,80,44],
	["lounge_orbit",30,20,80,34,64,78,18,64,46,42,54,60],
	["lounge_breach",18,26,64,20,80,66,38,78,34,50,66,52],
	["lounge_crossfire",26,18,82,46,20,74,68,82,48,30,46,66],
	["lounge_open",20,20,78,24,82,76,16,68,18,44,80,50],
	["archive_defense",18,22,60,18,82,56,42,80,34,44,64,66],
	["archive_gallery",20,34,42,80,66,18,82,64,34,58,66,44],
	["archive_breach",28,20,76,28,18,72,70,82,46,42,50,66],
	["archive_orbit",48,18,80,56,42,82,18,42,36,40,62,60],
	["kitchen_crossfire",18,38,66,18,82,72,34,80,38,24,62,58],
	["kitchen_breach",32,18,80,30,62,78,18,66,30,46,70,54],
	["kitchen_open",18,20,76,18,82,68,26,82,18,48,78,42],
	["kitchen_defense",24,28,74,20,78,78,28,66,48,36,54,70],
	["warehouse_gallery",18,28,40,78,66,26,82,74,30,52,70,52],
	["warehouse_orbit",36,18,82,48,58,82,18,58,42,38,62,64],
	["warehouse_crossfire",16,44,72,18,82,64,34,82,38,30,62,64],
	["warehouse_breach",24,22,70,32,18,80,80,78,44,48,66,68],
	["salon_open",20,18,82,28,72,82,18,72,18,48,82,56],
	["salon_defense",34,20,80,40,22,62,62,80,48,36,44,68],
	["salon_orbit",46,18,82,62,40,80,18,36,38,38,64,58],
	["salon_crossfire",18,24,74,18,28,78,80,60,44,40,62,74],
	["workshop_breach",22,18,72,26,82,80,34,72,44,48,72,54],
	["workshop_gallery",18,40,40,20,66,80,82,46,32,64,70,32],
	["workshop_defense",30,18,82,34,18,70,66,82,46,36,48,66],
	["workshop_open",16,24,80,18,84,74,22,82,20,52,78,44],
	["chapel_gallery",20,20,40,76,64,20,80,80,30,46,72,50],
	["chapel_crossfire",18,50,60,18,82,56,42,80,30,30,68,76],
	["chapel_breach",32,22,76,18,18,76,74,70,44,44,58,66],
	["chapel_orbit",42,20,80,46,64,80,20,62,40,44,62,60],
	["foyer_open",18,22,82,32,70,82,22,70,18,46,80,58],
	["foyer_breach",26,18,76,40,28,82,80,74,42,42,60,70],
	["foyer_crossfire",22,34,70,18,18,80,78,66,42,24,56,60],
	["foyer_defense",18,18,72,30,34,72,82,82,40,44,70,60],
	["studio_orbit",34,18,82,54,50,82,18,46,40,40,62,62],
	["studio_gallery",18,32,38,80,62,22,82,72,30,56,70,46],
	["studio_open",22,18,80,24,82,80,18,74,20,46,78,56],
	["studio_crossfire",18,28,68,18,32,82,82,62,40,40,64,74],
	["vault_defense",22,20,78,32,20,74,66,80,44,38,50,66],
	["vault_breach",30,18,82,44,24,80,68,72,42,44,68,52],
	["vault_orbit",48,20,80,64,34,82,18,38,38,38,60,60],
	["vault_crossfire",20,44,76,18,26,80,82,72,44,26,58,68],
	["terrace_open",16,28,78,18,84,70,22,80,18,52,80,42],
	["terrace_gallery",20,24,44,80,62,18,82,62,30,48,68,44],
	["terrace_breach",24,18,72,36,18,72,78,82,44,40,60,62],
	["terrace_orbit",38,18,82,38,58,82,18,60,44,38,60,64],
]

static func get_modules() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row: Array in PLANS:
		var enemies: Array[Vector2] = []
		var props: Array[Vector2] = []
		for i in range(4): enemies.append(Vector2(float(row[1+i*2]), float(row[2+i*2])) / 100.0)
		for i in range(2): props.append(Vector2(float(row[9+i*2]), float(row[10+i*2])) / 100.0)
		var kind := str(row[0]).get_slice("_",1)
		var roles: Array = ["gunner","assault","gunner","melee"]
		var patrols: Array = [Vector2.DOWN,Vector2.LEFT,Vector2.UP,Vector2.RIGHT]
		if kind == "breach": roles = ["melee","gunner","assault","gunner"]
		if kind == "defense": roles = ["gunner","heavy","melee","gunner"]
		if kind == "gallery": patrols = [Vector2.RIGHT,Vector2.UP,Vector2.LEFT,Vector2.DOWN]
		result.append({"id": str(row[0]), "enemies": enemies, "props": props, "patrols": patrols, "roles": roles})
	return result

