class_name Bunker
extends Node2D

signal destroyed_bunker(team_id: int)

@export var team_id: int = 0
@export var team_name: String = "Team"
@export var max_health: float = 8500.0

var health: float = 8500.0

@onready var _poly: Polygon2D = $Polygon2D
@onready var _label: Label = $Label


func _ready() -> void:
	add_to_group("bunkers")
	health = max_health
	_refresh_label()


func _refresh_label() -> void:
	if _label:
		_label.text = "%s\n%.0f / %.0f" % [team_name, health, max_health]


func take_damage(amount: float, attacker_team: int) -> void:
	if attacker_team == team_id:
		return
	health -= amount
	_refresh_label()
	if health <= 0.0:
		destroyed_bunker.emit(team_id)
		queue_free()
