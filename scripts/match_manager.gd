extends Node2D

const PLAYER_BASE_SCENE := preload("res://scenes/player_base.tscn")

@onready var units_root: Node2D = $Units
@onready var bases_root: Node2D = $Bases
@onready var diamond_obstacle: Polygon2D = $DiamondObstacle
@onready var camera: Camera2D = $Camera2D
@onready var hud: Label = $CanvasLayer/HUD

var _game_over: bool = false
var _bases: Array[PlayerBase] = []
var _human_player: PlayerBase = null


func is_match_over() -> bool:
	return _game_over


func _ready() -> void:
	add_to_group("match_manager")
	if diamond_obstacle:
		diamond_obstacle.visible = (
			GameSessionManager.instance.mode == GameSessionManager.Mode.TEAMS
		)
	_spawn_bases_from_session()
	_refresh_hud()


func _spawn_bases_from_session() -> void:
	var layout: Array[Dictionary] = GameSessionManager.instance.get_base_layout()
	for cfg in layout:
		var pb: PlayerBase = PLAYER_BASE_SCENE.instantiate() as PlayerBase
		pb.slot_index = cfg["slot"] as int
		pb.team_id = cfg["team_id"] as int
		pb.team_name = cfg["team_name"] as String
		pb.is_human_player = cfg["is_human"] as bool
		pb.position = cfg["position"] as Vector2
		bases_root.add_child(pb)
		_bases.append(pb)
		if pb.is_human_player:
			_human_player = pb
	if _human_player == null and _bases.size() > 0:
		_human_player = _bases[0]
	for pb in _bases:
		if pb.bunker:
			pb.bunker.destroyed_bunker.connect(_on_bunker_destroyed.bind(pb))
			pb.bunker.health_changed.connect(_on_fort_health_changed)


func _on_fort_health_changed(_current: float, _maximum: float) -> void:
	if _game_over:
		return
	_refresh_hud()


func _process(_delta: float) -> void:
	if _game_over:
		return
	if camera and _human_player and is_instance_valid(_human_player) and _human_player.spawner:
		camera.global_position = _human_player.spawner.global_position


func register_kill(killer: PlayerBase) -> void:
	if _game_over:
		return
	if killer == null or not is_instance_valid(killer):
		return
	killer.add_kill()
	_refresh_hud()


func _fort_line(pb: PlayerBase) -> String:
	if pb == null:
		return ""
	if not is_instance_valid(pb.bunker):
		return "%s — fort destroyed" % pb.team_name
	var b: Bunker = pb.bunker
	var hp_pct: int = int(round(100.0 * b.health / b.max_health))
	var hint: String = EvolutionConfig.get_next_evolution_hint(pb.kills)
	return (
		"%s — fort %d%% | kills: %d | %s | next: %s"
		% [pb.team_name, hp_pct, pb.kills, EvolutionConfig.get_stats_for_kills(pb.kills).get("tier_name", "?"), hint]
	)


func _refresh_hud() -> void:
	if hud == null:
		return
	var lines: Array[String] = []
	for pb in _bases:
		if is_instance_valid(pb):
			lines.append(_fort_line(pb))
	var mode_hint := (
		"Teams"
		if GameSessionManager.instance.mode == GameSessionManager.Mode.TEAMS
		else "FFA"
	)
	var body_lines := ""
	for i in range(lines.size()):
		if i > 0:
			body_lines += "\n"
		body_lines += lines[i]
	hud.text = (
		"[%s]\n" % mode_hint
		+ body_lines
		+ "\n\nWASD — move your spawner  |  P / Esc — pause  |  Restart — new match  |  Main menu  |  R — when paused / after win"
	)


func _remaining_team_ids_with_bunkers() -> Dictionary:
	var seen: Dictionary = {}
	for b in get_tree().get_nodes_in_group("bunkers"):
		if b is Bunker and is_instance_valid(b):
			seen[b.team_id] = true
	return seen


func _on_bunker_destroyed(owner_pb: PlayerBase, _losing_fort_team: int) -> void:
	if _game_over:
		return
	if owner_pb != null and is_instance_valid(owner_pb) and owner_pb.is_human_player:
		_finish_human_defeat()
		return
	var remaining: Dictionary = _remaining_team_ids_with_bunkers()
	if remaining.size() <= 1:
		var winner_tid: int = -1
		if remaining.size() == 1:
			for k in remaining:
				winner_tid = int(k)
				break
		_finish_match(winner_tid)
	else:
		_refresh_hud()


func _finish_human_defeat() -> void:
	_game_over = true
	for s in get_tree().get_nodes_in_group("spawners"):
		if s is SpawnerNode:
			(s as SpawnerNode).stop_spawning()
	if hud:
		hud.text = "Game Over\nYour fort was destroyed.\n\nR or Restart — play again"


func _finish_match(winner_team_id: int) -> void:
	_game_over = true
	for s in get_tree().get_nodes_in_group("spawners"):
		if s is SpawnerNode:
			(s as SpawnerNode).stop_spawning()
	if hud:
		var headline := "Victory!"
		if (
			_human_player != null
			and is_instance_valid(_human_player)
			and is_instance_valid(_human_player.bunker)
			and winner_team_id == _human_player.team_id
		):
			headline = "Victory!\nAll enemy forts destroyed."
		hud.text = headline + "\n\n" + _winner_text(winner_team_id) + "\n\nR or Restart — play again"


func _winner_text(winner_team_id: int) -> String:
	if winner_team_id < 0:
		return "Draw?"
	if GameSessionManager.instance.mode == GameSessionManager.Mode.TEAMS:
		var letter := "A" if winner_team_id == 0 else "B"
		return "Team %s wins!" % letter
	for pb in _bases:
		if pb.team_id == winner_team_id and is_instance_valid(pb):
			return "%s wins!" % pb.team_name
	return "Victory!"
