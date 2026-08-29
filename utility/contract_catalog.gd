class_name ContractCatalog
extends RefCounted

const CONTRACT_ORDER := ["standard", "ghost", "restraint", "silent_blade", "asset_preservation", "total_recovery", "immaculate", "rapid_response"]
const CONTRACTS := {
	"standard": {"name": "STANDARD TERMS", "description": "NO ADDITIONAL CONDITIONS", "payout": 1.0},
	"ghost": {"name": "GHOST PROTOCOL", "description": "COMPLETE WITH ZERO ALARMS", "payout": 1.25},
	"restraint": {"name": "CONTROLLED FORCE", "description": "FIRE NO MORE THAN 8 SHOTS", "payout": 1.20},
	"silent_blade": {"name": "SILENT BLADE", "description": "COMPLETE WITHOUT FIRING A SHOT", "payout": 1.32},
	"asset_preservation": {"name": "ASSET PRESERVATION", "description": "CAUSE ZERO PROPERTY DAMAGE", "payout": 1.28},
	"total_recovery": {"name": "TOTAL RECOVERY", "description": "REMOVE ALL BODIES AND BALLISTIC EVIDENCE", "payout": 1.38},
	"immaculate": {"name": "IMMACULATE", "description": "LEAVE WITH 100% CLEANUP", "payout": 1.35},
	"rapid_response": {"name": "RAPID RESPONSE", "description": "POLICE ETA 90 SECONDS AFTER COMBAT", "payout": 1.40, "cleanup_time": 90.0},
}

static func get_contract(contract_id: String) -> Dictionary:
	var resolved := contract_id if CONTRACTS.has(contract_id) else "standard"
	var contract: Dictionary = (CONTRACTS[resolved] as Dictionary).duplicate(true)
	contract["id"] = resolved
	return contract

static func get_available_contracts(profile: MissionProfile) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for contract_id in CONTRACT_ORDER:
		if profile != null and not profile.is_campaign_mission and contract_id == "rapid_response": continue
		if profile != null and not profile.allowed_contracts.is_empty() and contract_id not in profile.allowed_contracts: continue
		results.append(get_contract(contract_id))
	return results

static func evaluate(contract_id: String, cleanup_ratio: float, alarms: int, shots: int, timed_out: bool, property_damage := 0, bodies := 0, ballistic := 0) -> bool:
	match contract_id:
		"ghost": return alarms == 0
		"restraint": return shots <= 8
		"silent_blade": return shots == 0
		"asset_preservation": return property_damage == 0
		"total_recovery": return bodies == 0 and ballistic == 0 and cleanup_ratio >= 0.90
		"immaculate": return cleanup_ratio >= 0.999
		"rapid_response": return not timed_out and cleanup_ratio >= 0.90
		_: return cleanup_ratio >= 0.90

static func get_operational_forecast(profile: MissionProfile, kit_id: String, contract_id: String) -> String:
	if profile == null: return "INTEL UNAVAILABLE"
	var kit := LoadoutCatalog.get_kit(kit_id)
	var contract := get_contract(contract_id)
	var pressure := "NO RESPONSE CLOCK" if profile.cleanup_pressure_seconds <= 0.0 else "RESPONSE %ds" % roundi(profile.cleanup_pressure_seconds)
	return "INTEL // %s // RESISTANCE %s // %d ROUTES\nHAZARD // %s\nCLEANUP // %s\nPLAN // %s\nFORECAST // %s + %s // %s // TARGET %dMIN" % [profile.location_archetype, profile.expected_resistance, maxi(1, profile.access_routes), profile.primary_hazard, profile.cleanup_complication, profile.recommended_approach, str(kit.name), str(contract.name), pressure, roundi(profile.target_duration_seconds / 60.0)]

static func get_action_review(forensic_report: Dictionary) -> String:
	var alarms := int(forensic_report.get("alarms", 0))
	var shots := int(forensic_report.get("shots", 0))
	var property := int(forensic_report.get("property_damage", 0))
	var bodies := int(forensic_report.get("bodies", 0))
	var ballistic := int(forensic_report.get("ballistic", 0))
	var biological := int(forensic_report.get("biological", 0))
	if bodies > 0: return "REVIEW // BAG BODIES BEFORE DETAIL CLEANING"
	if property >= 3: return "REVIEW // USE CONTROLLED FIRE TO REDUCE RESTORATION"
	if alarms > 0: return "REVIEW // BREAK SIGHTLINES BEFORE THE FIRST SHOT"
	if ballistic >= 4: return "REVIEW // RECOVER WEAPONS AND CASINGS BEFORE MOPPING"
	if biological >= 8 and shots >= 8: return "REVIEW // HIGH FIRE VOLUME CREATED THE PRIMARY CLEANUP LOAD"
	if biological > 0: return "REVIEW // FINISH BIOLOGICAL DETAIL WITH UV CONFIRMATION"
	return "REVIEW // PROFESSIONAL SCENE CONTROL"

static func get_recommended_contract(profile: MissionProfile) -> String:
	if profile == null: return "standard"
	if profile.maximum_alarms_for_bonus == 0 and (profile.allowed_contracts.is_empty() or "ghost" in profile.allowed_contracts): return "ghost"
	if profile.maximum_player_shots_for_bonus >= 0 and (profile.allowed_contracts.is_empty() or "restraint" in profile.allowed_contracts): return "restraint"
	return "standard"
