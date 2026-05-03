class_name CombatUnit
extends CharacterBody2D

enum PlayerOrder { NONE, MOVE, ATTACK }

var team_id: int = -1
var max_hp: float = 50.0
var hp: float = 50.0
var damage: float = 5.0
var move_speed: float = 100.0
var attack_range: float = 30.0
var attack_cooldown: float = 0.5
## Owner identity color (bunker/spawner); tier digit uses this color.
var player_accent: Color = Color.WHITE
var tier_display: int = 1

var _attack_timer: float = 0.0
var _target: Node2D = null
var _last_killer: PlayerBase = null
## Spawner's fort; used so AI prioritizes enemy units until late evolution.
var _owner_player: PlayerBase = null

var _player_order: PlayerOrder = PlayerOrder.NONE
var _move_goal: Vector2 = Vector2.ZERO
var _attack_order_target: Node2D = null

var _friendly_selected: bool = false
var _enemy_inspect: bool = false

const _FRIENDLY_RING := Color(0.35, 0.95, 0.42, 0.95)
const _ENEMY_INSPECT_RING := Color(0.98, 0.38, 0.32, 0.96)

## Kenney animal pack (Round); used for tier 3+ (tiers 1–2 use custom mite / striker art).
const _KENNEY_ROUND_TEXTURES: Array[Texture2D] = [
	preload("res://assets/units/kenney_animal_pack/elephant.png"),
	preload("res://assets/units/kenney_animal_pack/giraffe.png"),
	preload("res://assets/units/kenney_animal_pack/hippo.png"),
	preload("res://assets/units/kenney_animal_pack/monkey.png"),
	preload("res://assets/units/kenney_animal_pack/panda.png"),
	preload("res://assets/units/kenney_animal_pack/parrot.png"),
	preload("res://assets/units/kenney_animal_pack/penguin.png"),
	preload("res://assets/units/kenney_animal_pack/pig.png"),
	preload("res://assets/units/kenney_animal_pack/rabbit.png"),
	preload("res://assets/units/kenney_animal_pack/snake.png"),
]

## Preview path: keep gameplay 2D, but render coworker 3D marble scenes as unit sprites.
const _USE_MARBLE_PREVIEW_UNITS := true
const _MARBLE_UNIT_SCENES: Array[PackedScene] = [
	preload("res://scenes/units/elephant_marble.tscn"),
	preload("res://scenes/units/snake_marble.tscn"),
	preload("res://scenes/units/pig_marble.tscn"),
	preload("res://scenes/units/monkey_marble.tscn"),
]
const _MARBLE_VIEWPORT_SIZE := Vector2i(96, 96)
const _MARBLE_SPRITE_SCALE := Vector2(0.58, 0.58)
const _CUSTOM_UNIT_SCALE := Vector2(0.11, 0.11)
const _CUSTOM_UNIT_WALK_FPS := 9.0

static var _mite_sprite_frames: SpriteFrames
static var _striker_sprite_frames: SpriteFrames
static var _unit_keyed_textures: Dictionary = {}

@onready var _tier_label: Label = $TierLabel
@onready var _body_sprite: Sprite2D = $Sprite2D
@onready var _mite_anim: AnimatedSprite2D = $MiteAnim
@onready var _striker_anim: AnimatedSprite2D = $StrikerAnim
@onready var _nav: NavigationAgent2D = $NavigationAgent2D

var _marble_viewport: SubViewport
var _marble_root: Node3D


func set_owner_player(player_base: PlayerBase) -> void:
	_owner_player = player_base


func get_owner_player() -> PlayerBase:
	return _owner_player


func set_selected(selected: bool) -> void:
	_friendly_selected = selected
	if selected:
		_enemy_inspect = false
	queue_redraw()


func set_enemy_inspected(inspected: bool) -> void:
	_enemy_inspect = inspected
	if inspected:
		_friendly_selected = false
	queue_redraw()


func set_player_move_order(world_pos: Vector2) -> void:
	_player_order = PlayerOrder.MOVE
	_move_goal = world_pos
	_attack_order_target = null
	_target = null


func set_player_attack_order(enemy: Node2D) -> void:
	_player_order = PlayerOrder.ATTACK
	_attack_order_target = enemy
	_move_goal = Vector2.ZERO


