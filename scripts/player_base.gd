class_name PlayerBase
extends Node2D

@export var team_id: int = 0
@export var team_name: String = "Team"

var kills: int = 0

@onready var bunker: Bunker = $Bunker
@onready var spawner: SpawnerNode = $Spawner


func _ready() -> void:
	add_to_group("player_bases")
	if bunker:
		bunker.team_id = team_id
		bunker.team_name = team_name
	if spawner and spawner.has_method("setup"):
		spawner.setup(self)


func add_kill() -> void:
	kills += 1


func get_enemy_bunker_position() -> Vector2:
	for b in get_tree().get_nodes_in_group("bunkers"):
		if b is Bunker and b.team_id != team_id and is_instance_valid(b):
			return b.global_position
	return Vector2.ZERO
