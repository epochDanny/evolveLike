extends Node2D

const PLAYER_BASE_SCENE := preload("res://scenes/player_base.tscn")

@onready var units_root: Node2D = $Units
@onready var bases_root: Node2D = $Bases
@onready var diamond_obstacle: Polygon2D = $DiamondObstacle
@onready var camera: Camera2D = $Camera2D
@onready var hud: Label = $CanvasLayer/HUD
@onready var _match_ui: MatchUI = $MatchLayer/MatchUI

var _game_over: bool = false
## Human eliminated but match continues (FFA or Teams).
var _ffa_spectating: bool = false
var _bases: Array[PlayerBase] = []
var _human_player: PlayerBase = null


func is_match_over() -> bool:
	return _game_over


func get_human_player() -> PlayerBase:
	return _human_player


func is_human_spectating() -> bool:
	if _game_over:
		return false
	if _human_player == null or not is_instance_valid(_human_player):
		return false
	if not _human_player.is_eliminated:
		return false
	if GameSessionManager.instance.mode == GameSessionManager.Mode.FFA:
		return _ffa_spectating
	return true


func _ready() -> void:
	add_to_group("match_manager")
	if diamond_obstacle:
		diamond_obstacle.visible = (
			GameSessionManager.instance.mode == GameSessionManager.Mode.TEAMS
		)
	if _match_ui:
		_match_ui.main_menu_pressed.connect(_on_match_ui_main_menu)
		_match_ui.ffa_watch_pressed.connect(_on_ffa_watch_continue)
	_spawn_bases_from_session()
	_refresh_hud()
	MusicRouter.play_match_music()


func _on_match_ui_main_menu() -> void:
	MusicRouter.stop_match_music(0.4)
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_ffa_watch_continue() -> void:
	_ffa_spectating = true
	get_tree().paused = false
	if _match_ui:
		_match_ui.set_spectator_bar_visible(true)


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
	if camera == null:
		return
	if _human_player != null and is_instance_valid(_human_player):
		if _human_player.is_eliminated:
			camera.global_position = _get_spectator_camera_position()
			return
		if is_instance_valid(_human_player.spawner):
			camera.global_position = _human_player.spawner.global_position
			return
	camera.global_position = _get_spectator_camera_position()


func _get_spectator_camera_position() -> Vector2:
	var mode := GameSessionManager.instance.mode
	var acc := Vector2.ZERO
	var n: int = 0
	for pb in _bases:
		if not is_instance_valid(pb) or pb.is_eliminated:
			continue
		if not is_instance_valid(pb.spawner):
			continue
		if mode == GameSessionManager.Mode.TEAMS and _human_player != null:
			if pb.team_id != _human_player.team_id:
				continue
		acc += pb.spawner.global_position
		n += 1
	if n > 0:
		return acc / float(n)
	return Vector2(1000, 600)


func register_kill(killer: PlayerBase) -> void:
	if _game_over:
		return
	if killer == null or not is_instance_valid(killer):
		return
	if killer.is_eliminated:
		return
	killer.add_kill()
	_refresh_hud()


func _remove_units_owned_by(owner_pb: PlayerBase) -> void:
	for u in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(u) or not (u is CombatUnit):
			continue
		var cu := u as CombatUnit
		if cu.get_owner_player() == owner_pb:
			cu.queue_free()


func _fort_line(pb: PlayerBase) -> String:
	if pb == null:
		return ""
	if not is_instance_valid(pb.bunker):
		return "%s — fort destroyed" % pb.team_name
	var b: Bunker = pb.bunker
	var hp_pct: int = int(round(100.0 * b.health / b.max_health))
	var hint: String = EvolutionConfig.get_next_evolution_hint(pb.kills)
	return (
		"%s — fort %d%% | kills: %d | %s | %s"
		% [
			pb.team_name,
			hp_pct,
			pb.kills,
			EvolutionConfig.get_stats_for_kills(pb.kills).get("tier_name", "?"),
			hint,
		]
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
	var spec_hint := ""
	if is_human_spectating() and GameSessionManager.instance.mode == GameSessionManager.Mode.TEAMS:
		spec_hint = "\n\n(Spectating your team — use Main menu to leave.)"
	hud.text = (
		"[%s]\n" % mode_hint
		+ body_lines
		+ spec_hint
		+ "\n\nWASD — move your spawner  |  Click / drag-box — select your units  |  Shift — add to selection  |  Right-click — move or attack  |  P / Esc — pause  |  Restart / Main menu  |  R — when paused / after win"
	)


func _remaining_team_ids_with_bunkers() -> Dictionary:
	var seen: Dictionary = {}
	for b in get_tree().get_nodes_in_group("bunkers"):
		if not is_instance_valid(b) or not (b is Bunker):
			continue
		if (b as Bunker).health <= 0.0:
			continue
		seen[(b as Bunker).team_id] = true
	return seen


## Signal emits (team_id) first; .bind(owner_pb) appends the base. Order is (losing_team, owner_pb).
func _on_bunker_destroyed(_losing_team: int, owner_pb: PlayerBase) -> void:
	if _game_over:
		return
	_remove_units_owned_by(owner_pb)
	owner_pb.eliminate_from_match()

	var remaining: Dictionary = _remaining_team_ids_with_bunkers()
	if remaining.size() <= 1:
		var winner_tid: int = -1
		if remaining.size() == 1:
			for k in remaining:
				winner_tid = int(k)
				break
		_finish_match_full(winner_tid)
		return

	if owner_pb.is_human_player:
		if GameSessionManager.instance.mode == GameSessionManager.Mode.FFA:
			get_tree().paused = true
			if _match_ui:
				_match_ui.show_ffa_eliminated()
		else:
			if _match_ui:
				_match_ui.set_spectator_bar_visible(false)
	_refresh_hud()


func _finish_match_full(winner_team_id: int) -> void:
	_game_over = true
	_ffa_spectating = false
	MusicRouter.stop_match_music(2.0)
	if _match_ui:
		_match_ui.hide_all()
		_match_ui.set_spectator_bar_visible(false)

	for s in get_tree().get_nodes_in_group("spawners"):
		if s is SpawnerNode:
			(s as SpawnerNode).stop_spawning()

	get_tree().paused = true

	var gs_mode := GameSessionManager.instance.mode
	if gs_mode == GameSessionManager.Mode.TEAMS:
		var human_won: bool = (
			_human_player != null
			and is_instance_valid(_human_player)
			and winner_team_id == _human_player.team_id
		)
		if _match_ui:
			_match_ui.show_teams_match_end(human_won, winner_team_id)
	elif _match_ui:
		_match_ui.show_ffa_match_over(_winner_line_ffa(winner_team_id))


func _winner_line_ffa(winner_team_id: int) -> String:
	for pb in _bases:
		if pb.team_id == winner_team_id and is_instance_valid(pb):
			return "%s wins!" % pb.team_name
	return "Victory!"
