class_name SpawnerNode
extends Node2D

const COMBAT_UNIT := preload("res://scenes/units/combat_unit.tscn")

@export var spawn_interval: float = 2.15
@export var player_move_speed: float = 155.0
@export var ai_move_speed: float = 105.0

var _owner_base: PlayerBase

@onready var _timer: Timer = $Timer
@onready var _poly: Polygon2D = $Polygon2D


func _ready() -> void:
	add_to_group("spawners")
	_timer.wait_time = spawn_interval
	_timer.timeout.connect(_on_spawn_timer)
	_timer.one_shot = false


func setup(owner_base: PlayerBase) -> void:
	_owner_base = owner_base
	if _poly:
		_poly.color = Color(0.45, 0.95, 1.0) if _owner_base.team_id == 0 else Color(1.0, 0.42, 0.42)
	if not _timer.is_stopped():
		_timer.stop()
	_timer.start()


func _process(delta: float) -> void:
	if _owner_base == null:
		return
	var mgr := get_tree().get_first_node_in_group("match_manager")
	if mgr and mgr.has_method("is_match_over") and mgr.is_match_over():
		return
	if _owner_base.team_id == 0:
		var dir := Vector2.ZERO
		if Input.is_physical_key_pressed(KEY_A):
			dir.x -= 1.0
		if Input.is_physical_key_pressed(KEY_D):
			dir.x += 1.0
		if Input.is_physical_key_pressed(KEY_W):
			dir.y -= 1.0
		if Input.is_physical_key_pressed(KEY_S):
			dir.y += 1.0
		if dir.length_squared() > 0.0001:
			global_position += dir.normalized() * player_move_speed * delta
	else:
		var target := _owner_base.get_enemy_bunker_position()
		if target != Vector2.ZERO:
			global_position += global_position.direction_to(target) * ai_move_speed * delta

	global_position.x = clampf(global_position.x, 48.0, 1952.0)
	global_position.y = clampf(global_position.y, 48.0, 1152.0)


func _on_spawn_timer() -> void:
	if _owner_base == null:
		return
	var stats: Dictionary = EvolutionConfig.get_stats_for_kills(_owner_base.kills)
	var u: CombatUnit = COMBAT_UNIT.instantiate() as CombatUnit
	u.setup_from_stats(stats, _owner_base.team_id)
	u.global_position = global_position
	var arena := get_tree().get_first_node_in_group("arena_root")
	if arena and arena.has_node("Units"):
		arena.get_node("Units").add_child(u)


func stop_spawning() -> void:
	if _timer:
		_timer.stop()
