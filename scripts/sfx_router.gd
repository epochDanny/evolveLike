extends Node

## Global combat SFX. Ensures we never overwhelm the mix: per-source throttle,
## global voice cap per effect, pitch variation, positional 2D audio with an
## off-screen cull so faraway hits stay quiet or drop entirely.

const UNIT_ATTACK: AudioStream = preload("res://assets/audio/unit_attack.ogg")
const BUNKER_ATTACK: AudioStream = preload("res://assets/audio/bunker_attack.ogg")
const UNIT_DEATH: AudioStream = preload("res://assets/audio/unit_death.ogg")
const BUNKER_DESTROYED: AudioStream = preload("res://assets/audio/bunker_destroyed.ogg")

const BUS_NAME := "SFX"

## Minimum seconds between plays triggered by the same source (unit/bunker).
const PER_SOURCE_MIN_INTERVAL := 0.08
## Minimum seconds between ANY plays of a given SFX, regardless of source.
## This is the real "don't overwhelm the mix" knob — caps plays/sec globally.
const UNIT_GLOBAL_MIN_INTERVAL := 0.05
const BUNKER_GLOBAL_MIN_INTERVAL := 0.08
## Death SFX fire less often but land as events; keep the global gate tight so
## a chain wipe doesn't spam ten zaps on one frame.
const UNIT_DEATH_GLOBAL_MIN_INTERVAL := 0.06
const BUNKER_DESTROYED_GLOBAL_MIN_INTERVAL := 0.15
## Max concurrent voices per SFX. Small on purpose: 3 overlapping explosions
## still reads as "lots of combat" without turning into a drone.
const UNIT_VOICE_CAP := 3
const BUNKER_VOICE_CAP := 2
const UNIT_DEATH_VOICE_CAP := 3
const BUNKER_DESTROYED_VOICE_CAP := 2
## +/- pitch_scale randomization to break phase when many stack.
const PITCH_JITTER := 0.1

## 2D attenuation: beyond max_distance the SFX is inaudible. Tighter than the
## viewport so edge-of-screen hits are already quiet.
const MAX_DISTANCE := 650.0
const ATTENUATION := 1.8

## Hard cull beyond camera rect (px margin around visible area).
const OFFSCREEN_CULL_MARGIN := 300.0

## Per-SFX base volume (dB). Kept conservative because a few overlapping
## voices still add ~6 dB of perceived loudness.
const UNIT_VOLUME_DB := -8.0
const BUNKER_VOLUME_DB := -10.0
## Death events want to cut through; a touch louder, but still reined in.
const UNIT_DEATH_VOLUME_DB := -6.0
## Bunker destroyed is a once-per-match payoff moment — full presence.
const BUNKER_DESTROYED_VOLUME_DB := 0.0

var _unit_voices: Array[AudioStreamPlayer2D] = []
var _bunker_voices: Array[AudioStreamPlayer2D] = []
var _unit_death_voices: Array[AudioStreamPlayer2D] = []
var _bunker_destroyed_voices: Array[AudioStreamPlayer2D] = []
## instance_id -> last play time (seconds, engine clock).
var _last_play_by_source: Dictionary = {}
## Last global play time per SFX channel (seconds).
var _last_unit_play: float = -1.0
var _last_bunker_play: float = -1.0
var _last_unit_death_play: float = -1.0
var _last_bunker_destroyed_play: float = -1.0
var _prune_accum: float = 0.0


func _ready() -> void:
	_ensure_bus()
	for i in range(UNIT_VOICE_CAP):
		_unit_voices.append(_make_voice(UNIT_ATTACK, UNIT_VOLUME_DB))
	for i in range(BUNKER_VOICE_CAP):
		_bunker_voices.append(_make_voice(BUNKER_ATTACK, BUNKER_VOLUME_DB))
	for i in range(UNIT_DEATH_VOICE_CAP):
		_unit_death_voices.append(_make_voice(UNIT_DEATH, UNIT_DEATH_VOLUME_DB))
	for i in range(BUNKER_DESTROYED_VOICE_CAP):
		_bunker_destroyed_voices.append(
			_make_voice(BUNKER_DESTROYED, BUNKER_DESTROYED_VOLUME_DB)
		)


func _process(delta: float) -> void:
	_prune_accum += delta
	if _prune_accum >= 2.0:
		_prune_accum = 0.0
		_prune_stale_sources()


