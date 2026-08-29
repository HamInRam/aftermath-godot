class_name MissionResultBuilder
extends RefCounted

static func restoration_cost(property_damage: int, ballistic: int, biological: int) -> int:
	return maxi(0, property_damage) * 75 + maxi(0, ballistic) * 8 + maxi(0, biological) * 2

static func grade(cleanup_ratio: float, alarms: int, property_damage: int) -> String:
	var alarm_performance := maxf(0.0, 1.0 - alarms * 0.15)
	var property_performance := maxf(0.0, 1.0 - property_damage * 0.08)
	var rating := clampf(cleanup_ratio, 0.0, 1.0) * 0.68 + alarm_performance * 0.22 + property_performance * 0.10
	if cleanup_ratio >= 0.999 and alarms == 0: return "S"
	if rating >= 0.9: return "A"
	if rating >= 0.75: return "B"
	if rating >= 0.5: return "C"
	return "D"

static func dominant_cost(property_damage: int, ballistic: int, biological: int, bodies: int) -> String:
	var costs := {
		"PROPERTY": maxi(0, property_damage) * 75,
		"BALLISTIC": maxi(0, ballistic) * 8,
		"BIOLOGICAL": maxi(0, biological) * 2,
		"BODIES": maxi(0, bodies) * 25,
	}
	var result := "NONE"
	var highest := 0
	for category in costs:
		if int(costs[category]) > highest:
			highest = int(costs[category])
			result = str(category)
	return result