func clear_player_orders() -> void:
	_player_order = PlayerOrder.NONE
	_attack_order_target = null
	_move_goal = Vector2.ZERO


func setup_from_stats(
	stats: Dictionary, p_team_id: int, p_player_accent: Color, tier_index_1_based: int
) -> void:
	team_id = p_team_id
	player_accent = p_player_accent
	tier_display = tier_index_1_based
	max_hp = float(stats["max_hp"])
	hp = max_hp
	damage = float(stats["damage"])
	move_speed = float(stats["speed"])
	attack_range = float(stats["attack_range"])
	attack_cooldown = float(stats["attack_cooldown"])


func _ready() -> void:
	add_to_group("units")
	motion_mode = MOTION_MODE_FLOATING
	# Layer 2: units; layer 3 (bit value 4): bunker StaticBody2D — cannot walk through forts.
	collision_layer = 2
	collision_mask = 2 | 4
	_nav.avoidance_enabled = true
	_nav.radius = 22.0
	_nav.neighbor_distance = 64.0
	_nav.path_desired_distance = 10.0
	_nav.target_desired_distance = 6.0
	_nav.max_speed = maxf(move_speed, 1.0)
	GameSessionManager.instance.configure_unit_avoidance(_nav, team_id)
	_nav.velocity_computed.connect(_on_velocity_computed)
	_apply_unit_visual()


func _draw() -> void:
	if not _friendly_selected and not _enemy_inspect:
		return
	var ring: Color = _FRIENDLY_RING if _friendly_selected else _ENEMY_INSPECT_RING
	draw_arc(Vector2.ZERO, 19.0, 0.0, TAU, 48, ring, 2.0, true)
	var bar_top := -72.0
	if _enemy_inspect:
		var txt := "%.0f / %.0f" % [hp, max_hp]
		var font := ProceduralTextures.default_ui_font()
		var fs := 11
		var sz: Vector2 = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(
			font,
			Vector2(-sz.x * 0.5, bar_top - float(fs) - 2.0),
			txt,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			fs,
			Color(0.98, 0.45, 0.4, 0.98)
		)
	HealthBarUtil.draw_bar(self, 0.0, bar_top, 44.0, 5.0, hp, max_hp)


static func _texture_black_to_transparent(src: Texture2D) -> Texture2D:
	if src == null:
		return null
	var path := src.resource_path
	if path != "" and _unit_keyed_textures.has(path):
		return _unit_keyed_textures[path]
	var img: Image = src.get_image()
	if img == null and src.resource_path != "":
		var host_path := ProjectSettings.globalize_path(src.resource_path)
		if FileAccess.file_exists(host_path):
			var f := FileAccess.open(host_path, FileAccess.READ)
			if f != null:
				var buf := f.get_buffer(f.get_length())
				var disk := Image.new()
				var err: Error = disk.load_png_from_buffer(buf)
				if err != OK:
					disk = Image.new()
					err = disk.load_jpg_from_buffer(buf)
				if err == OK:
					img = disk
	if img == null:
		return src
	img = img.duplicate()
	img.convert(Image.FORMAT_RGBA8)
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var c := img.get_pixel(x, y)
			if c.r <= 0.05 and c.g <= 0.05 and c.b <= 0.05:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	var out := ImageTexture.create_from_image(img)
	if path != "":
		_unit_keyed_textures[path] = out
	return out


static func _get_mite_sprite_frames() -> SpriteFrames:
	if _mite_sprite_frames != null:
		return _mite_sprite_frames
	var sf := SpriteFrames.new()
	var idle_tex := _texture_black_to_transparent(
		load("res://assets/units/mite_tier1/mite_idle.jpg") as Texture2D
	)
	var w1 := _texture_black_to_transparent(
		load("res://assets/units/mite_tier1/mite_walk_1.jpg") as Texture2D
	)
	var w2 := _texture_black_to_transparent(
		load("res://assets/units/mite_tier1/mite_walk_2.jpg") as Texture2D
	)
	var w3 := _texture_black_to_transparent(
		load("res://assets/units/mite_tier1/mite_walk_3.jpg") as Texture2D
	)
	sf.add_animation("idle")
	sf.set_animation_loop("idle", true)
	sf.set_animation_speed("idle", 1.0)
	sf.add_frame("idle", idle_tex, 1.0)
	sf.add_animation("walk")
	sf.set_animation_loop("walk", true)
	sf.set_animation_speed("walk", _CUSTOM_UNIT_WALK_FPS)
	sf.add_frame("walk", w1, 1.0)
	sf.add_frame("walk", w2, 1.0)
	sf.add_frame("walk", w3, 1.0)
	_mite_sprite_frames = sf
	return sf


