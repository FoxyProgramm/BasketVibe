class_name RadioItem
extends ItemBase

var hold_offset := Vector3(0, -0.0, -1.2)
var hold_rotation := Vector3(0, 0, 0)

@export var sync_position: Vector3
@export var sync_rotation: Vector3

@export var held_by_id: int = 0:
	set(val):
		held_by_id = val
		_update_bat_state()

@export var songs: Array[AudioStream] = []
@export var fade_duration: float = 1.8
@export var volume_db: float = -15.0

@onready var audio_player = $AudioStreamPlayer3D

var is_on: bool = false
var current_song_index: int = -1
var fade_tween: Tween
var original_pitch: float = 1.0

@onready var sprite_mat = $Sprite3D

func is_pickable() -> bool :
	return true

func _ready() -> void:
	original_pitch = audio_player.pitch_scale
	
	var sync = MultiplayerSynchronizer.new()
	sync.root_path = NodePath("..")
	var config = SceneReplicationConfig.new()

	config.add_property(NodePath(".:sync_position"))
	config.add_property(NodePath(".:sync_rotation"))
	sync.replication_config = config

	sync.replication_interval = 0.05
	sync.delta_interval = 0.05
	add_child(sync)

	sync_position = global_position
	sync_rotation = rotation

	audio_player.volume_db = -80.0
	audio_player.finished.connect(_on_song_finished)

	if not multiplayer.is_server():
		freeze = true

func _on_song_finished():
	if is_on and audio_player.stream:
		audio_player.play()

func use():
	if multiplayer.is_server():
		_radio_toggle()
	else:
		rpc_id(1, "_radio_toggle")

@rpc("any_peer", "reliable")
func _radio_toggle():
	if not multiplayer.is_server():
		return
	
	is_on = !is_on
	
	if is_on:
		current_song_index = randi_range(0, songs.size() - 1)
		audio_player.stream = songs[current_song_index]
		audio_player.play()
	
	rpc("_update_radio_state", is_on, current_song_index)

@rpc("call_local", "reliable")
func _update_radio_state(state: bool, song_index: int):
	is_on = state
	current_song_index = song_index
	
	if fade_tween and fade_tween.is_running():
		fade_tween.kill()
	
	fade_tween = create_tween()
	
	if is_on:
		if song_index >= 0 and song_index < songs.size():
			audio_player.stream = songs[song_index]
		if not audio_player.playing:
			audio_player.play()
		fade_tween.tween_property(audio_player, "volume_db", volume_db, fade_duration).set_ease(Tween.EASE_OUT)
	else:
		fade_tween.tween_property(audio_player, "volume_db", -200.0, fade_duration).set_ease(Tween.EASE_IN)

func _update_bat_state():
	if held_by_id != 0:
		if not freeze: freeze = true
		collision_layer = 0
		collision_mask = 0
	else:
		if not multiplayer.is_server():
			freeze = true
		else:
			if freeze: freeze = false
		collision_layer = 3
		collision_mask = 3

func _process(delta: float):
	var cam = get_viewport().get_camera_3d()
	var sprite = get_node_or_null("Visuals/Sprite3D")
	if cam and sprite:
		var to_cam = cam.global_position - sprite.global_position
		var local_up = global_transform.basis.y.normalized()
		var projected_to_cam = to_cam - local_up * to_cam.dot(local_up)
		if projected_to_cam.length_squared() > 0.001:
			var forward = projected_to_cam.normalized()
			var right = local_up.cross(forward).normalized()
			sprite.global_basis = Basis(right, local_up, forward) * 0.5

	var anim_sprite = get_node_or_null("Visuals/AnimatedSprite3D")
	if cam and anim_sprite:
		var to_cam = cam.global_position - anim_sprite.global_position
		var local_up = global_transform.basis.y.normalized()
		var projected_to_cam = to_cam - local_up * to_cam.dot(local_up)
		if projected_to_cam.length_squared() > 0.001:
			var forward = projected_to_cam.normalized()
			var right = local_up.cross(forward).normalized()
			anim_sprite.global_basis = Basis(right, local_up, forward) * 0.5

func _physics_process(delta: float) -> void:
	if held_by_id != 0:
		var player = _get_player(held_by_id)
		if player:
			var grip = player.get_node_or_null("Head/WeaponGrip")
			if grip:
				global_position = grip.global_transform * hold_offset
				global_transform.basis = grip.global_transform.basis * Basis.from_euler(hold_rotation)
			else:
				var head = player.get_node_or_null("Head")
				if head:
					global_position = head.global_transform * hold_offset
					global_transform.basis = head.global_transform.basis * Basis.from_euler(hold_rotation)
				else:
					global_position = player.global_transform * hold_offset

		if multiplayer.is_server():
			linear_velocity = Vector3.ZERO
			angular_velocity = Vector3.ZERO
			sync_position = global_position
			sync_rotation = rotation
	else:
		if multiplayer.is_server():
			sync_position = global_position
			sync_rotation = rotation
		else:
			global_position = global_position.lerp(sync_position, 15.0 * delta)
			rotation.x = lerp_angle(rotation.x, sync_rotation.x, 15.0 * delta)
			rotation.y = lerp_angle(rotation.y, sync_rotation.y, 15.0 * delta)
			rotation.z = lerp_angle(rotation.z, sync_rotation.z, 15.0 * delta)

@rpc("any_peer", "call_local", "reliable")
func request_pickup(player_id: int) -> void:
	if not multiplayer.is_server(): return
	if held_by_id != 0: return

	var player = _get_player(player_id)
	if player:
		if global_position.distance_to(player.global_position) < 4.0:
			held_by_id = player_id
			self.rotation = Vector3.ZERO
			rpc("update_held_state", player_id)

@rpc("any_peer", "call_local", "reliable")
func request_drop(player_vel: Vector3 = Vector3.ZERO) -> void:
	if not multiplayer.is_server(): return
	var sender_id = multiplayer.get_remote_sender_id()
	if held_by_id == sender_id:
		held_by_id = 0
		rpc("update_held_state", 0)
		linear_velocity = player_vel

@rpc("any_peer", "call_local", "reliable")
func update_held_state(new_id: int):
	held_by_id = new_id

func _get_player(id: int) -> Node3D:
	for p in get_tree().get_nodes_in_group("player"):
		if p.name == str(id):
			return p
	return null

@rpc("any_peer", "call_local", "reliable")
func apply_radio_impulse(impulse: Vector3):
	apply_central_impulse(impulse)
	_hit_pitch_effect()

func _hit_pitch_effect():
	var hit_pitch = randf_range(0.3, 1.8)
	audio_player.pitch_scale = hit_pitch
	var tween = create_tween()
	tween.tween_property(audio_player, "pitch_scale", original_pitch, 0.9).set_ease(Tween.EASE_OUT)
