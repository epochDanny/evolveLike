class_name Bunker
extends Node2D

## Matches fort art: sprite 176×120 centered on this node; label sits above the sprite (see bunker.tscn).
const FOOTPRINT_HALF_WIDTH: float = 88.0
## Local space: label reaches about y = -100, sprite bottom about y = +60 from bunker origin.
const FOOTPRINT_EXTENT_ABOVE_CENTER: float = 100.0
const FOOTPRINT_EXTENT_BELOW_CENTER: float = 60.0

signal destroyed_bunker(team_id: int)
signal health_changed(current: float, maximum: float)


## Push a world point outside this bunker's label+sprite footprint (used for spawn placement vs all forts).
func push_world_position_outside_footprint(world_pos: Vector2, extra_margin: float) -> Vector2:
	var half_w: float = FOOTPRINT_HALF_WIDTH + extra_margin
	var y_top: float = FOOTPRINT_EXTENT_ABOVE_CENTER + extra_margin
	var y_bot: float = FOOTPRINT_EXTENT_BELOW_CENTER + extra_margin
	var local: Vector2 = world_pos - global_position
	local = push_local_outside_footprint(local, half_w, y_top, y_bot)
	return global_position + local


## If `local` lies inside the footprint box, scale along the ray from the bunker origin to the box edge.
static func push_local_outside_footprint(
	local: Vector2, half_w: float, y_top: float, y_bot: float
) -> Vector2:
	if absf(local.x) > half_w or local.y < -y_top or local.y > y_bot:
		return local
	var t: float = INF
	if absf(local.x) > 0.0001:
		t = minf(t, half_w / absf(local.x))
	if absf(local.y) > 0.0001:
		if local.y < 0.0:
			t = minf(t, y_top / absf(local.y))
		elif local.y > 0.0:
			t = minf(t, y_bot / absf(local.y))
	if t >= INF - 1.0:
		return Vector2(half_w * 1.001, 0.0)
	return local * t * 1.001


## Closest point on the fort footprint AABB (matches StaticBody2D rect) for range / navigation.
func closest_point_on_footprint_world(world_pos: Vector2) -> Vector2:
	var l: Vector2 = world_pos - global_position
	var cx: float = clampf(l.x, -FOOTPRINT_HALF_WIDTH, FOOTPRINT_HALF_WIDTH)
	var cy: float = clampf(l.y, -FOOTPRINT_EXTENT_ABOVE_CENTER, FOOTPRINT_EXTENT_BELOW_CENTER)
	return global_position + Vector2(cx, cy)


func distance_to_footprint_edge(world_pos: Vector2) -> float:
	return world_pos.distance_to(closest_point_on_footprint_world(world_pos))


@export var team_id: int = 0
@export var team_name: String = "Team"
@export var max_health: float = 8500.0
## Ranged defense vs enemy units; kills credit this fort owner (individual kill track).
@export var defense_range: float = 270.0
@export var defense_damage: float = 32.0
@export var defense_interval: float = 0.36

var health: float = 8500.0
var _defense_cd: float = 0.0
var _owner_base: PlayerBase = null

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _label: Label = $Label


func set_owner_base(player_base: PlayerBase) -> void:
	_owner_base = player_base


func apply_player_visual(accent: Color) -> void:
	if _sprite:
		_sprite.texture = ProceduralTextures.create_fort_texture(accent)
	if _label:
		_label.add_theme_font_override("font", ProceduralTextures.default_ui_font())
		_label.add_theme_color_override("font_color", Color(0.96, 0.96, 0.98))
	_refresh_label()


func _ready() -> void:
	add_to_group("bunkers")
	if _label:
		_label.add_theme_font_override("font", ProceduralTextures.default_ui_font())
	health = max_health
	_defense_cd = randf() * defense_interval
	_refresh_label()
	health_changed.emit(health, max_health)


func _physics_process(delta: float) -> void:
	if health <= 0.0:
		return
	var mgr := get_tree().get_first_node_in_group("match_manager")
	if mgr and mgr.has_method("is_match_over") and mgr.is_match_over():
		return
	_defense_cd -= delta
	if _defense_cd > 0.0:
		return
	var victim := _find_nearest_enemy_unit_in_range()
	if victim == null:
		return
	victim.take_damage(defense_damage, team_id, _owner_base)
	_defense_cd = defense_interval


func _find_nearest_enemy_unit_in_range() -> CombatUnit:
	var best: CombatUnit = null
	var best_d := INF
	for u in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(u):
			continue
		var cu := u as CombatUnit
		if cu.team_id == team_id:
			continue
		var d := global_position.distance_to(cu.global_position)
		if d > defense_range:
			continue
		if d < best_d:
			best_d = d
			best = cu
	return best


func _refresh_label() -> void:
	if _label:
		_label.text = "%s\n%.0f / %.0f" % [team_name, health, max_health]


func take_damage(amount: float, attacker_team: int, _killer: PlayerBase = null) -> void:
	if attacker_team == team_id:
		return
	health -= amount
	_refresh_label()
	health_changed.emit(health, max_health)
	if health <= 0.0:
		destroyed_bunker.emit(team_id)
		queue_free()