static func _get_striker_sprite_frames() -> SpriteFrames:
	if _striker_sprite_frames != null:
		return _striker_sprite_frames
	var sf := SpriteFrames.new()
	var idle_tex := _texture_black_to_transparent(
		load("res://assets/units/striker_tier2/striker_idle.jpg") as Texture2D
	)
	var w1 := _texture_black_to_transparent(
		load("res://assets/units/striker_tier2/striker_walk_1.jpg") as Texture2D
	)
	var w2 := _texture_black_to_transparent(
		load("res://assets/units/striker_tier2/striker_walk_2.jpg") as Texture2D
	)
	var w3 := _texture_black_to_transparent(
		load("res://assets/units/striker_tier2/striker_walk_3.jpg") as Texture2D
	)
	sf.add_animation("idle")
	sf.set_animation_loop("idle", true)
	sf.set_animation_speed("idle", 1.0)
	sf.add_frame("idle", idle_tex, 1.0)
	sf.add_animation("walk")
	sf.set_animation_loop("walk", true)
	sf.set_animation_speed("walk", _CUSTOM_UNIT_WALK_FPS)
	sf.add_frame("walk", w1, 1.0)
	sf.add_frame("walk", w2, 1.0)
	sf.add_frame("walk", w3, 1.0)
	_striker_sprite_frames = sf
	return sf


func _process(delta: float) -> void:
	if _marble_root != null:
		_spin_marble_visual(delta)
	elif tier_display == 1:
		_sync_custom_unit_anim(_mite_anim)
	elif tier_display == 2:
		_sync_custom_unit_anim(_striker_anim)


func _sync_custom_unit_anim(anim: AnimatedSprite2D) -> void:
	if anim == null or not anim.visible:
		return
	var moving := velocity.length_squared() > 90.0
	if moving:
		if anim.animation != "walk":
			anim.play("walk")
		# Art faces left by default; mirror when moving right (+x).
		if absf(velocity.x) > 6.0:
			anim.flip_h = velocity.x > 0.0
	else:
		if anim.animation != "idle":
			anim.play("idle")


func _apply_unit_visual() -> void:
	if _USE_MARBLE_PREVIEW_UNITS and _body_sprite:
		if _mite_anim:
			_mite_anim.visible = false
		if _striker_anim:
			_striker_anim.visible = false
		if not _apply_marble_visual():
			_apply_kenney_round_visual()
	elif tier_display == 1 and _mite_anim != null:
		_clear_marble_visual()
		_mite_anim.sprite_frames = _get_mite_sprite_frames()
		_mite_anim.scale = _CUSTOM_UNIT_SCALE
		_mite_anim.visible = true
		_mite_anim.play("idle")
		if _striker_anim:
			_striker_anim.visible = false
		if _body_sprite:
			_body_sprite.visible = false
	elif tier_display == 2 and _striker_anim != null:
		_clear_marble_visual()
		_striker_anim.sprite_frames = _get_striker_sprite_frames()
		_striker_anim.scale = _CUSTOM_UNIT_SCALE
		_striker_anim.visible = true
		_striker_anim.play("idle")
		if _mite_anim:
			_mite_anim.visible = false
		if _body_sprite:
			_body_sprite.visible = false
	elif _body_sprite:
		if _mite_anim:
			_mite_anim.visible = false
		if _striker_anim:
			_striker_anim.visible = false
		if not _apply_marble_visual():
			_apply_kenney_round_visual()
	if _tier_label:
		_tier_label.add_theme_font_override("font", ProceduralTextures.default_ui_font())
		_tier_label.text = str(tier_display)
		_tier_label.add_theme_color_override("font_color", player_accent)


func _apply_kenney_round_visual() -> void:
	_clear_marble_visual()
	if _body_sprite == null or _KENNEY_ROUND_TEXTURES.is_empty():
		return
	var idx := (maxi(tier_display, 1) - 1) % _KENNEY_ROUND_TEXTURES.size()
	_body_sprite.texture = _KENNEY_ROUND_TEXTURES[idx]
	_body_sprite.visible = true
	_body_sprite.scale = _CUSTOM_UNIT_SCALE


