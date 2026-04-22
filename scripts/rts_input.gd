extends Control

## Selection and move/attack orders for the human player's units. Placed first under HUD CanvasLayer so toolbar buttons stay on top for input.

const BOX_MIN_DRAG_PX := 6.0
const UNIT_PICK_RADIUS := 28.0
## Slightly larger so attack-move and enemy inspect register on first try.
const ENEMY_UNIT_PICK_RADIUS := 44.0

var _human: PlayerBase
var _camera: Camera2D

var _lmb_down: bool = false
var _box_screen_start: Vector2 = Vector2.ZERO
var _selected: Array[CombatUnit] = []
var _selected_bunker: Bunker = null
var _inspected_enemy_unit: CombatUnit = null
var _inspected_enemy_bunker: Bunker = null

var _mgr: Node = null


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	_camera = get_node_or_null("../../Camera2D") as Camera2D
	call_deferred("_cache_human")


func _cache_human() -> void:
	_mgr = get_tree().get_first_node_in_group("match_manager")
	if _mgr and _mgr.has_method("get_human_player"):
		_human = _mgr.get_human_player()


func _process(_delta: float) -> void:
	if _lmb_down:
		queue_redraw()


func _draw() -> void:
	if not _lmb_down:
		return
	var p1 := _box_screen_start
	var p2 := get_viewport().get_mouse_position()
	var gp := get_global_rect().position
	var r := Rect2(
		Vector2(minf(p1.x, p2.x), minf(p1.y, p2.y)) - gp,
		Vector2(absf(p1.x - p2.x), absf(p1.y - p2.y))
	)
	draw_rect(r, Color(0.2, 0.82, 0.32, 0.22), true)
	draw_rect(r, Color(0.35, 1.0, 0.45, 0.88), false, 1.0)


func _gui_input(event: InputEvent) -> void:
	if not _can_rts():
		return
	var mui := get_tree().get_first_node_in_group("match_ui") as MatchUI
	if mui != null and mui.is_modal_visible():
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_lmb_down = true
				_box_screen_start = get_viewport().get_mouse_position()
			else:
				_on_lmb_released()
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_issue_orders_at_mouse()
			accept_event()
			return


func _can_rts() -> bool:
	if get_tree().paused:
		return false
	if _mgr == null or not is_instance_valid(_mgr):
		_cache_human()
	if _mgr and _mgr.has_method("is_match_over") and _mgr.is_match_over():
		return false
	if _human == null or not is_instance_valid(_human):
		_cache_human()
	if _human == null or not is_instance_valid(_human):
		return false
	if _human.is_eliminated:
		return false
	return true


func _on_lmb_released() -> void:
	if not _lmb_down:
		return
	_lmb_down = false
	queue_redraw()
	_prune_selection()

	var p1 := _box_screen_start
	var p2 := get_viewport().get_mouse_position()
	var drag := p1.distance_to(p2)

	if drag < BOX_MIN_DRAG_PX:
		_click_select_at(p2)
	else:
		_box_select(p1, p2)


func _screen_to_world(screen: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen


func _click_select_at(screen: Vector2) -> void:
	var world := _screen_to_world(screen)
	var u := _pick_own_unit_at(world)
	var add := Input.is_key_pressed(KEY_SHIFT)

	if u != null:
		_clear_enemy_inspect()
		if add:
			_deselect_bunker()
			if u in _selected:
				_selected.erase(u)
				u.set_selected(false)
			else:
				_selected.append(u)
				u.set_selected(true)
		else:
			_clear_selection_visual()
			_selected = [u]
			u.set_selected(true)
	else:
		var bunker_here := _pick_own_bunker_at(world)
		if bunker_here != null:
			_clear_enemy_inspect()
			_clear_selection_visual()
			_selected.clear()
			_selected_bunker = bunker_here
			bunker_here.set_selected(true)
		else:
			var enemy_u := _pick_enemy_unit_at(world)
			if enemy_u != null:
				_set_inspected_enemy_unit(enemy_u)
			else:
				var enemy_b := _pick_enemy_bunker_at(world)
				if enemy_b != null:
					_set_inspected_enemy_bunker(enemy_b)
				elif not add:
					_clear_selection_visual()
					_selected.clear()
					_clear_enemy_inspect()


func _box_select(p1_screen: Vector2, p2_screen: Vector2) -> void:
	var r_screen := Rect2(
		Vector2(minf(p1_screen.x, p2_screen.x), minf(p1_screen.y, p2_screen.y)),
		Vector2(absf(p1_screen.x - p2_screen.x), absf(p1_screen.y - p2_screen.y))
	)
	var w_rect := _world_rect_from_screen_rect(r_screen)
	var add := Input.is_key_pressed(KEY_SHIFT)
	if not add:
		_clear_selection_visual()
		_selected.clear()
		_clear_enemy_inspect()
	else:
		_deselect_bunker()
		_clear_enemy_inspect()

	for u in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(u) or not (u is CombatUnit):
			continue
		var cu := u as CombatUnit
		if not _is_own_unit(cu):
			continue
		if w_rect.has_point(cu.global_position):
			if cu not in _selected:
				_selected.append(cu)
				cu.set_selected(true)


func _world_rect_from_screen_rect(screen_rect: Rect2) -> Rect2:
	var c0 := _screen_to_world(screen_rect.position)
	var c1 := _screen_to_world(screen_rect.position + Vector2(screen_rect.size.x, 0.0))
	var c2 := _screen_to_world(screen_rect.position + screen_rect.size)
	var c3 := _screen_to_world(screen_rect.position + Vector2(0.0, screen_rect.size.y))
	var min_x := minf(minf(c0.x, c1.x), minf(c2.x, c3.x))
	var max_x := maxf(maxf(c0.x, c1.x), maxf(c2.x, c3.x))
	var min_y := minf(minf(c0.y, c1.y), minf(c2.y, c3.y))
	var max_y := maxf(maxf(c0.y, c1.y), maxf(c2.y, c3.y))
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))


