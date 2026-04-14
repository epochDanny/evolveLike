class_name CombatUnit
extends CharacterBody2D

var team_id: int = -1
var max_hp: float = 50.0
var hp: float = 50.0
var damage: float = 5.0
var move_speed: float = 100.0
var attack_range: float = 30.0
var attack_cooldown: float = 0.5
## Owner identity color (bunker/spawner); tier digit uses this color.
var player_accent: Color = Color.WHITE
var tier_display: int = 1

var _attack_timer: float = 0.0
var _target: Node2D = null
var _last_killer: PlayerBase = null
## Spawner's fort; used so AI prioritizes enemy units until late evolution.
var _owner_player: PlayerBase = null

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _tier_label: Label = $TierLabel
@onready var _nav: NavigationAgent2D = $NavigationAgent2D


func set_owner_player(owner: PlayerBase) -> void:
	_owner_player = owner


func setup_from_stats(
	stats: Dictionary, p_team_id: int, p_player_accent: Color, tier_index_1_based: int
) -> void:
	team_id = p_team_id
	player_accent = p_player_accent
	tier_display = tier_index_1_based
	max_hp = float(stats["max_hp"])
	hp = max_hp
	damage = float(stats["damage"])
	move_speed = float(stats["speed"])
	attack_range = float(stats["attack_range"])
	attack_cooldown = float(stats["attack_cooldown"])


func _ready() -> void:
	add_to_group("units")
	motion_mode = MOTION_MODE_FLOATING
	# Layer 2: bump other units (same layer/mask) so armies don't occupy the same spot.
	collision_layer = 2
	collision_mask = 2
	_nav.avoidance_enabled = true
	_nav.radius = 22.0
	_nav.neighbor_distance = 64.0
	_nav.path_desired_distance = 10.0
	_nav.target_desired_distance = 6.0
	_nav.max_speed = maxf(move_speed, 1.0)
	GameSessionManager.instance.configure_unit_avoidance(_nav, team_id)
	_nav.velocity_computed.connect(_on_velocity_computed)
	_apply_unit_visual()


func _apply_unit_visual() -> void:
	if _tier_label:
		_tier_label.add_theme_font_override("font", ProceduralTextures.default_ui_font())
		_tier_label.text = str(tier_display)
		_tier_label.add_theme_color_override("font_color", player_accent)


func _physics_process(delta: float) -> void:
	if hp <= 0.0:
		return
	var mgr := get_tree().get_first_node_in_group("match_manager")
	if mgr and mgr.has_method("is_match_over") and mgr.is_match_over():
		_nav.set_velocity(Vector2.ZERO)
		return
	_attack_timer -= delta
	_acquire_target()
	_nav.max_speed = maxf(move_speed, 1.0)
	if _target == null or not is_instance_valid(_target):
		_nav.set_velocity(Vector2.ZERO)
		return
	var dist := global_position.distance_to(_target.global_position)
	if dist <= attack_range + 4.0:
		_nav.target_position = _target.global_position
		_nav.set_velocity(Vector2.ZERO)
		if _attack_timer <= 0.0:
			_deal_damage_to(_target)
			_attack_timer = attack_cooldown
		return
	_nav.target_position = _target.global_position
	var next_pos := _nav.get_next_path_position()
	var to_next := global_position.direction_to(next_pos)
	if to_next.length_squared() < 0.0001:
		_nav.set_velocity(Vector2.ZERO)
	else:
		_nav.set_velocity(to_next * move_speed)


func _on_velocity_computed(safe_velocity: Vector2) -> void:
	velocity = safe_velocity
	move_and_slide()


func _acquire_target() -> void:
	var ai_early_focus_units: bool = (
		_owner_player != null
		and not _owner_player.is_human_player
		and not EvolutionConfig.ai_should_consider_bunkers_for_targeting(_owner_player.kills)
	)

	var best: Node2D = null
	var best_d := INF

	if not ai_early_focus_units:
		for b in get_tree().get_nodes_in_group("bunkers"):
			if not is_instance_valid(b):
				continue
			if b is Bunker and (b as Bunker).team_id == team_id:
				continue
			var d := global_position.distance_to(b.global_position)
			if d < best_d:
				best_d = d
				best = b as Node2D

	for u in get_tree().get_nodes_in_group("units"):
		if u == self or not is_instance_valid(u):
			continue
		var cu := u as CombatUnit
		if cu.team_id == team_id or cu.hp <= 0.0:
			continue
		var d2 := global_position.distance_to(cu.global_position)
		if d2 < best_d:
			best_d = d2
			best = cu

	if ai_early_focus_units and best == null:
		for b in get_tree().get_nodes_in_group("bunkers"):
			if not is_instance_valid(b):
				continue
			if b is Bunker and (b as Bunker).team_id == team_id:
				continue
			var d := global_position.distance_to(b.global_position)
			if d < best_d:
				best_d = d
				best = b as Node2D

	_target = best


func _deal_damage_to(target: Node2D) -> void:
	var killer: PlayerBase = _owner_player
	if target is Bunker:
		(target as Bunker).take_damage(damage, team_id, killer)
	elif target is CombatUnit:
		(target as CombatUnit).take_damage(damage, team_id, killer)


func take_damage(amount: float, attacker_team: int, killer: PlayerBase = null) -> void:
	if attacker_team == team_id:
		return
	_last_killer = killer
	hp -= amount
	if hp <= 0.0:
		_die()


func _die() -> void:
	if _last_killer != null and is_instance_valid(_last_killer):
		var mgr := get_tree().get_first_node_in_group("match_manager")
		if mgr and mgr.has_method("register_kill"):
			mgr.register_kill(_last_killer)
	queue_free()