func _ensure_bus() -> void:
	if AudioServer.get_bus_index(BUS_NAME) != -1:
		return
	var idx: int = AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, BUS_NAME)
	AudioServer.set_bus_send(idx, "Master")


func _make_voice(stream: AudioStream, volume_db: float) -> AudioStreamPlayer2D:
	var p := AudioStreamPlayer2D.new()
	p.stream = stream
	p.bus = BUS_NAME
	p.max_distance = MAX_DISTANCE
	p.attenuation = ATTENUATION
	p.volume_db = volume_db
	add_child(p)
	return p


func play_unit_attack(world_pos: Vector2, source: Node) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_unit_play < UNIT_GLOBAL_MIN_INTERVAL:
		return
	if not _play(world_pos, source, _unit_voices, UNIT_VOLUME_DB):
		return
	_last_unit_play = now


func play_bunker_attack(world_pos: Vector2, source: Node) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_bunker_play < BUNKER_GLOBAL_MIN_INTERVAL:
		return
	if not _play(world_pos, source, _bunker_voices, BUNKER_VOLUME_DB):
		return
	_last_bunker_play = now


func play_unit_death(world_pos: Vector2, source: Node) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_unit_death_play < UNIT_DEATH_GLOBAL_MIN_INTERVAL:
		return
	if not _play(world_pos, source, _unit_death_voices, UNIT_DEATH_VOLUME_DB):
		return
	_last_unit_death_play = now


## Bunker-destroyed is a match beat: bypass the off-screen cull and don't
## attenuate by distance so the player always hears a fort fall, even if the
## camera is elsewhere.
func play_bunker_destroyed(world_pos: Vector2, source: Node) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_bunker_destroyed_play < BUNKER_DESTROYED_GLOBAL_MIN_INTERVAL:
		return
	if not _source_throttle_ok(source):
		return
	var voice := _find_free_voice(_bunker_destroyed_voices)
	if voice == null:
		return
	voice.global_position = world_pos
	voice.volume_db = BUNKER_DESTROYED_VOLUME_DB
	voice.pitch_scale = 1.0 + randf_range(-PITCH_JITTER, PITCH_JITTER)
	voice.play()
	_last_bunker_destroyed_play = now


func _play(
	world_pos: Vector2,
	source: Node,
	voices: Array[AudioStreamPlayer2D],
	volume_db: float
) -> bool:
	if not _source_throttle_ok(source):
		return false
	if _is_far_offscreen(world_pos):
		return false
	var voice := _find_free_voice(voices)
	if voice == null:
		return false
	voice.global_position = world_pos
	voice.volume_db = volume_db
	voice.pitch_scale = 1.0 + randf_range(-PITCH_JITTER, PITCH_JITTER)
	voice.play()
	return true


func _source_throttle_ok(source: Node) -> bool:
	if source == null or not is_instance_valid(source):
		return true
	var id: int = source.get_instance_id()
	var now: float = Time.get_ticks_msec() / 1000.0
	if _last_play_by_source.has(id):
		var last: float = _last_play_by_source[id]
		if now - last < PER_SOURCE_MIN_INTERVAL:
			return false
	_last_play_by_source[id] = now
	return true


func _find_free_voice(voices: Array[AudioStreamPlayer2D]) -> AudioStreamPlayer2D:
	for v in voices:
		if not v.playing:
			return v
	return null


func _is_far_offscreen(world_pos: Vector2) -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	var vp := tree.root.get_viewport()
	if vp == null:
		return false
	var cam := vp.get_camera_2d()
	if cam == null:
		return false
	var vsize: Vector2 = vp.get_visible_rect().size
	var cam_center: Vector2 = cam.get_screen_center_position()
	var half: Vector2 = vsize * 0.5
	var margin := Vector2(OFFSCREEN_CULL_MARGIN, OFFSCREEN_CULL_MARGIN)
	var rect := Rect2(cam_center - half - margin, vsize + margin * 2.0)
	return not rect.has_point(world_pos)


## Remove entries for freed instances so the dict doesn't grow forever.
func _prune_stale_sources() -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	var to_remove: Array[int] = []
	for key in _last_play_by_source.keys():
		var t: float = _last_play_by_source[key]
		if now - t > 5.0:
			to_remove.append(int(key))
	for id in to_remove:
		_last_play_by_source.erase(id)