func _pick_own_unit_at(world: Vector2) -> CombatUnit:
	var best: CombatUnit = null
	var best_d := UNIT_PICK_RADIUS
	for u in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(u) or not (u is CombatUnit):
			continue
		var cu := u as CombatUnit
		if not _is_own_unit(cu):
			continue
		var d := world.distance_to(cu.global_position)
		if d <= best_d:
			best_d = d
			best = cu
	return best


func _is_own_unit(cu: CombatUnit) -> bool:
	if cu.hp <= 0.0:
		return false
	var owner := cu.get_owner_player()
	return owner != null and is_instance_valid(owner) and owner == _human


func _deselect_bunker() -> void:
	if _selected_bunker != null and is_instance_valid(_selected_bunker):
		_selected_bunker.set_selected(false)
	_selected_bunker = null


func _clear_enemy_inspect() -> void:
	if _inspected_enemy_unit != null and is_instance_valid(_inspected_enemy_unit):
		_inspected_enemy_unit.set_enemy_inspected(false)
	_inspected_enemy_unit = null
	if _inspected_enemy_bunker != null and is_instance_valid(_inspected_enemy_bunker):
		_inspected_enemy_bunker.set_enemy_inspected(false)
	_inspected_enemy_bunker = null


func _set_inspected_enemy_unit(u: CombatUnit) -> void:
	_deselect_bunker()
	_clear_enemy_inspect()
	_inspected_enemy_unit = u
	u.set_enemy_inspected(true)


func _set_inspected_enemy_bunker(b: Bunker) -> void:
	_deselect_bunker()
	_clear_enemy_inspect()
	_inspected_enemy_bunker = b
	b.set_enemy_inspected(true)


func _clear_selection_visual() -> void:
	for u in _selected:
		if is_instance_valid(u):
			u.set_selected(false)
	_deselect_bunker()


func _prune_selection() -> void:
	var next: Array[CombatUnit] = []
	for u in _selected:
		if is_instance_valid(u) and u.hp > 0.0:
			next.append(u)
		elif is_instance_valid(u):
			u.set_selected(false)
	_selected = next
	if _selected_bunker != null:
		if not is_instance_valid(_selected_bunker) or _selected_bunker.health <= 0.0:
			if is_instance_valid(_selected_bunker):
				_selected_bunker.set_selected(false)
			_selected_bunker = null
	if _inspected_enemy_unit != null:
		if not is_instance_valid(_inspected_enemy_unit) or _inspected_enemy_unit.hp <= 0.0:
			if is_instance_valid(_inspected_enemy_unit):
				_inspected_enemy_unit.set_enemy_inspected(false)
			_inspected_enemy_unit = null
	if _inspected_enemy_bunker != null:
		if not is_instance_valid(_inspected_enemy_bunker) or _inspected_enemy_bunker.health <= 0.0:
			if is_instance_valid(_inspected_enemy_bunker):
				_inspected_enemy_bunker.set_enemy_inspected(false)
			_inspected_enemy_bunker = null


func _issue_orders_at_mouse() -> void:
	_prune_selection()
	if _selected.is_empty():
		return
	var world := _screen_to_world(get_viewport().get_mouse_position())

	var enemy_u := _pick_enemy_unit_at(world)
	if enemy_u != null:
		for u in _selected:
			if is_instance_valid(u):
				u.set_player_attack_order(enemy_u)
		return

	var bunker := _pick_enemy_bunker_at(world)
	if bunker != null:
		for u in _selected:
			if is_instance_valid(u):
				u.set_player_attack_order(bunker)
		return

	for u in _selected:
		if is_instance_valid(u):
			u.set_player_move_order(world)


func _pick_enemy_unit_at(world: Vector2) -> CombatUnit:
	var best: CombatUnit = null
	var best_d := ENEMY_UNIT_PICK_RADIUS
	for u in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(u) or not (u is CombatUnit):
			continue
		var cu := u as CombatUnit
		if cu.hp <= 0.0:
			continue
		if GameSessionManager.instance.are_allied(_human.team_id, cu.team_id):
			continue
		var d := world.distance_to(cu.global_position)
		if d <= best_d:
			best_d = d
			best = cu
	return best


func _pick_enemy_bunker_at(world: Vector2) -> Bunker:
	var best: Bunker = null
	var best_d := 96.0
	for b in get_tree().get_nodes_in_group("bunkers"):
		if not is_instance_valid(b) or not (b is Bunker):
			continue
		var bu := b as Bunker
		if bu.health <= 0.0:
			continue
		if GameSessionManager.instance.are_allied(_human.team_id, bu.team_id):
			continue
		var d := bu.distance_to_footprint_edge(world)
		if d <= best_d:
			best_d = d
			best = bu
	return best


func _pick_own_bunker_at(world: Vector2) -> Bunker:
	if _human == null or _human.bunker == null or not is_instance_valid(_human.bunker):
		return null
	var bu := _human.bunker
	if bu.health <= 0.0:
		return null
	if bu.distance_to_footprint_edge(world) <= 96.0:
		return bu
	return null
