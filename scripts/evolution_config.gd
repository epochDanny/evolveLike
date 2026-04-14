extends Node

## Data-driven evolution tiers (original names; tune min_kills for pacing).
var _tiers: Array[Dictionary] = [
	{
		"min_kills": 0,
		"tier_name": "Mite",
		"max_hp": 38.0,
		"damage": 4.0,
		"speed": 112.0,
		"attack_range": 30.0,
		"attack_cooldown": 0.55,
		"color": Color(0.88, 0.48, 0.22),
	},
	{
		"min_kills": 8,
		"tier_name": "Striker",
		"max_hp": 78.0,
		"damage": 9.0,
		"speed": 128.0,
		"attack_range": 34.0,
		"attack_cooldown": 0.5,
		"color": Color(0.28, 0.78, 0.38),
	},
	{
		"min_kills": 25,
		"tier_name": "Breaker",
		"max_hp": 175.0,
		"damage": 19.0,
		"speed": 102.0,
		"attack_range": 40.0,
		"attack_cooldown": 0.44,
		"color": Color(0.38, 0.58, 0.98),
	},
	{
		"min_kills": 60,
		"tier_name": "Titan",
		"max_hp": 420.0,
		"damage": 42.0,
		"speed": 88.0,
		"attack_range": 48.0,
		"attack_cooldown": 0.38,
		"color": Color(0.92, 0.88, 0.28),
	},
]


func get_stats_for_kills(kills: int) -> Dictionary:
	var best: Dictionary = _tiers[0]
	for t in _tiers:
		if kills >= t["min_kills"]:
			best = t
	return best.duplicate()
