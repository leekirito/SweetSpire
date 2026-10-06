class_name BotProfile
extends Resource

## Editable priorities, capabilities, pacing, and bounded imperfect choices.
## Controllers use validated copies rather than mutating the shared resource.

## Decision tuning. No bonuses, hidden knowledge, or forced outcomes.
@export_group("Identity")
## Stable key used by rosters and BotCatalog to select this profile.
@export var profile_id := "balanced"
## Player-facing label shown when choosing a bot profile.
@export var display_name := "Balanced"
## Revision included in the profile signature; increase when revising this preset.
@export var profile_version := 1
@export_group("Planning")
## Number of future threat steps considered in movement scoring.
@export_range(1, 4) var lookahead_depth := 2
## Maximum scored movement options retained per unit.
@export_range(8, 256) var candidate_limit := 64
## Soft assignment limit; excess units prefer another strategic destination.
@export_range(1, 8) var coordination_limit := 2
@export_group("Priorities")
## Relative priority of resource collection, upgrades, and income investments.
@export_range(0.0, 3.0) var economy_weight := 1.0
## Relative priority of moving toward capturable towns.
@export_range(0.0, 3.0) var expansion_weight := 1.0
## Relative priority of defending threatened territory.
@export_range(0.0, 3.0) var defense_weight := 1.2
## Relative priority of purchasing useful research and prerequisites.
@export_range(0.0, 3.0) var research_weight := 0.9
## Relative priority of reaching and holding the center objective.
@export_range(0.0, 3.0) var sweetspire_weight := 1.3
## Relative priority of spending Sugar on additional units.
@export_range(0.0, 3.0) var recruitment_weight := 1.0
@export_group("Combat")
## Higher values reduce movement penalties for exposure to visible enemies.
@export_range(0.0, 1.0) var risk_tolerance := 0.35
## Health fraction below which a unit favors safer positions.
@export_range(0.0, 1.0) var retreat_health_ratio := 0.3
## Weight of estimated enemy threat; this does not add a counterattack rule.
@export_range(0.0, 3.0) var retaliation_weight := 1.0
## Penalty for harming friendly units with area attacks.
@export_range(0.0, 3.0) var friendly_fire_penalty := 1.5
@export_group("Spending")
## Preferred savings for nonurgent recruitment/construction. Urgent actions and research may spend it.
@export_range(0, 30) var reserve_sugar := 3
## Number of future income rounds considered when valuing an improvement.
@export_range(1, 12) var investment_horizon := 4
@export_group("Imperfection")
## Chance to choose a slightly weaker candidate when the mistake cooldown permits.
@export_range(0.0, 1.0) var mistake_chance := 0.1
## Maximum number of top-ranked candidates considered for an imperfect choice.
@export_range(1, 8) var alternative_count := 3
## Largest allowed drop from the best normalized score when making a mistake.
@export_range(0.0, 1.0) var max_score_loss := 0.15
## Number of subsequent decisions protected from another deliberate mistake.
@export_range(0, 12) var mistake_cooldown := 2
@export_group("Commitment")
## How many rounds a unit can retain its strategic destination.
@export_range(1, 10) var goal_commitment_turns := 3
## Visible threat level that can break a unit's current goal commitment.
@export_range(1, 8) var threat_response_threshold := 2
@export_group("Capabilities")
## Allow this profile to propose research purchases.
@export var allow_research := true
## Allow this profile to propose new units.
@export var allow_recruitment := true
## Allow this profile to propose structures.
@export var allow_construction := true
## Allow planning movement that embarks units and crosses water.
@export var allow_naval := true
## Allow tile-targeted area attacks in candidate generation.
@export var allow_area_attacks := true
@export_group("Presentation")
## Seconds between bot decisions, keeping its actions readable.
@export_range(0.0, 3.0) var action_delay := 0.35
## Seconds to wait at the start of the bot's turn.
@export_range(0.0, 3.0) var turn_intro_delay := 0.6
@export_group("Execution")
## Maximum own units scored per planning frame. Individual route searches remain synchronous.
@export_range(1, 16) var work_per_frame := 2
## Safety cap on execution attempts before ending the turn.
@export_range(8, 256) var max_actions_per_turn := 96
## Rejected-command limit for the turn; prevents repeatedly attempting invalid actions.
@export_range(1, 16) var max_failed_retries := 4
## Print chosen commands, scores, reasons, and deliberate mistakes for tuning.
@export var debug_decisions := false

## Duplicates the resource and clamps numeric exports to their Inspector ranges.
func validated_copy() -> BotProfile:
	var result := duplicate() as BotProfile
	for property in get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE and int(property.hint) == PROPERTY_HINT_RANGE:
			var limits := str(property.hint_string).split(",")
			var value := clampf(float(get(property.name)), float(limits[0]), float(limits[1]))
			result.set(property.name, int(value) if int(property.type) == TYPE_INT else value)
	return result

## Hashes script-defined tuning values without mutating the profile.
func signature() -> String:
	var values: Array = []
	for property in get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			values.append([property.name, get(property.name)])
	return JSON.stringify(values).sha256_text()