func _apply_marble_visual() -> bool:
	if _body_sprite == null or _MARBLE_UNIT_SCENES.is_empty():
		return false
	if _marble_viewport == null:
		var scene := _MARBLE_UNIT_SCENES[(maxi(tier_display, 1) - 1) % _MARBLE_UNIT_SCENES.size()]
		var marble := scene.instantiate() as Node3D
		if marble == null:
			return false
		_prepare_marble_scene_for_preview(marble)

		_marble_viewport = SubViewport.new()
		_marble_viewport.name = "MarblePreviewViewport"
		_marble_viewport.size = _MARBLE_VIEWPORT_SIZE
		_marble_viewport.transparent_bg = true
		_marble_viewport.own_world_3d = true
		_marble_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_marble_viewport)

		var light := DirectionalLight3D.new()
		light.name = "PreviewLight"
		light.light_energy = 1.8
		light.rotation_degrees = Vector3(-45.0, -35.0, 0.0)
		_marble_viewport.add_child(light)

		var camera := Camera3D.new()
		camera.name = "PreviewCamera"
		camera.current = true
		camera.fov = 30.0
		camera.position = Vector3(0.0, 0.15, 2.2)
		_marble_viewport.add_child(camera)
		camera.look_at(Vector3.ZERO, Vector3.UP)

		_marble_root = Node3D.new()
		_marble_root.name = "MarbleVisualRoot"
		_marble_viewport.add_child(_marble_root)
		_marble_root.add_child(marble)

	_body_sprite.texture = _marble_viewport.get_texture()
	_body_sprite.visible = true
	_body_sprite.scale = _MARBLE_SPRITE_SCALE
	return true


func _prepare_marble_scene_for_preview(marble: Node3D) -> void:
	for child in marble.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		var sphere := mesh_instance.mesh as SphereMesh
		if sphere == null:
			continue
		sphere = sphere.duplicate()
		sphere.flip_faces = false
		mesh_instance.mesh = sphere


func _clear_marble_visual() -> void:
	_marble_root = null
	if _marble_viewport != null:
		_marble_viewport.queue_free()
		_marble_viewport = null


#func _spin_marble_visual(delta: float) -> void:
	#var speed := 1.1
	#if velocity.length_squared() > 90.0:
		#speed = 4.0
	#_marble_root.rotate_y(speed * delta)
	
	
func _spin_marble_visual(delta: float) -> void:
	# 1. Check if we are actually moving to avoid math errors
	if velocity.length() > 0.1:
		# 2. Define how fast the "roll" should look. 
		# A higher number makes it look like it has more traction.
		var roll_speed := 0.10 
		
		# 3. Calculate the rotation axis. 
		# We take the movement direction and rotate it 90 degrees.
		# Moving Forward (Y) means rotating around X.
		# Moving Right (X) means rotating around Y.
		var rolling_axis = Vector3(velocity.y, 0, -velocity.x).normalized()
		
		# 4. Apply the rotation based on the distance traveled (velocity * delta)
		var amount_to_rotate = velocity.length() * delta * roll_speed
		_marble_root.rotate(rolling_axis, amount_to_rotate)


func _physics_process(delta: float) -> void:
	if hp <= 0.0:
		return
	var mgr := get_tree().get_first_node_in_group("match_manager")
	if mgr and mgr.has_method("is_match_over") and mgr.is_match_over():
		_nav.set_velocity(Vector2.ZERO)
		return
	_attack_timer -= delta

	if _player_order == PlayerOrder.MOVE:
		_run_move_order(delta)
		return

	if _player_order == PlayerOrder.ATTACK:
		if not _attack_order_still_valid():
			clear_player_orders()
			_acquire_target()
		else:
			_target = _attack_order_target
	else:
		_acquire_target()

	_nav.max_speed = maxf(move_speed, 1.0)
	if _target == null or not is_instance_valid(_target):
		_nav.set_velocity(Vector2.ZERO)
		return
	var dist := _distance_to_target_for_combat()
	var nav_goal := _nav_goal_for_target()
	if dist <= attack_range + 4.0:
		_nav.target_position = nav_goal
		_nav.set_velocity(Vector2.ZERO)
		if _attack_timer <= 0.0:
			_deal_damage_to(_target)
			_attack_timer = attack_cooldown
		return
	_nav.target_position = nav_goal
	var next_pos := _nav.get_next_path_position()
	var to_next := global_position.direction_to(next_pos)
	if to_next.length_squared() < 0.0001:
		_nav.set_velocity(Vector2.ZERO)
	else:
		_nav.set_velocity(to_next * move_speed)


