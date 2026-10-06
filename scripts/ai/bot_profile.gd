class_name BotProfile
extends Resource
## Decision tuning. No bonuses, hidden knowledge, or forced outcomes.
@export_group("Identity")
@export var profile_id := "balanced"
@export var display_name := "Balanced"
@export var profile_version := 1
@export_group("Planning")
## Number of future threat steps considered in movement scoring.
@export_range(1, 4) var lookahead_depth := 2
## Maximum scored movement options retained per unit.
@export_range(8, 256) var candidate_limit := 64
## Soft assignment limit; excess units prefer another strategic destination.
@export_range(1, 8) var coordination_limit := 2
@export_group("Priorities")
@export_range(0.0, 3.0) var economy_weight := 1.0
@export_range(0.0, 3.0) var expansion_weight := 1.0
@export_range(0.0, 3.0) var defense_weight := 1.2
@export_range(0.0, 3.0) var research_weight := 0.9
@export_range(0.0, 3.0) var sweetspire_weight := 1.3
@export_range(0.0, 3.0) var recruitment_weight := 1.0
@export_group("Combat")
@export_range(0.0, 1.0) var risk_tolerance := 0.35
@export_range(0.0, 1.0) var retreat_health_ratio := 0.3
@export_range(0.0, 3.0) var retaliation_weight := 1.0
@export_range(0.0, 3.0) var friendly_fire_penalty := 1.5
@export_group("Spending")
@export_range(0, 30) var reserve_sugar := 3
@export_range(1, 12) var investment_horizon := 4
@export_group("Imperfection")
@export_range(0.0, 1.0) var mistake_chance := 0.1
@export_range(1, 8) var alternative_count := 3
@export_range(0.0, 1.0) var max_score_loss := 0.15
@export_range(0, 12) var mistake_cooldown := 2
@export_group("Commitment")
@export_range(1, 10) var goal_commitment_turns := 3
@export_range(1, 8) var threat_response_threshold := 2
@export_group("Capabilities")
@export var allow_research := true
@export var allow_recruitment := true
@export var allow_construction := true
@export var allow_naval := true
@export var allow_area_attacks := true
@export_group("Presentation")
@export_range(0.0, 3.0) var action_delay := 0.35
@export_range(0.0, 3.0) var turn_intro_delay := 0.6
@export_group("Execution")
@export_range(1, 16) var work_per_frame := 2
@export_range(8, 256) var max_actions_per_turn := 96
@export_range(1, 16) var max_failed_retries := 4
@export var debug_decisions := false

func validated_copy() -> BotProfile:
	var result := duplicate() as BotProfile
	for property in get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE and int(property.hint) == PROPERTY_HINT_RANGE:
			var limits := str(property.hint_string).split(",")
			var value := clampf(float(get(property.name)), float(limits[0]), float(limits[1]))
			result.set(property.name, int(value) if int(property.type) == TYPE_INT else value)
	return result

func signature() -> String:
	var values: Array = []
	for property in get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			values.append([property.name, get(property.name)])
	return JSON.stringify(values).sha256_text()
