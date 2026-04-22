extends Node

## Background music autoload. One track at a time, looped, on its own bus so
## the SFX mix is independent. Use play_match_music() when a match starts and
## stop_match_music() (optionally with a fade) when it ends or the player
## leaves to the menu.

const MATCH_AMBIENT: AudioStream = preload("res://assets/audio/music/match_ambient.ogg")

const BUS_NAME := "Music"
## Target playing volume in dB. Music loops are mastered loud relative to
## game SFX, so sit this well below 0.
const MUSIC_VOLUME_DB := -16.0
## Effective silence for fades.
const SILENT_DB := -60.0
const DEFAULT_FADE_IN := 1.5
const DEFAULT_FADE_OUT := 1.0

var _player: AudioStreamPlayer = null
var _fade_tween: Tween = null
var _current_stream: AudioStream = null


func _ready() -> void:
	_ensure_bus()
	if MATCH_AMBIENT == null:
		push_error("MusicRouter: MATCH_AMBIENT failed to preload (asset missing / not imported yet).")
	else:
		_ensure_loop(MATCH_AMBIENT)
	_player = AudioStreamPlayer.new()
	_player.bus = BUS_NAME
	_player.volume_db = SILENT_DB
	## Pause the music when the game pauses (pause menu, match-over modal).
	_player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_player)
	print(
		"[MusicRouter] ready. stream=",
		MATCH_AMBIENT,
		" bus=",
		BUS_NAME,
		" bus_idx=",
		AudioServer.get_bus_index(BUS_NAME),
	)


func play_match_music(fade_in: float = DEFAULT_FADE_IN) -> void:
	_play(MATCH_AMBIENT, fade_in)


func stop_match_music(fade_out: float = DEFAULT_FADE_OUT) -> void:
	_stop(fade_out)


func set_music_volume_db(db: float) -> void:
	if AudioServer.get_bus_index(BUS_NAME) != -1:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_NAME), db)


func _play(stream: AudioStream, fade_in: float) -> void:
	if stream == null:
		push_error("MusicRouter: tried to play null stream.")
		return
	if _player == null:
		push_error("MusicRouter: _player is null; autoload not ready?")
		return
	if _current_stream == stream and _player.playing:
		return
	_current_stream = stream
	_player.stream = stream
	_player.volume_db = SILENT_DB
	_player.play()
	print(
		"[MusicRouter] play ",
		stream.resource_path,
		" playing=",
		_player.playing,
		" fade_in=",
		fade_in,
	)
	_kill_fade()
	## Tween must not obey tree pause — otherwise the fade stalls the moment
	## the game pauses during fade-in (e.g. match-over triggered instantly).
	_fade_tween = create_tween()
	_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade_tween.tween_property(_player, "volume_db", MUSIC_VOLUME_DB, maxf(fade_in, 0.01))


func _stop(fade_out: float) -> void:
	if _player == null or not _player.playing:
		return
	_kill_fade()
	if fade_out <= 0.01:
		_player.stop()
		_current_stream = null
		return
	_fade_tween = create_tween()
	_fade_tween.tween_property(_player, "volume_db", SILENT_DB, fade_out)
	_fade_tween.tween_callback(Callable(self, "_on_fade_out_done"))


func _on_fade_out_done() -> void:
	if _player:
		_player.stop()
	_current_stream = null


func _kill_fade() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null


func _ensure_bus() -> void:
	if AudioServer.get_bus_index(BUS_NAME) != -1:
		return
	var idx: int = AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, BUS_NAME)
	AudioServer.set_bus_send(idx, "Master")


## WAV imports default to loop=off. Force looping on the stream resource so we
## don't depend on hand-edited .import flags.
func _ensure_loop(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		if wav.loop_end <= 0:
			## 0 means "end of sample"; Godot accepts it, but make intent clear.
			wav.loop_begin = 0
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
