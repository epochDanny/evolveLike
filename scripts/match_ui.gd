extends Control
class_name MatchUI

signal main_menu_pressed
signal ffa_watch_pressed

@onready var _dim: ColorRect = $Dim
@onready var _teams_panel: PanelContainer = $TeamsEnd
@onready var _teams_title: Label = $TeamsEnd/Margin/VBox/Title
@onready var _teams_body: Label = $TeamsEnd/Margin/VBox/Body
@onready var _teams_menu: Button = $TeamsEnd/Margin/VBox/ToMenu

@onready var _ffa_elim_panel: PanelContainer = $FFAEliminated
@onready var _ffa_elim_body: Label = $FFAEliminated/Margin/VBox/Body
@onready var _ffa_watch: Button = $FFAEliminated/Margin/VBox/Buttons/Watch
@onready var _ffa_elim_menu: Button = $FFAEliminated/Margin/VBox/Buttons/ToMenu

@onready var _ffa_over_panel: PanelContainer = $FFAOver
@onready var _ffa_over_body: Label = $FFAOver/Margin/VBox/Body
@onready var _ffa_over_menu: Button = $FFAOver/Margin/VBox/ToMenu

@onready var _spectator_bar: PanelContainer = $SpectatorBar
@onready var _spectator_leave: Button = $SpectatorBar/HBox/LeaveButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("match_ui")
	ProceduralTextures.apply_ui_font_to_tree(self)
	hide_all()
	if _teams_menu:
		_teams_menu.pressed.connect(_emit_main_menu)
	if _ffa_watch:
		_ffa_watch.pressed.connect(_on_ffa_watch)
	if _ffa_elim_menu:
		_ffa_elim_menu.pressed.connect(_emit_main_menu)
	if _ffa_over_menu:
		_ffa_over_menu.pressed.connect(_emit_main_menu)
	if _spectator_leave:
		_spectator_leave.pressed.connect(_emit_main_menu)


func is_modal_visible() -> bool:
	if _teams_panel == null:
		return false
	return (
		_teams_panel.visible
		or _ffa_elim_panel.visible
		or _ffa_over_panel.visible
	)


func hide_all() -> void:
	if _dim:
		_dim.visible = false
	if _teams_panel:
		_teams_panel.visible = false
	if _ffa_elim_panel:
		_ffa_elim_panel.visible = false
	if _ffa_over_panel:
		_ffa_over_panel.visible = false
	if _spectator_bar:
		_spectator_bar.visible = false


func show_teams_match_end(human_team_won: bool, winner_team_id: int) -> void:
	hide_all()
	var wletter := "A" if winner_team_id == 0 else "B"
	if human_team_won:
		_teams_title.text = "Congratulations!"
		_teams_body.text = "Team %s wins the match." % wletter
	else:
		_teams_title.text = "Game Over"
		_teams_body.text = "Team %s wins the match.\nYour team has been eliminated." % wletter
	if _dim:
		_dim.visible = true
	if _teams_panel:
		_teams_panel.visible = true


func show_ffa_eliminated() -> void:
	hide_all()
	_ffa_elim_body.text = (
		"Your fort was destroyed.\n\n"
		+ "You can keep watching the match or return to the main menu."
	)
	if _dim:
		_dim.visible = true
	if _ffa_elim_panel:
		_ffa_elim_panel.visible = true


func hide_ffa_eliminated_panel() -> void:
	if _ffa_elim_panel:
		_ffa_elim_panel.visible = false
	if _dim:
		_dim.visible = false


func show_ffa_match_over(winner_line: String) -> void:
	hide_all()
	_ffa_over_body.text = "The match is over.\n\n%s" % winner_line
	if _dim:
		_dim.visible = true
	if _ffa_over_panel:
		_ffa_over_panel.visible = true


func set_spectator_bar_visible(v: bool) -> void:
	if _spectator_bar:
		_spectator_bar.visible = v


func _emit_main_menu() -> void:
	main_menu_pressed.emit()


func _on_ffa_watch() -> void:
	hide_ffa_eliminated_panel()
	set_spectator_bar_visible(true)
	ffa_watch_pressed.emit()
