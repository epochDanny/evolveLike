extends Node

## Data-driven evolution tiers (original names; tune min_kills for pacing).
var _tiers: Array[Dictionary] = [
	{
		"min_kills": 0,
		"tier_name": "Mite",
		"max_hp": 38.0,
		"damage": 4.0,
		"speed": 112.0,
		"attack_range": 44.0,
		"attack_cooldown": 0.55,
		"color": Color(0.88, 0.48, 0.22),
	},
	{
		"min_kills": 8,
		"tier_name": "Striker",
		"max_hp": 78.0,
		"damage": 9.0,
		"speed": 128.0,
		"attack_range": 48.0,
		"attack_cooldown": 0.5,
		"color": Color(0.28, 0.78, 0.38),
	},
	{
		"min_kills": 25,
		"tier_name": "Breaker",
		"max_hp": 175.0,
		"damage": 19.0,
		"speed": 102.0,
		"attack_range": 54.0,
		"attack_cooldown": 0.44,
		"color": Color(0.38, 0.58, 0.98),
	},
	{
		"min_kills": 60,
		"tier_name": "Titan",
		"max_hp": 420.0,
		"damage": 42.0,
		"speed": 88.0,
		"attack_range": 62.0,
		"attack_cooldown": 0.38,
		"color": Color(0.92, 0.88, 0.28),
	},
]


const TITAN_MIN_KILLS: int = 60


## AI prioritizes killing enemy units until kills are near Titan; then bunkers are weighted equally.
func ai_should_consider_bunkers_for_targeting(owner_kills: int) -> bool:
	if owner_kills >= TITAN_MIN_KILLS:
		return true
	return owner_kills >= TITAN_MIN_KILLS - 10


func get_stats_for_kills(kills: int) -> Dictionary:
	var best: Dictionary = _tiers[0]
	for t in _tiers:
		if kills >= t["min_kills"]:
			best = t
	return best.duplicate()


## Display tier as 1..N (e.g. green "1" = Mite for that player color).
func get_tier_index_1_based(kills: int) -> int:
	var best_i: int = 0
	for i in range(_tiers.size()):
		if kills >= _tiers[i]["min_kills"]:
			best_i = i
	return best_i + 1


func get_next_evolution_hint(kills: int) -> String:
	var best_i: int = 0
	for i in range(_tiers.size()):
		if kills >= _tiers[i]["min_kills"]:
			best_i = i
	if best_i >= _tiers.size() - 1:
		return "Max tier"
	var next_t: Dictionary = _tiers[best_i + 1]
	var next_at: int = int(next_t["min_kills"])
	var need: int = max(0, next_at - kills) as int
	return "%d more kill%s → %s (at %d)" % [need, "s" if need != 1 else "", next_t["tier_name"], next_at]