func _run_move_order(_delta: float) -> void:
	_nav.max_speed = maxf(move_speed, 1.0)
	_nav.target_position = _move_goal
	if global_position.distance_to(_move_goal) < 14.0 or _nav.is_navigation_finished():
		clear_player_orders()
		_nav.set_velocity(Vector2.ZERO)
		return
	var next_pos := _nav.get_next_path_position()
	var to_next := global_position.direction_to(next_pos)
	if to_next.length_squared() < 0.0001:
		_nav.set_velocity(Vector2.ZERO)
	else:
		_nav.set_velocity(to_next * move_speed)


func _attack_order_still_valid() -> bool:
	if _attack_order_target == null or not is_instance_valid(_attack_order_target):
		return false
	if _attack_order_target is CombatUnit:
		return (_attack_order_target as CombatUnit).hp > 0.0
	if _attack_order_target is Bunker:
		return (_attack_order_target as Bunker).health > 0.0
	return true


func _on_velocity_computed(safe_velocity: Vector2) -> void:
	velocity = safe_velocity
	move_and_slide()


func _distance_to_target_for_combat() -> float:
	if _target is Bunker:
		return (_target as Bunker).distance_to_footprint_edge(global_position)
	return global_position.distance_to(_target.global_position)


func _nav_goal_for_target() -> Vector2:
	if _target is Bunker:
		return (_target as Bunker).closest_point_on_footprint_world(global_position)
	return _target.global_position


func _acquire_target() -> void:
	var ai_early_focus_units: bool = (
		_owner_player != null
		and not _owner_player.is_human_player
		and not EvolutionConfig.ai_should_consider_bunkers_for_targeting(_owner_player.kills)
	)

	var best: Node2D = null
	var best_d := INF

	if not ai_early_focus_units:
		for b in get_tree().get_nodes_in_group("bunkers"):
			if not is_instance_valid(b):
				continue
			if b is Bunker and (b as Bunker).team_id == team_id:
				continue
			var d: float = (b as Bunker).distance_to_footprint_edge(global_position)
			if d < best_d:
				best_d = d
				best = b as Node2D

	for u in get_tree().get_nodes_in_group("units"):
		if u == self or not is_instance_valid(u):
			continue
		var cu := u as CombatUnit
		if cu.team_id == team_id or cu.hp <= 0.0:
			continue
		var d2 := global_position.distance_to(cu.global_position)
		if d2 < best_d:
			best_d = d2
			best = cu

	if ai_early_focus_units and best == null:
		for b in get_tree().get_nodes_in_group("bunkers"):
			if not is_instance_valid(b):
				continue
			if b is Bunker and (b as Bunker).team_id == team_id:
				continue
			var d2b: float = (b as Bunker).distance_to_footprint_edge(global_position)
			if d2b < best_d:
				best_d = d2b
				best = b as Node2D

	_target = best


func _deal_damage_to(target: Node2D) -> void:
	var killer: PlayerBase = _owner_player
	if target is Bunker:
		(target as Bunker).take_damage(damage, team_id, killer)
	elif target is CombatUnit:
		(target as CombatUnit).take_damage(damage, team_id, killer)
	SfxRouter.play_unit_attack(global_position, self)


func take_damage(amount: float, attacker_team: int, killer: PlayerBase = null) -> void:
	if attacker_team == team_id:
		return
	_last_killer = killer
	hp -= amount
	if _friendly_selected or _enemy_inspect:
		queue_redraw()
	if hp <= 0.0:
		_die()


func _die() -> void:
	if _last_killer != null and is_instance_valid(_last_killer):
		var mgr := get_tree().get_first_node_in_group("match_manager")
		if mgr and mgr.has_method("register_kill"):
			mgr.register_kill(_last_killer)
	SfxRouter.play_unit_death(global_position, self)
	queue_free()
