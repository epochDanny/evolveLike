class_name PlayerBase
extends Node2D

@export var team_id: int = 0
@export var team_name: String = "Team"
@export var slot_index: int = 0
@export var is_human_player: bool = false

var kills: int = 0
var player_color: Color = Color.WHITE
## Set when this player's fort is destroyed; spawner removed and no new units.
var is_eliminated: bool = false

@onready var bunker: Bunker = $Bunker
@onready var spawner: SpawnerNode = $Spawner


func _ready() -> void:
	add_to_group("player_bases")
	player_color = ProceduralTextures.player_color_for_slot(slot_index)
	if bunker:
		bunker.team_id = team_id
		bunker.team_name = team_name
		bunker.set_owner_base(self)
		bunker.apply_player_visual(player_color)
	if spawner and spawner.has_method("setup"):
		spawner.setup(self)


func add_kill() -> void:
	kills += 1


## Keeps a world point outside this player's fort footprint (label + sprite), centered on the bunker.
func clamp_world_position_clear_of_own_bunker(world_pos: Vector2, extra_margin: float) -> Vector2:
	if bunker == null or not is_instance_valid(bunker):
		return world_pos
	return bunker.push_world_position_outside_footprint(world_pos, extra_margin)


func eliminate_from_match() -> void:
	if is_eliminated:
		return
	is_eliminated = true
	if spawner != null and is_instance_valid(spawner):
		spawner.stop_spawning()
		spawner.queue_free()


func get_enemy_bunker_position() -> Vector2:
	var best: Vector2 = Vector2.ZERO
	var best_d := INF
	for b in get_tree().get_nodes_in_group("bunkers"):
		if not is_instance_valid(b) or not (b is Bunker):
			continue
		if GameSessionManager.instance.are_allied(team_id, (b as Bunker).team_id):
			continue
		var d := global_position.distance_to(b.global_position)
		if d < best_d:
			best_d = d
			best = b.global_position
	return best


func get_nearest_enemy_unit_position(from_global: Vector2) -> Vector2:
	var best: Vector2 = Vector2.ZERO
	var best_d := INF
	for u in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(u) or not (u is CombatUnit):
			continue
		var cu := u as CombatUnit
		if GameSessionManager.instance.are_allied(team_id, cu.team_id) or cu.hp <= 0.0:
			continue
		var d := from_global.distance_to(cu.global_position)
		if d < best_d:
			best_d = d
			best = cu.global_position
	return best if best_d < INF else Vector2.ZERO


## AI spawner: move toward enemy units early, then toward enemy forts when near Titan tier.
func get_ai_spawner_goal_for_spawner() -> Vector2:
	if EvolutionConfig.ai_should_consider_bunkers_for_targeting(kills):
		return get_enemy_bunker_position()
	var from_pos := (
		spawner.global_position
		if spawner != null and is_instance_valid(spawner)
		else global_position
	)
	var up := get_nearest_enemy_unit_position(from_pos)
	if up != Vector2.ZERO:
		return up
	return get_enemy_bunker_position()
