class_name SpawnerNode
extends Node2D

const COMBAT_UNIT := preload("res://scenes/units/combat_unit.tscn")

@export var spawn_interval: float = 2.15
@export var player_move_speed: float = 155.0
@export var ai_move_speed: float = 105.0

var _owner_base: PlayerBase

@onready var _timer: Timer = $Timer
@onready var _sprite: Sprite2D = $Sprite2D
@onready var _team_letter: Label = $TeamLetter


func _ready() -> void:
	add_to_group("spawners")
	_timer.wait_time = spawn_interval
	_timer.timeout.connect(_on_spawn_timer)
	_timer.one_shot = false


func setup(owner_base: PlayerBase) -> void:
	_owner_base = owner_base
	if _sprite:
		_sprite.texture = ProceduralTextures.create_spawner_texture(_owner_base.player_color)
	if _team_letter:
		_team_letter.add_theme_font_override("font", ProceduralTextures.default_ui_font())
		if GameSessionManager.instance.mode == GameSessionManager.Mode.TEAMS:
			_team_letter.text = "A" if _owner_base.team_id == 0 else "B"
			_team_letter.add_theme_color_override("font_color", Color(0.98, 0.98, 1.0))
			_team_letter.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08))
			_team_letter.add_theme_constant_override("outline_size", 6)
			_team_letter.visible = true
		else:
			_team_letter.visible = false
	if not _timer.is_stopped():
		_timer.stop()
	_timer.start()


func _process(delta: float) -> void:
	if _owner_base == null:
		return
	var mgr := get_tree().get_first_node_in_group("match_manager")
	if mgr and mgr.has_method("is_match_over") and mgr.is_match_over():
		return
	if _owner_base.is_human_player:
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
		var target := _owner_base.get_ai_spawner_goal_for_spawner()
		if target != Vector2.ZERO:
			global_position += global_position.direction_to(target) * ai_move_speed * delta

	global_position.x = clampf(global_position.x, 48.0, 1952.0)
	global_position.y = clampf(global_position.y, 48.0, 1152.0)


func _on_spawn_timer() -> void:
	if _owner_base == null:
		return
	var stats: Dictionary = EvolutionConfig.get_stats_for_kills(_owner_base.kills)
	var tier_n: int = EvolutionConfig.get_tier_index_1_based(_owner_base.kills)
	var u: CombatUnit = COMBAT_UNIT.instantiate() as CombatUnit
	u.setup_from_stats(stats, _owner_base.team_id, _owner_base.player_color, tier_n)
	u.set_owner_player(_owner_base)
	u.global_position = global_position + Vector2(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0))
	var arena := get_tree().get_first_node_in_group("arena_root")
	if arena and arena.has_node("Units"):
		arena.get_node("Units").add_child(u)


func stop_spawning() -> void:
	if _timer:
		_timer.stop()
