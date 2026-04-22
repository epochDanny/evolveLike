extends Control

@onready var _mode: OptionButton = %ModeOption
@onready var _teams_size: OptionButton = %TeamsSizeOption
@onready var _ffa_count: OptionButton = %FFAPlayerOption
@onready var _ffa_label: Label = $Center/VBox/FFALabel
@onready var _teams_label: Label = $Center/VBox/TeamsLabel
@onready var _human_slot: OptionButton = %HumanSlotOption
@onready var _main_vbox: Control = $Center/VBox
@onready var _settings_overlay: Control = $SettingsLayer/SettingsOverlay
@onready var _music_volume: HSlider = %MusicVolumeSlider
@onready var _sfx_volume: HSlider = %SfxVolumeSlider
@onready var _music_mute: CheckBox = %MusicMuteCheck
@onready var _sfx_mute: CheckBox = %SfxMuteCheck
@onready var _music_percent: Label = %MusicPercent
@onready var _sfx_percent: Label = %SfxPercent

var _syncing_settings_ui: bool = false


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


func _on_settings_pressed() -> void:
	_sync_settings_ui_from_manager()
	_settings_overlay.show()
	_main_vbox.hide()


func _on_settings_back_pressed() -> void:
	_settings_overlay.hide()
	_main_vbox.show()


func _sync_settings_ui_from_manager() -> void:
	_syncing_settings_ui = true
	var m_lin: float = SettingsManager.get_music_volume_linear()
	var s_lin: float = SettingsManager.get_sfx_volume_linear()
	_music_volume.value = m_lin * 100.0
	_sfx_volume.value = s_lin * 100.0
	_music_mute.button_pressed = SettingsManager.is_music_muted()
	_sfx_mute.button_pressed = SettingsManager.is_sfx_muted()
	_music_percent.text = "%d%%" % int(roundf(m_lin * 100.0))
	_sfx_percent.text = "%d%%" % int(roundf(s_lin * 100.0))
	_syncing_settings_ui = false


func _on_music_volume_changed(value: float) -> void:
	_music_percent.text = "%d%%" % int(value)
	if _syncing_settings_ui:
		return
	SettingsManager.set_music_volume_linear(value / 100.0)


func _on_sfx_volume_changed(value: float) -> void:
	_sfx_percent.text = "%d%%" % int(value)
	if _syncing_settings_ui:
		return
	SettingsManager.set_sfx_volume_linear(value / 100.0)


func _on_music_mute_toggled(pressed: bool) -> void:
	if _syncing_settings_ui:
		return
	SettingsManager.set_music_muted(pressed)


func _on_sfx_mute_toggled(pressed: bool) -> void:
	if _syncing_settings_ui:
		return
	SettingsManager.set_sfx_muted(pressed)
