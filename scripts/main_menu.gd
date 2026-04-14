extends Control

@onready var _mode: OptionButton = %ModeOption
@onready var _teams_size: OptionButton = %TeamsSizeOption
@onready var _ffa_count: OptionButton = %FFAPlayerOption
@onready var _ffa_label: Label = $Center/VBox/FFALabel
@onready var _teams_label: Label = $Center/VBox/TeamsLabel
@onready var _human_slot: OptionButton = %HumanSlotOption


func _ready() -> void:
	ProceduralTextures.apply_ui_font_to_tree(self)
	_mode.select(0)
	_teams_size.select(2)
	_ffa_count.select(4)
	_on_mode_changed(-1)


func _on_mode_changed(_idx: int) -> void:
	var teams_mode: bool = _mode.selected == 0
	_teams_label.visible = teams_mode
	_teams_size.visible = teams_mode
	_ffa_label.visible = not teams_mode
	_ffa_count.visible = not teams_mode
	_rebuild_human_slots(0)


func _rebuild_human_slots(_i: int = 0) -> void:
	var prev_idx: int = _human_slot.selected
	_human_slot.clear()
	_human_slot.add_item("Random fort")
	var n: int
	if _mode.selected == 0:
		n = (_teams_size.selected + 1) * 2
	else:
		n = _ffa_count.selected + 2
	for s in range(n):
		_human_slot.add_item("You: fort %d" % (s + 1), s)
	if prev_idx <= 0 or prev_idx >= _human_slot.item_count:
		_human_slot.select(0)
	else:
		_human_slot.select(prev_idx)


func _on_start_pressed() -> void:
	var gs := GameSessionManager.instance
	gs.mode = GameSessionManager.Mode.TEAMS if _mode.selected == 0 else GameSessionManager.Mode.FFA
	var n: int
	if gs.mode == GameSessionManager.Mode.TEAMS:
		gs.teams_match_size = _teams_size.selected + 1
		n = gs.teams_match_size * 2
	else:
		gs.ffa_player_count = _ffa_count.selected + 2
		n = gs.ffa_player_count
	if _human_slot.selected == 0:
		gs.human_slot = randi() % n
	else:
		gs.human_slot = _human_slot.selected - 1
	get_tree().change_scene_to_file("res://scenes/arena.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
