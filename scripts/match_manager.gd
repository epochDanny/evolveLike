extends Node2D

@onready var units_root: Node2D = $Units
@onready var player_base: PlayerBase = $PlayerBase0
@onready var enemy_base: PlayerBase = $PlayerBase1
@onready var camera: Camera2D = $Camera2D
@onready var hud: Label = $CanvasLayer/HUD

var _game_over: bool = false


func is_match_over() -> bool:
	return _game_over


func _ready() -> void:
	add_to_group("match_manager")
	if player_base and player_base.bunker:
		player_base.bunker.destroyed_bunker.connect(_on_bunker_destroyed)
	if enemy_base and enemy_base.bunker:
		enemy_base.bunker.destroyed_bunker.connect(_on_bunker_destroyed)
	_refresh_hud()


func _process(_delta: float) -> void:
	if _game_over:
		return
	if camera and player_base and player_base.spawner:
		camera.global_position = player_base.spawner.global_position


func register_kill(killer_team: int) -> void:
	if _game_over:
		return
	for pb in get_tree().get_nodes_in_group("player_bases"):
		if pb is PlayerBase and pb.team_id == killer_team:
			(pb as PlayerBase).add_kill()
	_refresh_hud()


func _refresh_hud() -> void:
	if hud == null or player_base == null or enemy_base == null:
		return
	var ps: Dictionary = EvolutionConfig.get_stats_for_kills(player_base.kills)
	var es: Dictionary = EvolutionConfig.get_stats_for_kills(enemy_base.kills)
	hud.text = (
		"You (%s) — kills: %d | evolution: %s\n"
		+ "Enemy (%s) — kills: %d | evolution: %s\n"
		+ "Destroy the enemy fort. WASD moves your spawner craft."
	) % [
		player_base.team_name,
		player_base.kills,
		ps.get("tier_name", "?"),
		enemy_base.team_name,
		enemy_base.kills,
		es.get("tier_name", "?"),
	]


func _on_bunker_destroyed(losing_team: int) -> void:
	if _game_over:
		return
	_game_over = true
	for s in get_tree().get_nodes_in_group("spawners"):
		if s is SpawnerNode:
			(s as SpawnerNode).stop_spawning()
	var winner := "Unknown"
	for pb in get_tree().get_nodes_in_group("player_bases"):
		if pb is PlayerBase and (pb as PlayerBase).team_id != losing_team:
			winner = (pb as PlayerBase).team_name
			break
	if hud:
		hud.text = "%s wins!\nPress F5 or restart the scene to play again." % winner
