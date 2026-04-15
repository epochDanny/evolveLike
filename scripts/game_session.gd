extends Node
class_name GameSessionManager

## Holds match setup between main menu and arena. Not saved to disk.
## Use GameSessionManager.instance from scripts (autoload global "GameSession" is not always visible to the compiler).

static var instance: GameSessionManager

enum Mode { TEAMS, FFA }

var mode: Mode = Mode.TEAMS
## For Teams: 1 = 1v1, 2 = 2v2, 3 = 3v3 (players per side).
var teams_match_size: int = 3
## For FFA: total players (2–6).
var ffa_player_count: int = 6
## Which fort slot the human controls (0 .. player_count-1).
var human_slot: int = 0


func _ready() -> void:
	instance = self


func get_total_players() -> int:
	if mode == Mode.TEAMS:
		return teams_match_size * 2
	return ffa_player_count


func get_base_layout() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var n: int = get_total_players()
	var center := Vector2(1000, 600)
	var radius := 480.0
	if mode == Mode.TEAMS:
		var half: int = teams_match_size
		for slot in range(n):
			var team: int = 0 if slot < half else 1
			var local := (slot + 1) if team == 0 else (slot - half + 1)
			var team_label := "Team A%d" % local if team == 0 else "Team B%d" % local
			out.append(
				{
					"slot": slot,
					"team_id": team,
					"team_name": team_label,
					"position": _slot_position_teams(slot, teams_match_size),
					"is_human": slot == human_slot,
				}
			)
	else:
		for slot in range(n):
			out.append(
				{
					"slot": slot,
					"team_id": slot,
					"team_name": "Player %d" % (slot + 1),
					"position": _slot_position(slot, n, center, radius),
					"is_human": slot == human_slot,
				}
			)
	return out


## Team A row on top, Team B row on bottom (A1 A2 A3 / B1 B2 B3).
func _slot_position_teams(slot: int, per_side: int) -> Vector2:
	var top_y := 220.0
	var bot_y := 980.0
	if per_side == 1:
		return Vector2(1000, top_y) if slot == 0 else Vector2(1000, bot_y)
	var xs: Array[float]
	if per_side == 2:
		xs = [650.0, 1350.0]
	else:
		xs = [400.0, 1000.0, 1600.0]
	if slot < per_side:
		return Vector2(xs[slot], top_y)
	return Vector2(xs[slot - per_side], bot_y)


func _slot_position(slot: int, total: int, center: Vector2, r: float) -> Vector2:
	var angle := -PI / 2.0 + TAU * float(slot) / float(total)
	return center + Vector2(cos(angle), sin(angle)) * r


func are_allied(team_a: int, team_b: int) -> bool:
	return team_a == team_b


func configure_unit_avoidance(agent: NavigationAgent2D, team_id: int) -> void:
	# Layers = which team this agent occupies; mask = avoid all teams so allies don't stack.
	if mode == Mode.TEAMS:
		agent.avoidance_layers = 1 << team_id
		agent.avoidance_mask = (1 << 0) | (1 << 1)
	else:
		var n: int = get_total_players()
		agent.avoidance_layers = 1 << team_id
		var mask := 0
		for i in range(n):
			mask |= 1 << i
		agent.avoidance_mask = mask
