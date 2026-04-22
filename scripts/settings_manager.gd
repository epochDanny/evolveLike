extends Node

## Persists and applies user audio levels on the Music and SFX buses (see MusicRouter, SfxRouter).

const CONFIG_PATH := "user://settings.cfg"
const SECTION := "audio"

const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"

const KEY_MUSIC_LINEAR := "music_volume_linear"
const KEY_SFX_LINEAR := "sfx_volume_linear"
const KEY_MUSIC_MUTE := "music_mute"
const KEY_SFX_MUTE := "sfx_mute"

var _music_mute: bool = false
var _sfx_mute: bool = false
## Cached linear volumes (0..1) used when a bus is not muted.
var _music_linear: float = 1.0
var _sfx_linear: float = 1.0


func _ready() -> void:
	_load_and_apply()


func is_music_muted() -> bool:
	return _music_mute


func is_sfx_muted() -> bool:
	return _sfx_mute


func get_music_volume_linear() -> float:
	return _music_linear


func get_sfx_volume_linear() -> float:
	return _sfx_linear


func set_music_muted(muted: bool) -> void:
	_music_mute = muted
	_apply_buses()
	_save()


func set_sfx_muted(muted: bool) -> void:
	_sfx_mute = muted
	_apply_buses()
	_save()


func set_music_volume_linear(linear: float) -> void:
	_music_linear = clampf(linear, 0.0, 1.0)
	_apply_buses()
	_save()


func set_sfx_volume_linear(linear: float) -> void:
	_sfx_linear = clampf(linear, 0.0, 1.0)
	_apply_buses()
	_save()


func _load_and_apply() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		_music_linear = clampf(
			float(cfg.get_value(SECTION, KEY_MUSIC_LINEAR, 1.0)),
			0.0,
			1.0
		)
		_sfx_linear = clampf(
			float(cfg.get_value(SECTION, KEY_SFX_LINEAR, 1.0)),
			0.0,
			1.0
		)
		_music_mute = bool(cfg.get_value(SECTION, KEY_MUSIC_MUTE, false))
		_sfx_mute = bool(cfg.get_value(SECTION, KEY_SFX_MUTE, false))
	_apply_buses()


func _apply_buses() -> void:
	_set_bus_mute_and_linear(BUS_MUSIC, _music_mute, _music_linear)
	_set_bus_mute_and_linear(BUS_SFX, _sfx_mute, _sfx_linear)


func _set_bus_mute_and_linear(bus_name: String, muted: bool, linear: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, muted)
	## When muted, keep stored linear; engine mute silences output.
	if not muted:
		AudioServer.set_bus_volume_linear(idx, linear)


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, KEY_MUSIC_LINEAR, _music_linear)
	cfg.set_value(SECTION, KEY_SFX_LINEAR, _sfx_linear)
	cfg.set_value(SECTION, KEY_MUSIC_MUTE, _music_mute)
	cfg.set_value(SECTION, KEY_SFX_MUTE, _sfx_mute)
	cfg.save(CONFIG_PATH)
