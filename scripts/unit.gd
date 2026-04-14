class_name CombatUnit
extends Node2D

var team_id: int = -1
var max_hp: float = 50.0
var hp: float = 50.0
var damage: float = 5.0
var move_speed: float = 100.0
var attack_range: float = 30.0
var attack_cooldown: float = 0.5
var unit_color: Color = Color.WHITE

var _attack_timer: float = 0.0
var _target: Node2D = null
var _last_attacker_team: int = -1

@onready var _poly: Polygon2D = $Polygon2D


func setup_from_stats(stats: Dictionary, p_team_id: int) -> void:
	team_id = p_team_id
	max_hp = float(stats["max_hp"])
	hp = max_hp
	damage = float(stats["damage"])
	move_speed = float(stats["speed"])
	attack_range = float(stats["attack_range"])
	attack_cooldown = float(stats["attack_cooldown"])
	unit_color = stats["color"] as Color
	if _poly:
		_poly.color = unit_color


func _ready() -> void:
	add_to_group("units")
	if _poly and unit_color != Color.WHITE:
		_poly.color = unit_color


func _process(delta: float) -> void:
	if hp <= 0.0:
		return
	var mgr := get_tree().get_first_node_in_group("match_manager")
	if mgr and mgr.has_method("is_match_over") and mgr.is_match_over():
		return
	_attack_timer -= delta
	_acquire_target()
	if _target == null or not is_instance_valid(_target):
		return
	var dist := global_position.distance_to(_target.global_position)
	if dist > attack_range:
		global_position += global_position.direction_to(_target.global_position) * move_speed * delta
	elif _attack_timer <= 0.0:
		_deal_damage_to(_target)
		_attack_timer = attack_cooldown


func _acquire_target() -> void:
	var best: Node2D = null
	var best_d := INF
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
	_target = best


func _deal_damage_to(target: Node2D) -> void:
	if target is Bunker:
		(target as Bunker).take_damage(damage, team_id)
	elif target is CombatUnit:
		(target as CombatUnit).take_damage(damage, team_id)


func take_damage(amount: float, attacker_team: int) -> void:
	if attacker_team == team_id:
		return
	_last_attacker_team = attacker_team
	hp -= amount
	if hp <= 0.0:
		_die()


func _die() -> void:
	if _last_attacker_team >= 0:
		var mgr := get_tree().get_first_node_in_group("match_manager")
		if mgr and mgr.has_method("register_kill"):
			mgr.register_kill(_last_attacker_team)
	queue_free()
