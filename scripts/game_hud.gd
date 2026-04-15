extends CanvasLayer

## Runs while the game is paused so P / Esc / R still work.

@onready var _pause_overlay: Label = $PauseOverlay
@onready var _restart_btn: Button = $RestartButton
@onready var _menu_btn: Button = $MenuButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ProceduralTextures.apply_ui_font_to_tree(self)
	if _pause_overlay:
		_pause_overlay.visible = false
	if _restart_btn:
		_restart_btn.pressed.connect(_on_restart_pressed)
	if _menu_btn:
		_menu_btn.pressed.connect(_on_menu_pressed)


func _process(_delta: float) -> void:
	if _pause_overlay:
		_pause_overlay.visible = get_tree().paused


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var e := event as InputEventKey
	if not e.pressed or e.echo:
		return

	var mui := get_tree().get_first_node_in_group("match_ui") as MatchUI
	if mui != null and mui.is_modal_visible():
		return

	if e.keycode == KEY_P or e.keycode == KEY_ESCAPE:
		get_tree().paused = not get_tree().paused
		var vp := get_viewport()
		if vp:
			vp.set_input_as_handled()
		return

	if e.keycode == KEY_R:
		var mgr := get_tree().get_first_node_in_group("match_manager")
		var can_restart := get_tree().paused
		if mgr and mgr.has_method("is_match_over") and mgr.is_match_over():
			can_restart = true
		if can_restart:
			var vp := get_viewport()
			if vp:
				vp.set_input_as_handled()
			_restart_match()


func _on_restart_pressed() -> void:
	_restart_match()


func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _restart_match() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
